import HALDomain
import HALVisualization
import SwiftUI

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
        Text("\(applications.count) applications")
          .font(.halSecondary)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)

      if applications.isEmpty {
        ContentUnavailableView(
          model.explorationContext?.emptyTitle ?? "No applications observed",
          systemImage: "app.dashed",
          description: Text(
            query.isEmpty
              ? model.explorationContext?.emptyMessage ?? ""
              : "No applications match “\(query)”."
          )
        )
      } else {
        List(applications) { application in
          EntityBrowserRow(
            entity: application,
            subtitle: model.applicationSourceLabel(application) ?? application.summary,
            action: { model.focus(application) }
          )
        }
        .listStyle(.inset)
      }
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
      if let context, let presentation, hasMembers(presentation) {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(presentation.sections) { section in
              if !section.groups.isEmpty {
                sectionView(section)
              }
            }
            if !presentation.unassignedEntityIDs.isEmpty {
              unclassifiedSection(presentation.unassignedEntityIDs, context: context)
            }
          }
          .padding(20)
        }
      } else {
        ContentUnavailableView(
          context?.emptyTitle ?? "Nothing observed",
          systemImage: emptySymbol,
          description: Text(context?.emptyMessage ?? "")
        )
      }
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
      "Browse retained roles and discovery sources. HAL does not infer a command’s purpose from its name."
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
    if entity.type == .persistence {
      let state = entity.details.first { $0.label == "State" }?.value
      return ["Startup declaration", state].compactMap { $0 }.joined(separator: " · ")
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
