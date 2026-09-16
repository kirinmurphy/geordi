import AppKit
import GeordiCollectors
import GeordiDataSource
import GeordiDomain
import GeordiVisualization
import SwiftUI

struct OverviewView: View {
  let model: AppModel
  let diagnosticExportAction: () -> Void
  @State private var commandSearch = ""
  @State private var guidedProofPresented = false
  @State private var expandedSoftwareGroups = Set<String>()
  @State private var hoveredSoftwareGroupID: String?
  @State private var applicationFilterPresented = false
  @State private var cliActionsPresented = false

  /// Part C: the onboarding card shows on the Home page until dismissed
  /// or the CLI is actually installed; dismissal state is a persisted
  /// preference.
  private var cliCardVisible: Bool {
    !model.cliOnboardingDismissed
      && model.cliEnablement.status
        != .installed(target: model.cliEnablement.linkLocation + "/" + AppBrand.cliCommand)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 30) {
        if model.isSynthetic, !model.welcomeDismissed {
          WelcomePrompt(
            linkAction: model.linkToMac,
            dismissAction: model.dismissWelcome
          )
        }

        if cliCardVisible {
          CLIOnboardingCard(
            model: model.cliEnablement,
            inventory: model.cliInventory,
            onDismiss: { model.dismissCLIOnboarding() },
            onShowActions: { cliActionsPresented = true }
          )
          .onAppear { Task { await model.refreshCLILinkStatus() } }
        }

        TaskOrientedExploreView(model: model) {
          guidedProofPresented = true
        }

        if model.isSynthetic {
          inventorySection(
            title: "Alerts",
            symbol: "exclamationmark.triangle.fill",
            tint: .red,
            emphasized: true
          ) {
            InventoryRow(
              symbol: "memorychip",
              tint: .red,
              title: "Memory pressure became critical",
              subtitle: "Docker, VS Code, and Brave were the largest contributors",
              trailing: "Today · 9 min"
            ) { model.navigate(to: .performance) }
            Divider()
            InventoryRow(
              symbol: "internaldrive.fill",
              tint: .orange,
              title: "Reclaimable storage is getting large",
              subtitle:
                "\(reclaimAlertSize) of caches and downloads can be rebuilt or fetched again",
              trailing: reclaimAlertSize
            ) { model.navigate(to: .storage) }
          }

          CurrentActivityView()
        } else if model.linkCompletionPending && !model.linkedCompletionDismissed {
          LiveCoverageNotice(model: model, exportAction: diagnosticExportAction)
        }

        applicationInventorySection

        if !packageManagers.isEmpty || !softwareSourceCategories.isEmpty {
          inventorySection(
            title: "Software Sources",
            symbol: "shippingbox"
          ) {
            ForEach(packageManagers) { manager in
              let applications = managedItems(for: manager, type: .application)
              let applicationGroups = classifiedApplicationGroups(applications)
              let packages = managedItems(for: manager, type: .package)
              let requestedPackages = packages.filter {
                detail("Installation reason", in: $0) == "Installed on request"
              }
              let dependencyPackages = packages.filter {
                detail("Installation reason", in: $0) == "Installed as a dependency"
              }
              let unclassifiedPackages = packages.filter {
                detail("Installation reason", in: $0) == nil
                  || detail("Installation reason", in: $0) == "Not recorded"
              }
              InventoryRow(
                symbol: "shippingbox",
                tint: EntityVisualStyle.color(for: .packageManager),
                title: manager.name,
                trailing: "\(applications.count + packages.count) managed"
              ) { model.focus(manager) }
              if !applications.isEmpty {
                ForEach(applicationGroups) { group in
                  softwareDisclosureRow(
                    id: "\(manager.id.rawValue):applications:\(group.id)",
                    title: "\(group.applications.count) \(group.label)",
                    symbol: "app",
                    tint: group.tint
                  ) {
                    ForEach(group.applications) { application in
                      InventoryRow(
                        symbol: "app",
                        tint: EntityVisualStyle.color(for: .application),
                        title: application.name,
                        trailing: "",
                        applicationPath: detail("Path", in: application),
                        compact: true
                      ) { model.focus(application) }
                      .padding(.leading, 44)
                    }
                  }
                }
              }
              softwarePackageGroup(
                manager: manager,
                id: "requested-packages",
                title: "User-installed packages",
                packages: requestedPackages
              )
              softwarePackageGroup(
                manager: manager,
                id: "dependency-packages",
                title: "Dependencies",
                packages: dependencyPackages
              )
              softwarePackageGroup(
                manager: manager,
                id: "packages",
                title: "Packages",
                packages: unclassifiedPackages
              )
            }
            ForEach(softwareSourceCategories) { source in
              let sourceApplications = applications(from: source)
              InventoryRow(
                symbol: "apple.logo",
                tint: .blue,
                title: source.label,
                trailing: "\(sourceApplications.count) applications"
              ) { model.navigate(to: .applications) }
              ForEach(classifiedApplicationGroups(sourceApplications), id: \.id) { group in
                softwareDisclosureRow(
                  id: "\(source.id):\(group.id)",
                  title: "\(group.applications.count) \(group.label)",
                  symbol: "app",
                  tint: group.tint
                ) {
                  ForEach(group.applications) { application in
                    InventoryRow(
                      symbol: "app",
                      tint: EntityVisualStyle.color(for: .application),
                      title: application.name,
                      trailing: "",
                      applicationPath: detail("Path", in: application),
                      compact: true
                    ) { model.focus(application) }
                    .padding(.leading, 44)
                  }
                }
              }
            }
          }
        }

        if !runtimeCapabilities.isEmpty {
          inventorySection(
            title: "Runtimes & Developer Tools",
            symbol: "terminal"
          ) {
            ForEach(Array(runtimeCapabilities.enumerated()), id: \.element.id) {
              index, software in
              if index > 0 { Divider() }
              InventoryRow(
                symbol: "terminal",
                tint: EntityVisualStyle.color(for: software.type),
                title: software.name,
                trailing: foundationTrailingDetail(software)
              ) { model.focus(software) }
            }
          }
        }

        if !commandLineSoftware.isEmpty {
          inventorySection(
            title: "Command-Line Inventory",
            symbol: "terminal"
          ) {
            TextField("Search commands", text: $commandSearch)
              .textFieldStyle(.roundedBorder)
              .accessibilityLabel("Search command-line software")
            ForEach(commandLineSourceGroups) { group in
              softwareDisclosureRow(
                id: "command-line:\(group.id)",
                title: "\(group.items.count) \(group.label.lowercased())",
                symbol: group.symbol,
                tint: .secondary
              ) {
                ForEach(group.items) { software in
                  InventoryRow(
                    symbol: "terminal",
                    tint: .secondary,
                    title: software.name,
                    trailing: detail("Executable", in: software) ?? "",
                    compact: true
                  ) { model.focus(software) }
                  .padding(.leading, 44)
                }
              }
            }
          }
        }

        if !reclaimCandidates.isEmpty {
          inventorySection(
            title: "Reclaimable Data",
            subtitle: "Caches and generated files that their owning tools can recreate.",
            symbol: "arrow.3.trianglepath",
            emphasized: true,
            headerActionTitle: model.isSynthetic ? "Reclaim File Space" : "Review Roots",
            headerAction: { model.navigate(to: .storage) }
          ) {
            ForEach(Array(reclaimCandidates.enumerated()), id: \.element.id) { index, file in
              if index > 0 { Divider() }
              InventoryRow(
                symbol: "folder",
                tint: .green,
                title: file.name,
                trailing:
                  model.isSynthetic
                  ? detail("Synthetic size", in: file) ?? ""
                  : detail("Size", in: file) ?? "Not collected"
              ) { model.focus(file) }
            }
          }
        }
      }
      .padding(28)
      .frame(maxWidth: 1_050, alignment: .topLeading)
      .frame(maxWidth: .infinity, alignment: .top)
    }
    .scrollIndicators(.visible)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
      if cliActionsPresented {
        CLIActionsPopup(
          inventory: model.cliInventory,
          linkLocation: model.cliEnablement.linkLocation,
          onClose: { cliActionsPresented = false }
        )
        .transition(.opacity)
        .zIndex(10)
      }
    }
    .animation(.easeInOut(duration: 0.15), value: cliActionsPresented)
    .sheet(isPresented: $guidedProofPresented) {
      GuidedProofView(model: model) {
        guidedProofPresented = false
      }
    }
  }

  private var applicationInventorySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "macwindow.on.rectangle")
        Text("Applications:")
        if !model.isSynthetic, let configuration = model.applicationClassifications {
          Button {
            applicationFilterPresented.toggle()
          } label: {
            HStack(spacing: 5) {
              Text(selectedApplicationCategoryLabel)
                .font(.section.bold())
                .underline()
              Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .bold))
            }
          }
          .buttonStyle(.plain)
          .hoverHighlight(hPadding: 4, vPadding: 2)
          .fixedSize()
          .popover(isPresented: $applicationFilterPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
              ForEach(model.applicationCategoryOptions) { category in
                ApplicationFilterOption(
                  label: category.filterLabel ?? category.label,
                  isSelected: model.selectedApplicationCategoryID == category.id
                ) {
                  selectApplicationCategory(category.id)
                }
              }
              Divider()
              ApplicationFilterOption(
                label: configuration.allApplicationsLabel,
                isSelected: model.selectedApplicationCategoryID == nil
              ) {
                selectApplicationCategory(nil)
              }
            }
            .padding(8)
            .frame(minWidth: 220)
          }
          .accessibilityLabel("Application filter: \(selectedApplicationCategoryLabel)")
        } else {
          Text("User installed").underline()
        }
        Spacer()
        if !model.isSynthetic {
          let counts = model.applicationScopeCounts
          Text("\(counts.visible) shown · \(counts.hidden) in other groups")
            .font(.secondary)
            .foregroundStyle(.secondary)
        }
      }
      .font(.section.bold())

      VStack(spacing: 0) {
        if applications.isEmpty {
          Text("No applications match this filter.")
            .font(.secondary)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        } else {
          ForEach(applications) { application in
            InventoryRow(
              symbol: application.presentation?.symbol ?? "app",
              tint: application.presentation.map { color(for: $0.tint) } ?? .accentColor,
              title: application.name,
              trailing: application.presentation?.trailingDetailLabel.flatMap {
                detail($0, in: application)
              } ?? model.applicationSourceLabel(application)
                ?? detail("Current state", in: application) ?? "",
              applicationPath: detail("Path", in: application)
            ) { model.focus(application) }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
      .overlay {
        RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.16))
      }
    }
  }

  private var selectedApplicationCategoryLabel: String {
    guard
      let selectedID = model.selectedApplicationCategoryID,
      let category = model.applicationClassifications?.categories.first(where: {
        $0.id == selectedID
      })
    else {
      return model.applicationClassifications?.allApplicationsLabel ?? "All"
    }
    return category.filterLabel ?? category.label
  }

  private var applications: [Entity] {
    model.applications(in: model.selectedApplicationCategoryID)
  }

  private struct SoftwareApplicationGroup: Identifiable {
    let id: String
    let label: String
    let tint: Color
    let applications: [Entity]
  }

  private var softwareSourceCategories: [ApplicationClassificationCategory] {
    guard !model.isSynthetic, let configuration = model.applicationClassifications else {
      return []
    }
    return configuration.categories.filter { source in
      source.kind == .source && source.showsInSoftwareSources
        && !packageManagers.contains {
          $0.id.rawValue == "package-manager:\(source.id)"
        }
    }
  }

  private func applications(
    from source: ApplicationClassificationCategory
  ) -> [Entity] {
    guard let configuration = model.applicationClassifications else { return [] }
    return model.fixture.entities.filter { application in
      guard
        application.type == .application,
        let path = detail("Path", in: application)
      else { return false }
      return configuration.source(
        forApplicationPath: path,
        platformBinary: nil,
        details: application.details
      )?.id == source.id
    }.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  private func classifiedApplicationGroups(
    _ applications: [Entity]
  ) -> [SoftwareApplicationGroup] {
    guard let classifications = model.applicationClassifications else {
      return applications.isEmpty
        ? []
        : [
          SoftwareApplicationGroup(
            id: "applications",
            label: applications.count == 1 ? "app" : "apps",
            tint: EntityVisualStyle.color(for: .application),
            applications: applications
          )
        ]
    }
    let grouped = Dictionary(grouping: applications) { application in
      guard let path = detail("Path", in: application) else { return "other" }
      return classifications.category(
        forApplicationPath: path,
        platformBinary: model.platformBinaryEvidence(for: application),
        details: application.details
      ).id
    }
    return classifications.categories
      .filter { $0.kind == .scope }
      .sorted {
        if $0.displayOrder != $1.displayOrder {
          return ($0.displayOrder ?? .max) < ($1.displayOrder ?? .max)
        }
        return $0.label < $1.label
      }
      .compactMap { category in
        guard let members = grouped[category.id], !members.isEmpty else { return nil }
        return SoftwareApplicationGroup(
          id: category.id,
          label: category.label,
          tint: EntityVisualStyle.color(for: .application),
          applications: members
        )
      }
  }

  private func selectApplicationCategory(_ categoryID: String?) {
    model.selectedApplicationCategoryID = categoryID
    applicationFilterPresented = false
  }

  @ViewBuilder
  private func softwarePackageGroup(
    manager: Entity,
    id: String,
    title: String,
    packages: [Entity]
  ) -> some View {
    if !packages.isEmpty {
      softwareDisclosureRow(
        id: "\(manager.id.rawValue):\(id)",
        title: "\(packages.count) \(title.lowercased())",
        symbol: "cube.box",
        tint: .purple
      ) {
        ForEach(packages) { package in
          InventoryRow(
            symbol: "cube.box",
            tint: EntityVisualStyle.color(for: .package),
            title: package.name,
            trailing: detail("Runtime dependencies", in: package).map {
              "Uses \($0)"
            } ?? "",
            compact: true
          ) { model.focus(package) }
          .padding(.leading, 44)
        }
      }
    }
  }

  @ViewBuilder
  private func softwareDisclosureRow<Content: View>(
    id: String,
    title: String,
    symbol: String,
    tint: Color,
    @ViewBuilder content: () -> Content
  ) -> some View {
    let expanded = expandedSoftwareGroups.contains(id)
    Button {
      if expanded {
        expandedSoftwareGroups.remove(id)
      } else {
        expandedSoftwareGroups.insert(id)
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: symbol)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(tint)
          .frame(width: 28, height: 28)
        Text(title)
          .font(.rowTitle)
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.leading, 22)
      .padding(.trailing, 16)
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .pointerCursor()
    .background(
      hoveredSoftwareGroupID == id
        ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.035)
    )
    .overlay(alignment: .bottom) {
      Rectangle().fill(Color.secondary.opacity(0.16)).frame(height: 1)
    }
    .padding(.horizontal, -16)
    .onHover { hovering in
      hoveredSoftwareGroupID = hovering ? id : nil
    }
    if expanded {
      content()
    }
  }

  private var reclaimCandidates: [Entity] {
    model.reclaimCandidates
  }

  /// The alert's size figure is derived from the graph, never hard-coded:
  /// the synthetic profile's "Synthetic size" details sum to the advertised
  /// total. Empty synthetic sizes fall back to a count-based summary.
  private var reclaimAlertSize: String {
    let gigabytes = reclaimCandidates.compactMap { file -> Double? in
      guard
        let raw = file.details.first(where: { $0.label == "Synthetic size" })?.value
      else { return nil }
      return Double(raw.prefix { $0.isNumber || $0 == "." })
    }.reduce(0, +)
    if gigabytes > 0 {
      return String(format: "%.1f GB", gigabytes)
    }
    return "\(reclaimCandidates.count) locations"
  }

  private var packageManagers: [Entity] {
    model.fixture.entities.filter {
      $0.type == .packageManager
    }.sorted {
      return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  private var runtimeCapabilities: [Entity] {
    model.fixture.entities.filter {
      $0.id.rawValue.hasPrefix("runtime-availability:")
    }.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  private func managedItems(for manager: Entity, type: EntityType) -> [Entity] {
    var ownedIDs = Set(
      model.fixture.relationships.filter {
        $0.source == manager.id && $0.type == .owns
      }.map(\.target)
    )
    if type == .application {
      let packageIDs = Set(
        model.fixture.entities.filter {
          ownedIDs.contains($0.id) && $0.type == .package
        }.map(\.id)
      )
      ownedIDs.formUnion(
        model.fixture.relationships.filter {
          packageIDs.contains($0.source) && $0.type == .owns
        }.map(\.target)
      )
    }
    return model.fixture.entities.filter {
      ownedIDs.contains($0.id) && $0.type == type
    }.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  private func softwareKindHeader(_ title: String, symbol: String, tint: Color) -> some View {
    Label(title, systemImage: symbol)
      .font(.small.bold())
      .foregroundStyle(tint)
      .textCase(.uppercase)
      .padding(.horizontal, 16)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tint.opacity(0.14))
      .overlay(alignment: .leading) {
        Rectangle().fill(tint.opacity(0.75)).frame(width: 4)
      }
  }

  private var commandLineSoftware: [Entity] {
    model.fixture.entities.filter {
      $0.id.rawValue.hasPrefix("command-line-software:")
        && $0.detail(.package) == nil
    }.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  private var filteredCommandLineSoftware: [Entity] {
    commandLineSoftware.filter {
      commandSearch.isEmpty
        || $0.name.localizedCaseInsensitiveContains(commandSearch)
        || $0.details.contains { $0.value.localizedCaseInsensitiveContains(commandSearch) }
    }
  }

  private struct CommandLineSourceGroup: Identifiable {
    let id: String
    let label: String
    let symbol: String
    let items: [Entity]
  }

  private var commandLineSourceGroups: [CommandLineSourceGroup] {
    Dictionary(grouping: filteredCommandLineSoftware) {
      $0.detail(.discoveredFrom) ?? "Other command location"
    }
    .map { label, items in
      let isSystem = label.localizedCaseInsensitiveContains("macOS system")
      let isUser = label.localizedCaseInsensitiveContains("user")
      return CommandLineSourceGroup(
        id: label,
        label: label,
        symbol: isSystem ? "apple.logo" : (isUser ? "person.crop.circle" : "externaldrive"),
        items: items
      )
    }
    .sorted { $0.label < $1.label }
  }

  private func foundationTrailingDetail(_ entity: Entity) -> String {
    if entity.id.rawValue.hasPrefix("runtime-availability:") {
      let version = detail("Version", in: entity) ?? "Version unavailable"
      let active = detail("Active instances", in: entity) ?? "0"
      return "\(version) · \(active) active"
    }
    if let version = detail("Version", in: entity) { return version }
    if let versions = detail("Installed versions", in: entity) { return versions }
    if let formulae = detail("Installed formulae", in: entity) {
      return "\(formulae) formulae"
    }
    if let packages = detail("Installed packages", in: entity) {
      return "\(packages) packages"
    }
    return ""
  }

  private func detail(_ label: String, in entity: Entity) -> String? {
    entity.details.first { $0.label == label }?.value
  }

  private func color(for tint: EntityPresentationTint) -> Color {
    switch tint {
    case .accent: .accentColor
    case .blue: .blue
    case .cyan: .cyan
    case .green: .green
    case .mint: .mint
    case .orange: .orange
    case .purple: .purple
    case .red: .red
    }
  }

  private func inventorySection<HeaderAccessory: View, Content: View>(
    title: String,
    subtitle: String? = nil,
    symbol: String,
    tint: Color = .primary,
    emphasized: Bool = false,
    headerActionTitle: String? = nil,
    headerAction: (() -> Void)? = nil,
    @ViewBuilder headerAccessory: () -> HeaderAccessory = { EmptyView() },
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Label(title, systemImage: symbol)
          .font(.section.bold())
          .foregroundStyle(tint)
        Spacer()
        headerAccessory()
        if let headerActionTitle, let headerAction {
          Button(action: headerAction) {
            Text(headerActionTitle)
          }
          .buttonStyle(AppButtonStyle(.inlineCTA))
          .accessibilityHint("Open reclaimable storage review")
        }
      }
      VStack(spacing: 0) {
        content()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        emphasized ? tint.opacity(0.08) : Color(nsColor: .controlBackgroundColor),
        in: RoundedRectangle(cornerRadius: 16)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 16).stroke(
          emphasized ? tint.opacity(0.45) : Color.secondary.opacity(0.16),
          lineWidth: emphasized ? 1.5 : 1
        )
      }
    }
  }
}
