import GeordiDomain
import GeordiVisualization
import SwiftUI

/// Max width for observation list columns. Page headers stay full-bleed;
/// the rows beneath are bounded so long lists stay scannable.
private let explorationContentMaxWidth: CGFloat = 880

struct ExplorationBrowserView: View {
  let model: AppModel

  var body: some View {
    let context = model.explorationContext
    let presentation = model.explorationPresentation
    VStack(spacing: 0) {
      ExplorationHeader(
        title: context?.title ?? "Explore",
        explanation: explanation
      )
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 20) {
          if let guide = referenceGuide {
            guide.panel
              .frame(maxWidth: .infinity, alignment: .center)
          }
          if let context, let presentation, hasMembers(presentation) {
            VStack(alignment: .leading, spacing: 5) {
              Text("What \(AppBrand.displayName) observed on this Mac")
                .font(.section.bold())
            }
            ForEach(presentation.sections) { section in
              if !section.groups.isEmpty {
                sectionView(section)
              }
            }
            if !presentation.unassignedEntityIDs.isEmpty {
              unclassifiedSection(presentation.unassignedEntityIDs, context: context)
            }
          } else {
            ContentUnavailableView(
              context?.emptyTitle ?? "Nothing observed",
              systemImage: emptySymbol,
              description: Text(
                context?.emptyMessage
                  ?? "The explanatory map above remains available even when no observations exist.")
            )
          }
        }
        .frame(maxWidth: explorationContentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(20)
      }
      .scrollIndicators(.visible)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .accessibilityIdentifier("explorationContextBrowser")
  }

  private var explanation: String {
    switch model.destination {
    case .startup:
      "A startup declaration and a currently running process are different observed facts. Choose an item only when you want its bounded relationship view."
    case .storage:
      "Rebuildable or redownloadable data may be recreated, but that classification does not mean it is automatically safe to delete."
    case .commandLine:
      "Browse retained roles and discovery sources. \(AppBrand.displayName) does not infer a command’s purpose from its name."
    default:
      model.explorationContext?.question ?? ""
    }
  }

  private var referenceGuide: ReferenceGuide? {
    switch model.destination {
    case .startup: .startup
    case .storage: .storage
    case .commandLine: .commandLine
    default: nil
    }
  }

  private var emptySymbol: String {
    switch model.destination {
    case .startup: "power"
    case .storage: "internaldrive"
    case .commandLine: "terminal"
    default: "tray"
    }
  }

  private func hasMembers(_ presentation: ExplorationPresentation) -> Bool {
    presentation.sections.contains { !$0.groups.isEmpty }
      || !presentation.unassignedEntityIDs.isEmpty
  }

  private func sectionView(_ section: ExplorationSection) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(section.title)
        .font(.subsection.bold())
      ForEach(section.groups) { group in
        if !group.entityIDs.isEmpty || group.actionEntityID != nil {
          GroupDisclosure(title: group.title, count: group.entityIDs.count) {
            VStack(spacing: 0) {
              if let actionEntityID = group.actionEntityID,
                let owner = model.fixture.entity(actionEntityID)
              {
                EntityBrowserRow(
                  entity: owner,
                  subtitle: "Owning software · Open its bounded relationships",
                  action: { model.focus(owner) }
                )
                Divider()
              }
              ForEach(group.entityIDs, id: \.rawValue) { id in
                if let entity = model.fixture.entity(id) {
                  EntityBrowserRow(
                    entity: entity,
                    subtitle: entitySubtitle(entity),
                    action: { model.focus(entity) }
                  )
                  Divider()
                }
              }
            }
            .padding(.leading, 12)
          }
        }
      }
    }
    .padding(16)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.secondary.opacity(0.2))
    }
  }

  private func unclassifiedSection(_ ids: [EntityID], context: ExplorationContext) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(context.unresolvedTitle ?? "Unclassified")
        .font(.subsection.bold())
      ForEach(ids, id: \.rawValue) { id in
        if let entity = model.fixture.entity(id) {
          EntityBrowserRow(
            entity: entity,
            subtitle: entitySubtitle(entity),
            action: { model.focus(entity) }
          )
        }
      }
    }
    .padding(16)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
  }

  private func entitySubtitle(_ entity: Entity) -> String {
    if model.destination == .storage {
      let size = entity.details.first { $0.label == "Size" }?.value
      let classification = entity.details.first {
        ["Classification", "Rebuildability", "Removal"].contains($0.label)
      }?.value
      let path = entity.details.first { ["Path", "Location"].contains($0.label) }?.value
      return [size, classification, path].compactMap { $0 }.joined(separator: " · ")
    }
    if entity.type == .persistence {
      let type = entity.details.first { $0.label == "Type" }?.value ?? "Startup declaration"
      let scope = entity.details.first { $0.label == "Scope" }?.value
      let ownership = entity.details.first { $0.label == "Ownership" }?.value
      let running = entity.details.first { $0.label == "Running state" }?.value
      let observedAt = entity.details.first { $0.label == "Process observation time" }?.value
      let activation = [
        entity.details.first { $0.label == "Run at load" }?.value == "Yes"
          ? "run at load configured" : nil,
        entity.details.first { $0.label == "Keep alive" }?.value == "Yes"
          ? "restart policy configured" : nil,
      ].compactMap { $0 }.joined(separator: ", ")
      return [
        type, scope, ownership, running, observedAt.map { "observed \($0)" },
        activation.isEmpty ? nil : activation,
      ]
      .compactMap { $0 }
      .joined(separator: " · ")
    }
    if let path = entity.details.first(where: {
      ["Path", "Location", "Executable", "Declaration"].contains($0.label)
    }) {
      return path.value
    }
    return entity.summary
  }
}

/// A state-controlled disclosure for observed groups. Replaces the older
/// uncontrolled `DisclosureGroup`, whose chevron promised an expandable
/// list but frequently failed to reveal one on macOS.
struct GroupDisclosure<Content: View>: View {
  let title: String
  let count: Int
  @ViewBuilder let content: () -> Content
  @State private var expanded = false
  @State private var hovering = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
      } label: {
        HStack(spacing: 10) {
          Image(systemName: expanded ? "chevron.down" : "chevron.right")
            .font(.small.bold())
            .foregroundStyle(.secondary)
            .frame(width: 14)
          Text(title)
            .font(.rowTitle)
          Spacer()
          Text("\(count)")
            .font(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .pointerCursor()
      .background(hovering ? Color.accentColor.opacity(0.06) : .clear)
      .onHover { hovering = $0 }
      if expanded {
        content()
      }
    }
  }
}

struct ExplorationHeader: View {
  let title: String
  let explanation: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.section.bold())
      Text(explanation)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .background(Color(nsColor: .controlBackgroundColor))
    .overlay(alignment: .bottom) { Divider() }
  }
}

struct EntityBrowserRow: View {
  let entity: Entity
  let subtitle: String
  let action: () -> Void
  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: entity.presentation?.symbol ?? symbol)
          .font(.system(size: 22, weight: .medium))
          .frame(width: 32)
          .foregroundStyle(.blue)
        VStack(alignment: .leading, spacing: 3) {
          Text(entity.name)
            .font(.rowTitle)
          Text(subtitle)
            .font(.small)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer()
        Text(entity.type == .persistence ? "View evidence" : "Open")
          .font(.secondary.bold())
          .foregroundStyle(.blue)
        Image(systemName: "chevron.right")
          .font(.small.bold())
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 8)
      .background(hovering ? Color.accentColor.opacity(0.08) : .clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .pointerCursor()
    .onHover { hovering = $0 }
  }

  private var symbol: String {
    switch entity.type {
    case .application: "app"
    case .persistence: "power"
    case .packageManager: "shippingbox"
    case .shellFramework: "terminal"
    case .package: "shippingbox.fill"
    case .file: "folder"
    default: "circle"
    }
  }
}
