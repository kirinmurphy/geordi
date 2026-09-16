import AppKit
import GeordiDomain
import SwiftUI

public enum TypeSize {
  /// The typographic floor — nothing in the UI renders smaller than this.
  public static let caption: CGFloat = 13
  public static let sm: CGFloat = 14
  public static let base: CGFloat = 15
  public static let large: CGFloat = 17
  public static let xl: CGFloat = 20
  public static let twoXL: CGFloat = 26
  public static let display: CGFloat = 32
}

public enum IconSize {
  public static let small: CGFloat = 18
  public static let base: CGFloat = 26
  public static let large: CGFloat = 34
  public static let xl: CGFloat = 44
}

public struct RelationshipCanvas: View {
  public let graph: SystemGraph
  public let layout: LayoutResult
  public let visibleTypes: Set<EntityType>
  @Binding public var selection: GraphSelection?
  @Binding public var focusedEntity: EntityID?
  private let configuration: LayoutConfiguration
  private let isReadOnlyPreview: Bool
  private let centerEntityID: EntityID?
  private let onRecenterEntity: ((Entity) -> Void)?

  @State private var scale = 1.0
  @State private var lastScale = 1.0
  @State private var offset = CGSize.zero
  @State private var lastOffset = CGSize.zero
  @State private var viewportSize = CGSize.zero

  public init(
    graph: SystemGraph,
    layout: LayoutResult,
    visibleTypes: Set<EntityType>,
    selection: Binding<GraphSelection?>,
    focusedEntity: Binding<EntityID?>,
    configuration: LayoutConfiguration,
    isReadOnlyPreview: Bool = false,
    centerEntityID: EntityID? = nil,
    onRecenterEntity: ((Entity) -> Void)? = nil
  ) {
    self.graph = graph
    self.layout = layout
    self.visibleTypes = visibleTypes
    _selection = selection
    _focusedEntity = focusedEntity
    self.configuration = configuration
    self.isReadOnlyPreview = isReadOnlyPreview
    self.centerEntityID = centerEntityID
    self.onRecenterEntity = onRecenterEntity
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        Group {
          if isReadOnlyPreview {
            Color.clear
          } else {
            Color(nsColor: .windowBackgroundColor)
          }
        }
        .background(
          Group {
            if !isReadOnlyPreview {
              ScrollWheelCapture { delta, zoomRequested in
                if zoomRequested {
                  changeScale(by: delta.height * 0.01)
                } else {
                  offset = CGSize(
                    width: offset.width + delta.width,
                    height: offset.height + delta.height
                  )
                  lastOffset = offset
                }
              }
            }
          })
        canvas
          .scaleEffect(scale, anchor: .topLeading)
          .offset(offset)
          .gesture(
            isReadOnlyPreview
              ? nil : panGesture.simultaneously(with: zoomGesture)
          )
          .onChange(of: focusedEntity) { _, entityID in
            guard let entityID, let point = layout.positions[entityID] else { return }
            scale = max(scale, 0.9)
            lastScale = scale
            offset = CGSize(
              width: proxy.size.width / 2 - point.x * scale,
              height: proxy.size.height / 2 - point.y * scale
            )
            lastOffset = offset
          }
        if !isReadOnlyPreview {
          controls
          interactionLegend
        }
      }
      .clipped()
      .onAppear {
        fitGraph(in: proxy.size)
        focusIfRequested(in: proxy.size)
      }
      .onChange(of: graph.metadata.id) { _, _ in fitGraph(in: proxy.size) }
      .onChange(of: proxy.size) { _, newSize in fitGraph(in: newSize) }
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Relationship map")
      .allowsHitTesting(!isReadOnlyPreview)
    }
  }

  private func focusIfRequested(in viewport: CGSize) {
    guard let focusedEntity, let point = layout.positions[focusedEntity] else { return }
    scale = max(scale, 0.9)
    lastScale = scale
    offset = CGSize(
      width: viewport.width / 2 - point.x * scale,
      height: viewport.height / 2 - point.y * scale
    )
    lastOffset = offset
  }

  private var canvas: some View {
    ZStack(alignment: .topLeading) {
      stageBackgrounds
      edges
      ForEach(visibleRelationships) { relationship in
        relationshipButton(relationship)
      }
      ForEach(visibleEntities) { entity in
        node(entity)
          .position(layout.positions[entity.id] ?? .zero)
      }
    }
    .frame(width: layout.size.width, height: layout.size.height)
    .contentShape(Rectangle())
    .onTapGesture { selection = nil }
  }

  private var stageBackgrounds: some View {
    ForEach(layout.groups, id: \.id) { group in
      VStack(alignment: .leading, spacing: 0) {
        Text(group.title)
          .font(.system(size: TypeSize.sm, weight: .bold))
          .tracking(0.7)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 10)
          .padding(.top, 10)
        Spacer()
      }
      .frame(width: group.frame.width, height: group.frame.height, alignment: .topLeading)
      .background(stageColor(group.tint).opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16)
          .stroke(stageColor(group.tint).opacity(0.18), lineWidth: 1)
      }
      .position(x: group.frame.midX, y: group.frame.midY)
      .allowsHitTesting(false)
    }
  }

  private var visibleEntities: [Entity] {
    graph.entities.filter { visibleTypes.contains($0.type) }
  }

  private var visibleEntityIDs: Set<EntityID> {
    Set(visibleEntities.map(\.id))
  }

  private var visibleRelationships: [Relationship] {
    graph.relationships.filter {
      visibleEntityIDs.contains($0.source) && visibleEntityIDs.contains($0.target)
    }
  }

  private var highlightedRelationships: Set<RelationshipID> {
    GraphNavigator(graph: graph).highlightedRelationships(for: selection)
  }

  private var highlightedEntities: Set<EntityID> {
    GraphNavigator(graph: graph).highlightedEntities(for: selection)
  }

  private var edges: some View {
    Canvas { context, _ in
      for edge in graph.relationships
      where visibleEntityIDs.contains(edge.source) && visibleEntityIDs.contains(edge.target) {
        guard let start = layout.positions[edge.source], let end = layout.positions[edge.target]
        else {
          continue
        }
        let isHighlighted = highlightedRelationships.contains(edge.id)
        let isUncertain = [.ambiguous, .possible, .probable].contains(edge.confidence)
        let color = isUncertain ? Color.orange : Color.accentColor
        var path = Path()
        path.move(to: start)
        let midpoint = (start.x + end.x) / 2
        path.addCurve(
          to: end,
          control1: CGPoint(x: midpoint, y: start.y),
          control2: CGPoint(x: midpoint, y: end.y)
        )
        context.stroke(
          path,
          with: .color(color.opacity(selection == nil || isHighlighted ? 0.8 : 0.12)),
          style: StrokeStyle(
            lineWidth: isHighlighted ? 4 : 2,
            dash: isUncertain ? [8, 6] : []
          )
        )
        let direction = Path { arrow in
          arrow.move(to: CGPoint(x: end.x - 10, y: end.y - 6))
          arrow.addLine(to: end)
          arrow.addLine(to: CGPoint(x: end.x - 10, y: end.y + 6))
        }
        context.stroke(
          direction, with: .color(color.opacity(isHighlighted ? 1 : 0.55)), lineWidth: 2)
      }
    }
    .allowsHitTesting(false)
  }

  private func node(_ entity: Entity) -> some View {
    let selected = selection?.value == .entity(entity.id)
    let relevant = selection == nil || highlightedEntities.contains(entity.id)
    let isGroup = DisplayGroupMetadata.isGroup(entity)
    return Button {
      selection = GraphSelection(.entity(entity.id))
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          if isGroup {
            Image(systemName: "square.stack.3d.up.fill")
              .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
          } else if entity.type == .application,
            let path = entity.details.first(where: { $0.label == "Path" })?.value
          {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
              .resizable()
              .scaledToFit()
              .frame(
                width: EntityVisualStyle.nodeIconSize,
                height: EntityVisualStyle.nodeIconSize
              )
          } else {
            Image(systemName: symbol(for: entity.type))
              .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
          }
          Text(
            isGroup
              ? entity.type.label.uppercased()
              : entity.type.label.dropLast(entity.type == .persistence ? 0 : 1).description
          )
          .font(.system(size: TypeSize.sm, weight: .regular))
        }
        .foregroundStyle(EntityVisualStyle.color(for: entity.type))
        Text(entity.name)
          .font(.system(size: TypeSize.base, weight: .regular))
          .lineLimit(2)
          .multilineTextAlignment(.leading)
      }
      .padding(12)
      .frame(width: configuration.nodeWidth, height: configuration.nodeHeight, alignment: .leading)
      .background {
        ZStack {
          if isGroup {
            RoundedRectangle(cornerRadius: 14)
              .fill(EntityVisualStyle.color(for: entity.type).opacity(0.12))
              .offset(x: 7, y: 7)
            RoundedRectangle(cornerRadius: 14)
              .fill(EntityVisualStyle.color(for: entity.type).opacity(0.09))
              .offset(x: 3.5, y: 3.5)
          }
          RoundedRectangle(cornerRadius: 14)
            .fill(.regularMaterial)
        }
      }
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(
            selected ? Color.accentColor : EntityVisualStyle.color(for: entity.type).opacity(0.55),
            lineWidth: selected ? 3 : 1)
      }
      .opacity(relevant ? 1 : 0.3)
      .shadow(color: .black.opacity(selected ? 0.22 : 0.08), radius: selected ? 10 : 3)
    }
    .buttonStyle(.plain)
    .simultaneousGesture(
      TapGesture(count: 2).onEnded {
        selection = GraphSelection(.entity(entity.id))
        focusedEntity = entity.id
      }
    )
    .overlay(alignment: .bottom) {
      if !isReadOnlyPreview, selected, !isGroup, entity.id != centerEntityID,
        let onRecenterEntity
      {
        Text("See all connections")
          .font(.system(size: TypeSize.sm, weight: .semibold))
          .foregroundStyle(EntityVisualStyle.color(for: entity.type))
          .frame(width: configuration.nodeWidth, height: 30)
          .background(.thickMaterial)
          .overlay(alignment: .top) {
            Rectangle()
              .fill(EntityVisualStyle.color(for: entity.type).opacity(0.45))
              .frame(height: 1)
          }
          .clipShape(
            .rect(
              bottomLeadingRadius: 14,
              bottomTrailingRadius: 14
            )
          )
          .offset(y: 30)
          .contentShape(Rectangle())
          .onTapGesture {
            onRecenterEntity(entity)
          }
          .help("See all \(entity.name) connections")
      }
    }
    .accessibilityLabel("\(entity.name), \(entity.type.label)")
    .accessibilityHint("Select to inspect relationships and evidence")
    .contextMenu {
      Button("Copy Name") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entity.name, forType: .string)
      }
    }
  }

  private func relationshipButton(_ relationship: Relationship) -> some View {
    let start = layout.positions[relationship.source] ?? .zero
    let end = layout.positions[relationship.target] ?? .zero
    let selected = selection?.value == .relationship(relationship.id)
    let relevant = selection == nil || highlightedRelationships.contains(relationship.id)
    return RelationshipMarker(
      relationship: relationship,
      selected: selected,
      relevant: relevant
    ) {
      selection = GraphSelection(.relationship(relationship.id))
    }
    .position(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    .accessibilityLabel(
      "\(relationship.type.rawValue), \(relationship.confidence.plainLanguage)"
    )
    .accessibilityHint("Select to inspect direction, confidence, and evidence")
  }

  private var controls: some View {
    HStack(spacing: 4) {
      Button {
        changeScale(by: -0.15)
      } label: {
        Image(systemName: "minus.magnifyingglass")
      }
      .accessibilityLabel("Zoom out")
      .disabled(scale <= configuration.minimumScale)
      .keyboardShortcut("-", modifiers: .command)
      Text("\(Int((scale * 100).rounded()))%")
        .font(.system(size: TypeSize.base).monospacedDigit())
        .frame(minWidth: 48)
        .accessibilityLabel("Zoom \(Int((scale * 100).rounded())) percent")
      Button {
        fitGraph(in: viewportSize)
      } label: {
        Image(systemName: "arrow.counterclockwise")
      }
      .accessibilityLabel("Reset map view")
      Button {
        changeScale(by: 0.15)
      } label: {
        Image(systemName: "plus.magnifyingglass")
      }
      .accessibilityLabel("Zoom in")
      .disabled(scale >= configuration.maximumScale)
      .keyboardShortcut("+", modifiers: .command)
    }
    .buttonStyle(.bordered)
    .padding(10)
  }

  private var interactionLegend: some View {
    VStack {
      Spacer()
      HStack(spacing: 14) {
        Label("Drag to move", systemImage: "hand.draw")
        Label("Two-finger scroll to move", systemImage: "rectangle.and.hand.point.up.left")
        Label("Pinch to zoom", systemImage: "arrow.up.left.and.arrow.down.right")
        Label("Double-click to focus", systemImage: "scope")
      }
      .font(.system(size: TypeSize.sm))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(.ultraThinMaterial, in: Capsule())
      .padding(.bottom, 12)
    }
    .frame(maxWidth: .infinity)
    .allowsHitTesting(false)
  }

  private var panGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        offset = CGSize(
          width: lastOffset.width + value.translation.width,
          height: lastOffset.height + value.translation.height
        )
      }
      .onEnded { _ in lastOffset = offset }
  }

  private var zoomGesture: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        scale = min(
          configuration.maximumScale,
          max(configuration.minimumScale, lastScale * value.magnification))
      }
      .onEnded { _ in lastScale = scale }
  }

  private func changeScale(by change: Double) {
    scale = min(configuration.maximumScale, max(configuration.minimumScale, scale + change))
    lastScale = scale
  }

  private func fitGraph(in size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    viewportSize = size
    let horizontalScale = (size.width - 48) / max(layout.size.width, 1)
    let verticalScale = (size.height - 48) / max(layout.size.height, 1)
    let readableMinimumScale =
      isReadOnlyPreview ? 0.1 : max(configuration.minimumScale, 0.72)
    scale = min(
      1.15,
      configuration.maximumScale,
      max(readableMinimumScale, min(horizontalScale, verticalScale))
    )
    lastScale = scale
    offset = CGSize(
      width: max(24, (size.width - layout.size.width * scale) / 2),
      height: max(24, (size.height - layout.size.height * scale) / 2)
    )
    lastOffset = offset
  }

  private func symbol(for type: EntityType) -> String {
    EntityVisualStyle.symbol(for: type)
  }

  private func stageColor(_ tint: SemanticStageDefinition.Tint) -> Color {
    switch tint {
    case .indigo: .indigo
    case .blue: .blue
    case .purple: .purple
    case .cyan: .cyan
    case .green: .green
    case .orange: .orange
    }
  }
}

/// A single, calm semantic palette for entity types wherever they appear in \(AppBrand.displayName).
/// Red and orange remain available exclusively for warnings, findings, and status.
public enum EntityVisualStyle {
  /// The shared icon size for semantic nodes in maps, diagrams, and inspectors.
  public static let nodeIconSize: CGFloat = IconSize.base

  public static func symbol(for type: EntityType) -> String {
    switch type {
    case .application: "macwindow.on.rectangle"
    case .process: "gearshape.2"
    case .file: "folder"
    case .persistence: "power"
    case .resource: "gauge.with.dots.needle.50percent"
    case .incident: "waveform.path.ecg"
    case .event: "clock"
    case .packageManager: "shippingbox"
    case .shellFramework: "terminal"
    case .package: "cube.box"
    }
  }

  public static func color(for type: EntityType) -> Color {
    switch type {
    case .application: Color(red: 0.35, green: 0.58, blue: 0.82)
    case .process: Color(red: 0.29, green: 0.69, blue: 0.74)
    case .file: Color(red: 0.38, green: 0.68, blue: 0.52)
    case .persistence: Color(red: 0.58, green: 0.48, blue: 0.78)
    case .resource: Color(red: 0.72, green: 0.48, blue: 0.70)
    case .incident: Color(red: 0.64, green: 0.49, blue: 0.72)
    case .event: Color(red: 0.43, green: 0.52, blue: 0.75)
    case .packageManager: Color(red: 0.46, green: 0.55, blue: 0.72)
    case .shellFramework: Color(red: 0.38, green: 0.66, blue: 0.62)
    case .package: Color(red: 0.31, green: 0.62, blue: 0.68)
    }
  }

}

private struct RelationshipMarker: View {
  let relationship: Relationship
  let selected: Bool
  let relevant: Bool
  let action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      Group {
        if selected || hovering {
          Text(relationship.type.rawValue)
            .padding(.horizontal, 7)
        } else {
          Image(systemName: "arrow.right")
            .frame(width: 20)
        }
      }
      .font(.system(size: TypeSize.sm, weight: .semibold))
      .frame(height: 22)
      .background(.thickMaterial, in: Capsule())
      .overlay {
        Capsule().stroke(markerColor, lineWidth: selected ? 3 : 1)
      }
      .opacity(relevant ? 1 : 0.18)
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .help(
      "\(relationship.type.rawValue.capitalized) · \(relationship.confidence.plainLanguage)"
    )
  }

  private var markerColor: Color {
    if selected {
      return relationship.confidence == .ambiguous ? .orange : .accentColor
    }
    if hovering {
      return relationship.confidence == .ambiguous
        ? .orange.opacity(0.8) : .accentColor.opacity(0.8)
    }
    return .secondary.opacity(0.25)
  }
}
