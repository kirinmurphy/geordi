import HALVisualization
import SwiftUI

struct FilesystemMapView: View {
  let model: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var focusedNodeID = "root"
  @State private var selectedNodeID: String?

  private var nodes: [FilesystemNode] {
    guard let catalog = try? FilesystemLocationCatalog.bundled() else { return [] }
    return FilesystemProjector().project(
      graph: model.fixture,
      catalog: catalog,
      homeDirectory: FileManager.default.homeDirectoryForCurrentUser.path
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      breadcrumb
      if nodes.isEmpty {
        ContentUnavailableView(
          "No filesystem locations to show",
          systemImage: "folder.badge.questionmark",
          description: Text("HAL has no typed observed paths in the current profile.")
        )
      } else {
        HSplitView {
          spatialTree
          inspector
            .frame(minWidth: 280, idealWidth: 340)
        }
      }
    }
    .accessibilityLabel("Filesystem map")
  }

  private var breadcrumb: some View {
    HStack(spacing: 6) {
      ForEach(Array(focusedAncestry.enumerated()), id: \.element.id) { index, node in
        if index > 0 {
          Image(systemName: "chevron.right")
            .font(.halSmall)
            .foregroundStyle(.secondary)
        }
        Button(node.label) {
          withOptionalAnimation { focusedNodeID = node.id }
        }
        .buttonStyle(.plain)
      }
      Spacer()
      Text("Curated view · no recursive indexing")
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .background(.bar)
  }

  private var spatialTree: some View {
    ScrollView([.horizontal, .vertical]) {
      HStack(alignment: .top, spacing: 46) {
        ForEach(depths, id: \.self) { depth in
          VStack(alignment: .leading, spacing: 18) {
            Text(depth == 0 ? "VOLUME" : "DEPTH \(depth)")
              .font(.halSmall.bold())
              .foregroundStyle(.secondary)
            ForEach(visibleNodes.filter { $0.depth == depth }) { node in
              nodeCard(node)
            }
          }
          .padding(.top, CGFloat(depth) * 12)
        }
      }
      .padding(28)
    }
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private func nodeCard(_ node: FilesystemNode) -> some View {
    Button {
      selectedNodeID = node.id
      withOptionalAnimation { focusedNodeID = node.id }
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: node.symbol)
            .font(.halSubsection)
          Text(node.label)
            .font(.halRowTitle)
            .lineLimit(2)
          Spacer()
          if !node.entityIDs.isEmpty {
            Text("\(node.entityIDs.count)")
              .font(.halSmall.bold())
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(.blue.opacity(0.15), in: Capsule())
          }
        }
        Text(stateLabel(node.state))
          .font(.halSecondary)
          .foregroundStyle(node.state == .observed ? .primary : .secondary)
      }
      .padding(14)
      .frame(width: 220, alignment: .leading)
      .frame(minHeight: 82, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(selectedNodeID == node.id ? Color.accentColor : .secondary.opacity(0.25))
      }
      .shadow(
        color: .black.opacity(reduceMotion ? 0.04 : min(0.16, Double(node.depth) * 0.025)),
        radius: reduceMotion ? 2 : CGFloat(3 + node.depth),
        y: reduceMotion ? 1 : CGFloat(node.depth)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(node.label), \(stateLabel(node.state))")
  }

  private var inspector: some View {
    let node = selectedNode ?? nodes.first
    return ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if let node {
          Text(node.label).font(.halSection.bold())
          Text(node.purpose).textSelection(.enabled)
          PathActionMenu(path: node.path)
          Label(stateLabel(node.state), systemImage: stateSymbol(node.state))
          Divider()
          Text("Observed here").font(.halRowTitle)
          if node.entityIDs.isEmpty {
            Text("No entity association is present. This does not mean the folder is empty.")
              .foregroundStyle(.secondary)
          } else {
            ForEach(node.entityIDs, id: \.rawValue) { id in
              if let entity = model.fixture.entity(id) {
                Button(entity.name) { model.focus(entity) }
                  .buttonStyle(.bordered)
              }
            }
          }
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var selectedNode: FilesystemNode? {
    selectedNodeID.flatMap { id in nodes.first { $0.id == id } }
  }

  private var focusedAncestry: [FilesystemNode] {
    var result: [FilesystemNode] = []
    var current = nodes.first { $0.id == focusedNodeID }
    while let node = current {
      result.insert(node, at: 0)
      current = node.parentID.flatMap { parent in nodes.first { $0.id == parent } }
    }
    return result
  }

  private var visibleNodes: [FilesystemNode] {
    guard focusedNodeID != "root" else { return nodes }
    let root = nodes.first { $0.id == focusedNodeID }
    return nodes.filter { node in
      node.id == focusedNodeID
        || (root.map { node.path.hasPrefix($0.path + "/") } ?? false)
    }
  }

  private var depths: [Int] { Array(Set(visibleNodes.map(\.depth))).sorted() }

  private func stateLabel(_ state: FilesystemObservationState) -> String {
    switch state {
    case .notEnumerated: "Not enumerated"
    case .unavailable: "Unavailable"
    case .unreadable: "Unreadable"
    case .empty: "Observed empty"
    case .observed: "Observed entities"
    }
  }

  private func stateSymbol(_ state: FilesystemObservationState) -> String {
    switch state {
    case .notEnumerated: "eye.slash"
    case .unavailable: "questionmark.circle"
    case .unreadable: "lock"
    case .empty: "tray"
    case .observed: "checkmark.circle"
    }
  }

  private func withOptionalAnimation(_ action: () -> Void) {
    if reduceMotion { action() } else { withAnimation(.easeInOut(duration: 0.2), action) }
  }
}
