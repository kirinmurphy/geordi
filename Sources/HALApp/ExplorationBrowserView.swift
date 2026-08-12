import HALDomain
import HALVisualization
import SwiftUI

private struct GuideNode: Identifiable {
  let id: String
  let title: String
  let explanation: String
  let symbol: String
}

private struct ConceptualSystemMap: View {
  let destination: AppModel.Destination

  private var nodes: [GuideNode] {
    switch destination {
    case .startup:
      [
        GuideNode(
          id: "declaration", title: "Declaration",
          explanation: "A plist records a request to launch something.", symbol: "doc.text"),
        GuideNode(
          id: "service", title: "Launch service",
          explanation: "macOS evaluates scope, timing, and restart policy.", symbol: "gearshape.2"),
        GuideNode(
          id: "software", title: "Owning software",
          explanation:
            "\(AppBrand.displayName) connects the declaration to an app when evidence supports it.",
          symbol: "app.badge"),
        GuideNode(
          id: "process", title: "Running process",
          explanation: "A separate observation—configuration alone does not prove it ran.",
          symbol: "waveform.path.ecg"),
      ]
    case .storage:
      [
        GuideNode(
          id: "application", title: "Application",
          explanation: "Software reads, writes, downloads, and derives data.", symbol: "app"),
        GuideNode(
          id: "support", title: "Working data",
          explanation: "Settings and support data may be essential or user-authored.",
          symbol: "folder.badge.gearshape"),
        GuideNode(
          id: "rebuildable", title: "Rebuildable data",
          explanation: "Caches and derived artifacts can often be recreated.",
          symbol: "arrow.triangle.2.circlepath"),
        GuideNode(
          id: "decision", title: "Evidence before action",
          explanation: "Size and classification inform a decision; they do not authorize deletion.",
          symbol: "checklist"),
      ]
    case .commandLine:
      [
        GuideNode(
          id: "source", title: "Install source",
          explanation: "A package manager, installer, or user-local location introduces software.",
          symbol: "shippingbox"),
        GuideNode(
          id: "package", title: "Installed package",
          explanation: "A package may be requested directly or pulled in as a dependency.",
          symbol: "cube.box"),
        GuideNode(
          id: "capability", title: "Capability",
          explanation: "Runtimes and tools provide commands used by other software.",
          symbol: "hammer"),
        GuideNode(
          id: "path", title: "Command on PATH",
          explanation: "Shell search order determines which executable a name resolves to.",
          symbol: "terminal"),
      ]
    default: []
    }
  }

  private var title: String {
    switch destination {
    case .startup: "How automatic startup actually works"
    case .storage: "How reclaimable data fits into application storage"
    case .commandLine: "How command-line software becomes available"
    default: "How this system works"
    }
  }

  var body: some View {
    if !nodes.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        Text(title).font(.halSection.bold())
        Text(
          "Follow the arrows through the system. The observations below show what \(AppBrand.displayName) actually found."
        )
        .foregroundStyle(.secondary)
        ViewThatFits(in: .horizontal) {
          wideWorkflow
          compactWorkflow
        }
      }
      .padding(20)
      .background(
        LinearGradient(
          colors: [.blue.opacity(0.10), .purple.opacity(0.06)], startPoint: .topLeading,
          endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 18)
      )
      .overlay { RoundedRectangle(cornerRadius: 18).stroke(.blue.opacity(0.25)) }
    }
  }

  private var wideWorkflow: some View {
    HStack(spacing: 8) {
      ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
        if index > 0 { connector("arrow.right") }
        workflowNode(node).frame(width: 172)
      }
    }
  }

  private var compactWorkflow: some View {
    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
      GridRow {
        workflowNode(nodes[0])
        connector("arrow.right")
        workflowNode(nodes[1])
      }
      GridRow {
        Color.clear.frame(height: 18)
        Color.clear.frame(height: 18)
        connector("arrow.down")
      }
      GridRow {
        workflowNode(nodes[3])
        connector("arrow.left")
        workflowNode(nodes[2])
      }
    }
  }

  private func connector(_ symbol: String) -> some View {
    Image(systemName: symbol)
      .foregroundStyle(.blue)
      .accessibilityHidden(true)
  }

  private func workflowNode(_ node: GuideNode) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: node.symbol).font(.halSection).foregroundStyle(.blue)
      Text(node.title).font(.halRowTitle)
      Text(node.explanation)
        .font(.halSmall)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
    .background(.background.opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
  }

}

private struct ApplicationAnatomyView: View {
  let model: AppModel
  let applications: [Entity]

  private var sample: Entity? { applications.first }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("An application is more than its icon").font(.halSection.bold())
      Text(
        "\(AppBrand.displayName) treats an app as the center of a small system. Choose an app below to replace this anatomy lesson with its real evidence."
      )
      .foregroundStyle(.secondary)
      HStack(spacing: 10) {
        anatomyNode("Installed from", "Source and provenance", "shippingbox")
        connector
        anatomyNode(
          sample?.name ?? "Application bundle", "Executable code and identity", "app.fill",
          emphasized: true)
        connector
        VStack(spacing: 10) {
          anatomyNode("Starts & runs", "Helpers, declarations, processes", "power")
          anatomyNode("Reads & writes", "Support, settings, caches", "folder")
        }
      }
      .padding(16)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }
  }

  private var connector: some View {
    Image(systemName: "arrow.left.and.right").foregroundStyle(.blue).accessibilityHidden(true)
  }

  private func anatomyNode(
    _ title: String, _ detail: String, _ symbol: String, emphasized: Bool = false
  ) -> some View {
    VStack(spacing: 7) {
      Image(systemName: symbol).font(.halSection).foregroundStyle(emphasized ? .white : .blue)
      Text(title).font(.halRowTitle).multilineTextAlignment(.center)
      Text(detail).font(.halSmall).foregroundStyle(emphasized ? .white.opacity(0.85) : .secondary)
        .multilineTextAlignment(.center)
    }
    .padding(14)
    .frame(maxWidth: .infinity, minHeight: 112)
    .background(
      emphasized ? Color.blue : Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12)
    )
    .foregroundStyle(emphasized ? .white : .primary)
  }
}

struct ApplicationBrowserView: View {
  let model: AppModel
  @State private var query = ""

  private var applications: [Entity] {
    model.applications(in: model.selectedApplicationCategoryID)
      .filter {
        query.isEmpty
          || $0.name.localizedCaseInsensitiveContains(query)
          || $0.summary.localizedCaseInsensitiveContains(query)
      }
      .sorted {
        let comparison = $0.name.localizedStandardCompare($1.name)
        if comparison != .orderedSame { return comparison == .orderedAscending }
        return $0.id.rawValue < $1.id.rawValue
      }
  }

  var body: some View {
    VStack(spacing: 0) {
      ExplorationHeader(
        title: model.explorationContext?.title ?? "Choose an application to understand",
        explanation:
          "Select an observed application to open its Application Story, evidence, and bounded relationships."
      )
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          ApplicationAnatomyView(model: model, applications: applications)
          HStack(spacing: 12) {
            TextField("Search applications", text: $query)
              .textFieldStyle(.roundedBorder)
              .frame(maxWidth: 360)
            if !model.applicationCategoryOptions.isEmpty {
              Picker(
                "Application group",
                selection: Binding(
                  get: { model.selectedApplicationCategoryID },
                  set: { model.selectedApplicationCategoryID = $0 }
                )
              ) {
                ForEach(model.applicationCategoryOptions) { category in
                  Text(category.label).tag(Optional(category.id))
                }
              }
              .frame(maxWidth: 260)
            }
            Spacer()
            Text("\(applications.count) observed")
              .font(.halSecondary)
              .foregroundStyle(.secondary)
          }
          if applications.isEmpty {
            ContentUnavailableView(
              model.explorationContext?.emptyTitle ?? "No applications observed",
              systemImage: "app.dashed",
              description: Text(
                query.isEmpty
                  ? model.explorationContext?.emptyMessage ?? ""
                  : "No applications match “\(query)”.")
            )
          } else {
            LazyVStack(spacing: 0) {
              ForEach(applications) { application in
                EntityBrowserRow(
                  entity: application,
                  subtitle: model.applicationSourceLabel(application) ?? application.summary,
                  action: { model.focus(application) }
                )
                Divider()
              }
            }
            .padding(.horizontal, 12)
            .background(
              Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
          }
        }
        .padding(20)
      }
      .scrollIndicators(.visible)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .accessibilityIdentifier("applicationExplorationBrowser")
  }
}

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
          ConceptualSystemMap(destination: model.destination)
          if let context, let presentation, hasMembers(presentation) {
            VStack(alignment: .leading, spacing: 5) {
              Text("What \(AppBrand.displayName) observed on this Mac")
                .font(.halSection.bold())
              Text(observationLead)
                .foregroundStyle(.secondary)
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
        .padding(20)
      }
      .scrollIndicators(.visible)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .accessibilityIdentifier("explorationContextBrowser")
  }

  private var observationLead: String {
    switch model.destination {
    case .startup:
      "Declarations are grouped with the software \(AppBrand.displayName) can connect them to; unresolved declarations stay explicit."
    case .storage:
      "Each location includes its classification, measured size when available, and the application relationship behind it."
    case .commandLine:
      "The inventory is organized as an ecosystem—sources and managers first, capabilities and installed artifacts second."
    default: "Open an observed node to see its bounded evidence and relationships."
    }
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
        .font(.halSubsection.bold())
      Text(section.explanation)
        .font(.halSecondary)
        .foregroundStyle(.secondary)
      ForEach(section.groups) { group in
        DisclosureGroup {
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
        } label: {
          HStack {
            Text(group.title)
              .font(.halRowTitle)
            Spacer()
            Text("\(group.entityIDs.count)")
              .font(.halSmall)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 5)
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
        .font(.halSubsection.bold())
      Text("These entities remain explicit instead of being assigned a guessed category.")
        .font(.halSecondary)
        .foregroundStyle(.secondary)
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

struct ExplorationHeader: View {
  let title: String
  let explanation: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.halSection.bold())
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
          .frame(width: 22)
          .foregroundStyle(.blue)
        VStack(alignment: .leading, spacing: 3) {
          Text(entity.name)
            .font(.halRowTitle)
          Text(subtitle)
            .font(.halSmall)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Spacer()
        Text(entity.type == .persistence ? "View evidence" : "Open")
          .font(.halSecondary.bold())
          .foregroundStyle(.blue)
        Image(systemName: "chevron.right")
          .font(.halSmall.bold())
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 8)
      .background(hovering ? Color.accentColor.opacity(0.08) : .clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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
