import AppKit
import HALCollectors
import HALDataSource
import HALDomain
import HALVisualization
import SwiftUI

struct ContentView: View {
  @State private var model: AppModel
  @State private var unlinkConfirmationPresented = false
  @State private var unlinkError: String?
  @State private var diagnosticExportError: String?
  @State private var linkedStatusExpanded = false

  init(
    configuration: AppConfiguration,
    applicationClassifications: ApplicationClassificationConfiguration?,
    syntheticProvider: any GraphSnapshotProvider,
    preferences: any DataSourcePreferenceStore,
    userDataStore: HALUserDataStore?,
    liveSnapshot: @escaping @Sendable () throws -> GraphSnapshot
  ) {
    _model = State(
      initialValue: AppModel(
        configuration: configuration,
        applicationClassifications: applicationClassifications,
        syntheticProvider: syntheticProvider,
        preferences: preferences,
        userDataStore: userDataStore,
        liveSnapshot: liveSnapshot
      )
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      NavigationSplitView {
        sidebar
      } detail: {
        VStack(spacing: 0) {
          notificationSlot
          if model.destination != .overview {
            header
          }
          switch model.destination {
          case .overview:
            OverviewView(
              model: model,
              diagnosticExportAction: exportRedactedDiagnostics
            )
          case .filesystem:
            FilesystemMapView(model: model)
          case .shellPath:
            ShellPathVisualizerView()
          case .entity(let id):
            if let entity = model.fixture.entity(id), entity.type == .application {
              ApplicationStoryView(model: model, application: entity)
            } else {
              AtlasDetailView(model: model)
            }
          default:
            AtlasDetailView(model: model)
          }
        }
      }
      .navigationSplitViewStyle(.balanced)

      dataFreshnessFooter
    }
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        SearchField(
          query: $model.searchQuery,
          results: model.searchResults,
          onSelect: model.focus
        )
      }
    }
    .overlay {
      if model.referencePresented {
        ZStack {
          Button {
            model.referencePresented = false
          } label: {
            Color.black.opacity(0.24)
              .ignoresSafeArea()
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Close map explanation")

          SystemReferenceView {
            model.referencePresented = false
          }
          .frame(maxWidth: 1_220, maxHeight: 820)
          .padding(28)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
        .zIndex(20)
      }
    }
    .overlay {
      if let entityType = model.entityTypeReferencePresented,
        let referenceItem = ReferenceCatalog.item(forEntityType: entityType)
      {
        ZStack {
          Button {
            model.entityTypeReferencePresented = nil
          } label: {
            Color.black.opacity(0.18)
              .ignoresSafeArea()
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Close node type explanation")

          ReferenceConceptPanel(item: referenceItem) {
            model.entityTypeReferencePresented = nil
          }
          .padding(28)
          .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .zIndex(21)
      }
    }
    .overlay {
      if model.collectionActivity == .initialLink {
        InitialLinkOverlay(cancelAction: model.cancelInitialLink)
          .zIndex(30)
      }
    }
    .animation(.easeInOut(duration: 0.18), value: model.referencePresented)
    .animation(
      .spring(response: 0.32, dampingFraction: 0.86),
      value: model.entityTypeReferencePresented
    )
    .task {
      model.resumeLinkedMacIfNeeded()
    }
    .confirmationDialog(
      "Return to the fictional Mac?",
      isPresented: $unlinkConfirmationPresented,
      titleVisibility: .visible
    ) {
      Button("Export Backup, then Return") {
        exportAndUnlink()
      }
      Button("Delete Compiled Data and Return", role: .destructive) {
        unlinkWithoutBackup()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "HAL will disconnect live collection and return to the fictional profile. A backup contains the last compiled application inventory."
      )
    }
    .alert(
      "Unable to Return",
      isPresented: Binding(
        get: { unlinkError != nil },
        set: { if !$0 { unlinkError = nil } }
      )
    ) {
      Button("OK") { unlinkError = nil }
    } message: {
      Text(unlinkError ?? "")
    }
    .alert(
      "Unable to Export Diagnostics",
      isPresented: Binding(
        get: { diagnosticExportError != nil },
        set: { if !$0 { diagnosticExportError = nil } }
      )
    ) {
      Button("OK") { diagnosticExportError = nil }
    } message: {
      Text(diagnosticExportError ?? "")
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 5) {
        Text("HAL")
          .font(.halDisplay.bold())
        Text("Understand this Mac")
          .foregroundStyle(.secondary)
      }
      .padding(20)

      List {
        Section {
          navigationButton("This Mac", symbol: "laptopcomputer", destination: .overview)
        }
        Section("Explore") {
          navigationButton(
            "Installed software", symbol: "square.grid.2x2", destination: .applications)
          navigationButton(
            "Filesystem Map", symbol: "point.3.connected.trianglepath.dotted",
            destination: .filesystem)
          if model.isSynthetic {
            navigationButton("Storage", symbol: "internaldrive", destination: .storage)
            navigationButton(
              "Performance", symbol: "gauge.with.dots.needle.50percent",
              destination: .performance)
          }
        }
        Section("Installed applications") {
          ForEach(model.fixture.entities.filter { $0.type == .application }) { application in
            Button {
              model.focus(application)
            } label: {
              HStack {
                Image(systemName: application.presentation?.symbol ?? "app")
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                  Text(application.name)
                  Text(application.details.first?.value ?? application.summary)
                    .font(.halSmall)
                    .foregroundStyle(.secondary)
                }
              }
              .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
          }
        }
        Section("Developer tools") {
          ForEach(
            model.fixture.entities.filter {
              [.packageManager, .shellFramework, .package].contains($0.type)
            }
          ) { tool in
            Button {
              model.focus(tool)
            } label: {
              HStack {
                Image(systemName: "terminal")
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                  Text(tool.name)
                  Text(tool.type.label)
                    .font(.halSmall)
                    .foregroundStyle(.secondary)
                }
              }
            }
            .buttonStyle(.plain)
          }
        }
      }

      Divider()
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: model.isSynthetic ? "desktopcomputer" : "link")
            .foregroundStyle(.secondary)
          VStack(alignment: .leading, spacing: 2) {
            Text(model.isSynthetic ? "Fictional profile" : "Linked to this Mac")
              .font(.halSmall.weight(.semibold))
            Text(model.isSynthetic ? "No machine access" : "Read-only application access")
              .font(.halSmall)
              .foregroundStyle(.secondary)
          }
          Spacer()
          if model.isSynthetic {
            Button("Link") { model.linkToMac() }
              .disabled(model.isCollecting)
          }
        }
        if !model.isSynthetic {
          HStack(spacing: 8) {
            Button("Check again") { model.refreshLiveData() }
            Button("Return to fictional Mac…") {
              unlinkConfirmationPresented = true
            }
          }
          .controlSize(.small)
          .buttonStyle(.bordered)
          .disabled(model.isCollecting)
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("linkedDataActions")
        }
      }
      .padding(14)
    }
    .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 280)
  }

  private var header: some View {
    HStack(spacing: 12) {
      HStack(spacing: 6) {
        ForEach(Array(model.breadcrumb.enumerated()), id: \.offset) { index, title in
          if index > 0 {
            Image(systemName: "chevron.right")
              .font(.halSmall)
              .foregroundStyle(.tertiary)
          }
          if index == 0, title == "Home", model.destination != .overview {
            Button("Home") {
              model.navigate(to: .overview)
            }
            .buttonStyle(.plain)
            .font(.halSecondary.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityHint("Return to the inventory")
          } else {
            Text(title)
              .font(index == model.breadcrumb.count - 1 ? .halRowTitle : .halSecondary)
              .foregroundStyle(index == model.breadcrumb.count - 1 ? .primary : .secondary)
          }
        }
      }
      Spacer()
    }
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity, minHeight: 44)
    .background(Color(nsColor: .windowBackgroundColor))
    .overlay(alignment: .bottom) {
      Divider()
    }
    .zIndex(1)
  }

  private var dataFreshnessFooter: some View {
    TimelineView(.periodic(from: .now, by: 30)) { context in
      let freshness = model.dataFreshness(at: context.date)
      HStack(spacing: 8) {
        Spacer()
        Button {
          linkedStatusExpanded.toggle()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: freshnessSymbol(freshness))
            Text(freshnessText(freshness))
            if !model.isSynthetic {
              Image(systemName: "chevron.up")
                .font(.halSmall)
            }
          }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $linkedStatusExpanded, arrowEdge: .bottom) {
          CollectionHealthPanel(model: model, exportAction: exportRedactedDiagnostics)
        }
      }
      .foregroundStyle(freshnessColor(freshness))
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, minHeight: 28)
      .background(Color(nsColor: .controlBackgroundColor))
      .overlay(alignment: .top) {
        Divider()
      }
      .help(
        model.scanContext.environment == .synthetic
          ? "This is a deterministic fixture, not a reading from this Mac."
          : "Freshness reflects when HAL collected this snapshot and whether collection was complete."
      )
      .accessibilityElement(children: .combine)
      .accessibilityLabel(freshnessText(freshness))
      .accessibilityIdentifier("dataFreshnessFooter")
    }
  }

  private func freshnessText(_ freshness: FreshnessState) -> String {
    if model.scanContext.environment == .synthetic {
      return "Deterministic fixture"
    }
    let state =
      switch freshness {
      case .fresh: "Observed recently"
      case .aging: "Observation is aging"
      case .stale: "Observation is stale"
      case .partial: "Partial observation"
      case .unavailable: "Data unavailable"
      case .permissionDenied: "Permission required"
      case .neverCollected: "Not yet observed"
      }
    guard let completedAt = model.scanContext.completedAt else { return state }
    return "\(state) · \(completedAt.formatted(date: .abbreviated, time: .shortened))"
  }

  private func freshnessSymbol(_ freshness: FreshnessState) -> String {
    switch freshness {
    case .fresh: "checkmark.circle.fill"
    case .aging: "clock.fill"
    case .stale: "exclamationmark.circle.fill"
    case .partial: "circle.lefthalf.filled"
    case .unavailable: "questionmark.circle.fill"
    case .permissionDenied: "lock.circle.fill"
    case .neverCollected: "circle.dashed"
    }
  }

  private func freshnessColor(_ freshness: FreshnessState) -> Color {
    switch freshness {
    case .fresh: .secondary
    case .aging: .orange
    case .stale: .red
    case .partial: .orange
    case .unavailable: .secondary
    case .permissionDenied: .orange
    case .neverCollected: .secondary
    }
  }

  private var notificationSlot: some View {
    Group {
      if let collectionError = model.collectionError {
        AppBanner(
          severity: .alert,
          title: "Collection problem",
          message: collectionError,
          allowsDismissal: true,
          actionTitle: model.isSynthetic ? "Try linking again" : "Check again",
          action: {
            if model.isSynthetic {
              model.linkToMac()
            } else {
              model.refreshLiveData()
            }
          }
        )
      } else if model.isSynthetic {
        AppBanner(
          severity: .warning,
          title: "Fictional Mac",
          message:
            "Everything shown is deterministic synthetic data. HAL is not scanning this Mac.",
          allowsDismissal: true,
          actionTitle: model.isCollecting ? "Linking…" : "Link to your Mac",
          action: model.linkToMac
        )
      }
    }
  }

  private func unlinkWithoutBackup() {
    do {
      try model.unlinkMac()
    } catch {
      unlinkError = error.localizedDescription
    }
  }

  private func exportAndUnlink() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "HAL-live-data-backup.json"
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try model.unlinkMac(backupURL: url)
    } catch {
      unlinkError = error.localizedDescription
    }
  }

  private func exportRedactedDiagnostics() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "HAL-redacted-diagnostic.json"
    panel.allowedContentTypes = [.json]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try RedactedDiagnosticExporter.write(model.currentSnapshot, to: url)
    } catch {
      diagnosticExportError = error.localizedDescription
    }
  }

  private func navigationButton(
    _ title: String,
    symbol: String,
    destination: AppModel.Destination
  ) -> some View {
    Button {
      model.navigate(to: destination)
    } label: {
      Label(title, systemImage: symbol)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct AppBanner: View {
  enum Severity {
    case success
    case info
    case warning
    case alert

    var color: Color {
      switch self {
      case .success: .green
      case .info: .blue
      case .warning: .orange
      case .alert: .red
      }
    }

    var symbol: String {
      switch self {
      case .success: "checkmark.circle.fill"
      case .info: "info.circle.fill"
      case .warning: "exclamationmark.triangle.fill"
      case .alert: "exclamationmark.octagon.fill"
      }
    }
  }

  let severity: Severity
  let title: String
  let message: String
  let allowsDismissal: Bool
  let actionTitle: String?
  let action: (() -> Void)?
  @State private var isVisible = true

  init(
    severity: Severity,
    title: String,
    message: String,
    allowsDismissal: Bool = false,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.severity = severity
    self.title = title
    self.message = message
    self.allowsDismissal = allowsDismissal
    self.actionTitle = actionTitle
    self.action = action
  }

  var body: some View {
    if isVisible {
      HStack(spacing: 10) {
        Image(systemName: severity.symbol)
          .foregroundStyle(severity.color)
        Text(title.uppercased())
          .font(.halSmall.bold())
        Text(message)
          .font(.halSmall)
          .foregroundStyle(.secondary)
        Spacer()
        if let actionTitle, let action {
          Button(actionTitle, action: action)
            .controlSize(.small)
        }
        if allowsDismissal {
          Button {
            withAnimation(.easeInOut(duration: 0.18)) {
              isVisible = false
            }
          } label: {
            Image(systemName: "xmark")
              .font(.halSmall.bold())
          }
          .buttonStyle(.plain)
          .help("Dismiss notification")
          .accessibilityLabel("Dismiss \(title)")
        }
      }
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, minHeight: 34)
      .background(severity.color.opacity(0.1))
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(severity.color)
          .frame(width: 3)
      }
      .overlay(alignment: .bottom) {
        Divider()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .transition(.move(edge: .top).combined(with: .opacity))
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(title). \(message)")
    }
  }
}

private struct OverviewView: View {
  let model: AppModel
  let diagnosticExportAction: () -> Void
  @State private var commandSearch = ""
  @State private var guidedProofPresented = false
  @State private var expandedSoftwareGroups = Set<String>()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 30) {
        if model.isSynthetic, !model.welcomeDismissed {
          WelcomePrompt(
            linkAction: model.linkToMac,
            dismissAction: model.dismissWelcome
          )
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
              subtitle: "24.4 GB of synthetic cache and downloads can be rebuilt or fetched again",
              trailing: "24.4 GB"
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
            subtitle: "Package managers with their observed applications and packages",
            symbol: "shippingbox"
          ) {
            ForEach(packageManagers) { manager in
              let applications = managedItems(for: manager, type: .application)
              let packages = managedItems(for: manager, type: .package)
              InventoryRow(
                symbol: "shippingbox",
                tint: EntityVisualStyle.color(for: .packageManager),
                title: manager.name,
                trailing: "\(applications.count + packages.count) managed"
              ) { model.focus(manager) }
              if !applications.isEmpty {
                softwareDisclosureRow(
                  id: "\(manager.id.rawValue):applications",
                  title: applications.count == 1 ? "1 app" : "\(applications.count) apps",
                  symbol: "app",
                  tint: .blue
                ) {
                  ForEach(applications) { application in
                    InventoryRow(
                      symbol: "app",
                      tint: EntityVisualStyle.color(for: .application),
                      title: application.name,
                      trailing: "Application",
                      applicationPath: detail("Path", in: application),
                      compact: true
                    ) { model.focus(application) }
                    .padding(.leading, 44)
                  }
                }
              }
              if !packages.isEmpty {
                softwareDisclosureRow(
                  id: "\(manager.id.rawValue):packages",
                  title: packages.count == 1 ? "1 package" : "\(packages.count) packages",
                  symbol: "cube.box",
                  tint: .purple
                ) {
                  ForEach(packages) { package in
                    InventoryRow(
                      symbol: "cube.box",
                      tint: EntityVisualStyle.color(for: .package),
                      title: package.name,
                      trailing: "Package",
                      compact: true
                    ) { model.focus(package) }
                    .padding(.leading, 44)
                  }
                }
              }
            }
            ForEach(softwareSourceCategories) { source in
              let sourceApplications = applications(from: source)
              InventoryRow(
                symbol: "apple.logo",
                tint: .blue,
                title: source.label,
                trailing: "\(sourceApplications.count) applications"
              ) { model.navigate(to: .applications) }
              ForEach(appStoreApplicationGroups(sourceApplications), id: \.id) { group in
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
                      trailing: "Application",
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
            subtitle: "Executable capabilities that answered a version query",
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
            title: "Other Command-Line Software",
            subtitle:
              "\(commandLineSoftware.count) executable tools observed but not capability-classified",
            symbol: "terminal"
          ) {
            TextField("Search commands", text: $commandSearch)
              .textFieldStyle(.roundedBorder)
              .accessibilityLabel("Search command-line software")
            if systemCommandCount > 0 {
              Text("\(systemCommandCount) macOS system commands grouped")
                .font(.halSecondary.weight(.semibold))
                .foregroundStyle(.secondary)
            }
            DisclosureGroup("Show all discovered commands") {
              ForEach(Array(filteredCommandLineSoftware.enumerated()), id: \.element.id) {
                index, software in
                if index > 0 { Divider() }
                InventoryRow(
                  symbol: "terminal",
                  tint: .secondary,
                  title: software.name,
                  trailing: detail("Package", in: software) ?? "Unclassified"
                ) { model.focus(software) }
              }
              .padding(.top, 8)
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
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .sheet(isPresented: $guidedProofPresented) {
      GuidedProofView(model: model) {
        guidedProofPresented = false
      }
    }
  }

  private var applicationInventorySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "square.grid.2x2")
        Text("Applications:")
        if !model.isSynthetic, let configuration = model.applicationClassifications {
          Menu {
            Button(configuration.allApplicationsLabel) {
              model.selectedApplicationCategoryID = nil
            }
            Divider()
            ForEach(model.applicationCategoryOptions) { category in
              Button {
                model.selectedApplicationCategoryID = category.id
              } label: {
                if model.selectedApplicationCategoryID == category.id {
                  Label(category.label, systemImage: "checkmark")
                } else {
                  Text(category.label)
                }
              }
            }
          } label: {
            HStack(spacing: 5) {
              Text(selectedApplicationCategoryLabel)
                .underline()
              Image(systemName: "chevron.down")
                .font(.halSmall.bold())
            }
          }
          .menuIndicator(.hidden)
          .menuStyle(.borderlessButton)
          .fixedSize()
          .accessibilityLabel("Application filter: \(selectedApplicationCategoryLabel)")
        } else {
          Text("User installed").underline()
        }
        Spacer()
        if !model.isSynthetic {
          let counts = model.applicationScopeCounts
          Text("\(counts.visible) shown · \(counts.hidden) in other groups")
            .font(.halSecondary)
            .foregroundStyle(.secondary)
        }
      }
      .font(.halSection.bold())

      VStack(spacing: 0) {
        if applications.isEmpty {
          Text("No applications match this filter.")
            .font(.halSecondary)
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
      return model.applicationClassifications?.allApplicationsLabel ?? "All Applications"
    }
    return category.label
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
    return configuration.categories.filter {
      $0.kind == .source && $0.showsInSoftwareSources
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

  private func appStoreApplicationGroups(
    _ applications: [Entity]
  ) -> [SoftwareApplicationGroup] {
    guard let classifications = model.applicationClassifications else { return [] }
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
      .sorted { $0.priority > $1.priority }
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
          .foregroundStyle(tint)
          .frame(width: 25, height: 25)
        Text(title)
          .font(.halRowTitle)
        Spacer()
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
          .font(.halSmall.bold())
          .foregroundStyle(.secondary)
      }
      .padding(.leading, 22)
      .padding(.trailing, 16)
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background(Color.secondary.opacity(0.035))
    .overlay(alignment: .bottom) {
      Rectangle().fill(Color.secondary.opacity(0.16)).frame(height: 1)
    }
    .padding(.horizontal, -16)
    if expanded {
      content()
    }
  }

  private var reclaimCandidates: [Entity] {
    if !model.isSynthetic {
      return model.fixture.entities.filter {
        $0.type == .file && detail("Rebuildability", in: $0) != nil
      }
    }
    let ids = Set(
      model.fixture.relationships.filter { $0.target == "resource.storage" }.map(\.source))
    return model.fixture.entities.filter { ids.contains($0.id) && $0.type == .file }
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
      .font(.halSmall.bold())
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
        && detail("Package", in: $0) == nil
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

  private var systemCommandCount: Int {
    commandLineSoftware.filter {
      detail("Discovered from", in: $0) == "macOS system executable directory"
    }.count
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
          .font(.halSection.bold())
          .foregroundStyle(tint)
        Spacer()
        headerAccessory()
        if let subtitle {
          Text(subtitle)
            .font(.halSecondary)
            .foregroundStyle(.secondary)
        }
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

private struct CurrentActivityView: View {
  private let metrics: [ActivityMetric] = [
    ActivityMetric(
      title: "CPU", value: "38%", context: "Docker is using the most", symbol: "cpu", tint: .orange),
    ActivityMetric(
      title: "Memory", value: "12.9 GB", context: "Pressure is normal", symbol: "memorychip",
      tint: .green),
    ActivityMetric(
      title: "Running apps", value: "5", context: "All are recognized", symbol: "app.badge",
      tint: .blue),
    ActivityMetric(
      title: "Background activity", value: "9", context: "Processes and helpers",
      symbol: "gearshape.2", tint: .cyan),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Label("Current activity", systemImage: "waveform.path.ecg")
          .font(.halSection.bold())
        Spacer()
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
        ForEach(metrics) { metric in
          VStack(alignment: .leading, spacing: 7) {
            Label(metric.title, systemImage: metric.symbol)
              .font(.halSecondary.weight(.semibold))
              .foregroundStyle(metric.tint)
            Text(metric.value)
              .font(.halSection.bold())
            Text(metric.context)
              .font(.halSmall)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
          .padding(14)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
          .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(metric.tint.opacity(0.18))
          }
        }
      }
    }
  }

  private struct ActivityMetric: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let context: String
    let symbol: String
    let tint: Color
  }
}

private struct WelcomePrompt: View {
  let linkAction: () -> Void
  let dismissAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Welcome to HAL", systemImage: "sparkles")
          .font(.halSection.bold())
        Spacer()
        Button(action: dismissAction) {
          Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss welcome")
      }
      Text(
        "HAL explains the software and activity on a Mac while keeping observations, evidence, and uncertainty visible."
      )
      Text(
        "You are currently exploring a fictional operating system. Link your Mac when you are ready to collect a read-only application inventory."
      )
      .foregroundStyle(.secondary)
      Button("Link to your Mac", action: linkAction)
        .buttonStyle(.borderedProminent)
    }
    .padding(18)
    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.3))
    }
    .accessibilityIdentifier("syntheticWelcomePrompt")
  }
}

private struct InitialLinkOverlay: View {
  let cancelAction: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.28)
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 12) {
          ProgressView()
            .controlSize(.regular)
          VStack(alignment: .leading, spacing: 3) {
            Text("Linking this Mac")
              .font(.halSection.bold())
            Text("HAL is building a read-only application atlas.")
              .foregroundStyle(.secondary)
          }
        }

        HStack(spacing: 8) {
          setupStage("Connect", complete: true)
          Image(systemName: "chevron.right")
          setupStage("Observe applications", active: true)
          Image(systemName: "chevron.right")
          setupStage("Build your atlas")
          Image(systemName: "chevron.right")
          setupStage("Ready")
        }
        .font(.halSmall)

        Text(
          "HAL is reading application bundles, signing facts, conventional related locations, current processes, and startup declarations. It will not modify applications or machine data."
        )
        .font(.halSecondary)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

        HStack {
          Spacer()
          Button("Cancel and keep exploring the fictional Mac", action: cancelAction)
        }
      }
      .padding(24)
      .frame(maxWidth: 620)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
      .shadow(radius: 24, y: 10)
      .padding(30)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("initialLinkOverlay")
  }

  private func setupStage(
    _ title: String,
    complete: Bool = false,
    active: Bool = false
  ) -> some View {
    Label(
      title,
      systemImage: complete ? "checkmark.circle.fill" : (active ? "circle.fill" : "circle")
    )
    .foregroundStyle(complete ? .green : (active ? Color.accentColor : .secondary))
  }
}

private struct LiveCoverageNotice: View {
  let model: AppModel
  let exportAction: () -> Void
  @State private var moreInfoPresented = false

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "checkmark.shield")
        .font(.halSection)
        .foregroundStyle(.green)
      VStack(alignment: .leading, spacing: 5) {
        Text("This Mac is linked")
          .font(.halRowTitle)
        Text(
          "HAL found your installed software and built a read-only map. Start exploring, or check the observation details."
        )
        .foregroundStyle(.secondary)
        if model.collectionActivity == .refresh {
          ProgressView("Checking the same read-only sources again…")
            .controlSize(.small)
        } else {
          Button("Explore installed applications") {
            model.exploreLinkedApplications()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          HStack(spacing: 10) {
            Button("Check this Mac again") { model.refreshLiveData() }
              .buttonStyle(.bordered)
              .controlSize(.small)
            Button("Export redacted diagnostics…") {
              exportAction()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button("More Info") { moreInfoPresented = true }
              .buttonStyle(.bordered)
              .controlSize(.small)
            Button("Dismiss") { model.dismissLinkedCompletion() }
              .buttonStyle(.plain)
              .controlSize(.small)
          }
        }
      }
      Spacer()
    }
    .padding(16)
    .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.25))
    }
    .popover(isPresented: $moreInfoPresented) {
      CollectionHealthPanel(model: model, exportAction: exportAction)
    }
  }

  private var groupedIssues: [GroupedCollectionIssue] {
    Dictionary(
      grouping: model.scanContext.collectorRuns.flatMap(\.issues).filter {
        $0.severity != .information
      },
      by: \.summary
    )
    .map { summary, issues in
      GroupedCollectionIssue(
        summary: summary,
        severity: issues.contains { $0.severity == .error } ? .error : .warning,
        count: issues.count
      )
    }
    .sorted { $0.summary < $1.summary }
  }

  private struct GroupedCollectionIssue {
    let summary: String
    let severity: CollectionIssue.Severity
    let count: Int

    var displayText: String {
      if summary == "A persistence property list did not declare a launchd label.", count > 1 {
        return "\(count) startup property lists did not declare launchd labels."
      }
      return summary + (count > 1 ? " (\(count) occurrences)" : "")
    }
  }

  private func refreshSummary(
    result: AppModel.RefreshResult,
    completedAt: Date
  ) -> String {
    let changeSummary = result == .changed ? "Updates found." : "No displayed changes."
    let duration =
      model.lastRefreshDuration.map { String(format: "%.1f seconds", $0) } ?? "duration unavailable"
    let checkedAt = completedAt.formatted(date: .omitted, time: .shortened)
    return "Checked \(checkedAt) · \(changeSummary) · \(duration)"
  }
}

private struct CollectionHealthPanel: View {
  let model: AppModel
  let exportAction: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Collection Health")
          .font(.halSection.bold())
        Text("HAL only read configured sources. It did not change applications or machine data.")
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
        ForEach(Array(model.scanContext.collectorRuns.enumerated()), id: \.offset) { _, run in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(run.collectorID.rawValue)
                .font(.halRowTitle)
              Spacer()
              Text(run.state.rawValue.capitalized)
                .foregroundStyle(run.state == .complete ? Color.secondary : Color.orange)
            }
            Text(impact(for: run))
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
            if !run.issues.isEmpty {
              DisclosureGroup(
                "\(run.issues.count) issue\(run.issues.count == 1 ? "" : "s") logged for future updates"
              ) {
                ForEach(Array(run.issues.enumerated()), id: \.offset) { _, issue in
                  Text(issue.summary)
                    .textSelection(.enabled)
                }
              }
            }
          }
          Divider()
        }
        HStack {
          Button("Check This Mac Again") { model.refreshLiveData() }
          Button("Export Redacted Diagnostics…") { exportAction() }
        }
        .buttonStyle(.bordered)
      }
      .padding(20)
    }
    .frame(width: 520, height: 520)
  }

  private func impact(for run: CollectorRun) -> String {
    if run.state == .complete && run.availability == .available {
      return "This source was observed normally."
    }
    if run.availability == .permissionDenied {
      return "macOS access limits this source; granting access may improve coverage."
    }
    if run.issues.allSatisfy({ $0.severity == .information }) {
      return "HAL logged a parser or coverage detail; no Mac repair is required."
    }
    return "Some observations from this source may be missing. Existing results remain usable."
  }
}

enum AppButtonKind {
  case standard
  case inline
  case inlineCTA
  case cta
}

struct AppButtonStyle: ButtonStyle {
  let kind: AppButtonKind

  init(_ kind: AppButtonKind = .standard) {
    self.kind = kind
  }

  func makeBody(configuration: Configuration) -> some View {
    AppButtonStyleBody(
      configuration: configuration,
      kind: kind
    )
  }

  private struct AppButtonStyleBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: AppButtonKind
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
      configuration.label
        .font(.halSecondary.weight(kind == .cta ? .semibold : .medium))
        .underline(kind == .inline || kind == .inlineCTA)
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, isInline ? 0 : 13)
        .padding(.vertical, isInline ? 3 : 7)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
          RoundedRectangle(cornerRadius: 7)
            .stroke(borderColor, lineWidth: isInline ? 0 : 1)
        }
        .opacity(isEnabled ? 1 : 0.45)
        .scaleEffect(configuration.isPressed && !isInline ? 0.98 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        .onHover { hovering in
          isHovering = hovering
          if isEnabled && hovering {
            NSCursor.pointingHand.set()
          } else {
            NSCursor.arrow.set()
          }
        }
    }

    private var foregroundColor: Color {
      switch kind {
      case .standard:
        isHovering ? .primary : .primary.opacity(0.9)
      case .inline:
        isHovering ? Color.primary.opacity(0.7) : .primary
      case .inlineCTA:
        isHovering ? Color.accentColor.opacity(0.72) : .accentColor
      case .cta:
        .white
      }
    }

    private var backgroundColor: Color {
      switch kind {
      case .standard:
        Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 1 : 0.72)
      case .inline, .inlineCTA:
        .clear
      case .cta:
        Color.accentColor.opacity(
          configuration.isPressed ? 0.72 : (isHovering ? 0.86 : 1)
        )
      }
    }

    private var borderColor: Color {
      switch kind {
      case .standard:
        Color.secondary.opacity(isHovering ? 0.42 : 0.25)
      case .inline, .inlineCTA:
        .clear
      case .cta:
        Color.accentColor.opacity(0.9)
      }
    }

    private var isInline: Bool {
      kind == .inline || kind == .inlineCTA
    }
  }
}

private struct InventoryRow: View {
  let symbol: String
  let tint: Color
  let title: String
  var subtitle: String? = nil
  let trailing: String
  var applicationPath: String? = nil
  var compact = false
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        if let applicationPath {
          Image(nsImage: NSWorkspace.shared.icon(forFile: applicationPath))
            .resizable()
            .scaledToFit()
            .frame(width: compact ? 25 : 32, height: compact ? 25 : 32)
        } else {
          Image(systemName: symbol)
            .font(.halSubsection)
            .foregroundStyle(tint)
            .frame(width: compact ? 25 : 32, height: compact ? 25 : 32)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.halRowTitle)
          if let subtitle {
            Text(subtitle)
              .font(.halSecondary)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.leading)
          }
        }
        Spacer()
        Text(trailing)
          .font(.halSecondary.weight(.medium))
          .foregroundStyle(.secondary)
        Image(systemName: "chevron.right")
          .font(.halSmall.bold())
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, compact ? 6 : 11)
      .frame(maxWidth: .infinity)
      .background(
        isHovering
          ? Color.accentColor.opacity(compact ? 0.14 : 0.11)
          : (compact ? Color.secondary.opacity(0.025) : Color.clear)
      )
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(Color.secondary.opacity(isHovering ? 0.3 : 0.16))
          .frame(height: 1)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.horizontal, -16)
    .onHover { isHovering = $0 }
  }
}

struct ReferenceItem: Identifiable {
  let id: String
  let title: String
  let detail: String
  let explanation: String
  let question: String
  let examples: String
  let symbol: String
  let tint: Color
}

enum ReferenceCatalog {
  static let items = [
    ReferenceItem(
      id: "mac", title: "Mac and storage", detail: "The machine, volumes, and accounts",
      explanation:
        "The physical and logical places where software and its data live. This context keeps a file or process tied to the Mac and storage volume that actually contains it.",
      question: "Where does this exist?", examples: "Mac · internal volume · external volume",
      symbol: "desktopcomputer", tint: .teal),
    ReferenceItem(
      id: "source", title: "Installation and identity",
      detail: "Where it came from and who made it",
      explanation:
        "Provenance distinguishes a web download from an App Store or package-manager install, and identity records evidence such as signing and package receipts.",
      question: "How did it get here, and can I identify it?",
      examples: "Web · App Store · Homebrew · npm · developer signature",
      symbol: "tray.and.arrow.down", tint: EntityVisualStyle.color(for: .packageManager)),
    ReferenceItem(
      id: "software", title: "Software", detail: "Things installed for a purpose",
      explanation:
        "The recognizable thing you chose to install, plus supporting packages or services. HAL uses this as the main point of entry instead of making you begin with low-level files.",
      question: "What did I install?", examples: "Application · service · package · framework",
      symbol: EntityVisualStyle.symbol(for: .application),
      tint: EntityVisualStyle.color(for: .application)),
    ReferenceItem(
      id: "runtime", title: "Runtime", detail: "What is actively running",
      explanation:
        "Runtime entities represent active work happening now or during an observed period. Installed software can exist without running, and one application may create many processes.",
      question: "What is running?", examples: "Process · helper · VM · container",
      symbol: "gearshape.2", tint: EntityVisualStyle.color(for: .process)),
    ReferenceItem(
      id: "persistence", title: "Persistence", detail: "What can bring software back",
      explanation:
        "Persistence is separate from runtime. It records mechanisms that can launch software after login, restart it after reboot, or keep a helper available even when the main application is closed.",
      question: "Why can this start or return automatically?",
      examples: "Login item · LaunchAgent · LaunchDaemon · background helper · extension",
      symbol: "power", tint: EntityVisualStyle.color(for: .persistence)),
    ReferenceItem(
      id: "data", title: "Data", detail: "What software creates or uses",
      explanation:
        "HAL separates valuable user work and configuration from disposable caches and logs. Ownership can be shared or uncertain, and uncertainty remains visible.",
      question: "What does it leave behind, and is any of it reclaimable?",
      examples: "Documents · settings · cache · logs · shared data",
      symbol: "folder", tint: EntityVisualStyle.color(for: .file)),
    ReferenceItem(
      id: "resources", title: "Resources", detail: "Capacity used while work happens",
      explanation:
        "Resource observations describe changing system capacity. They are measurements over time, not permanent properties of an application.",
      question: "What impact is it having right now or over time?",
      examples: "CPU · memory · storage · network",
      symbol: "gauge", tint: EntityVisualStyle.color(for: .resource)),
    ReferenceItem(
      id: "history", title: "Events and incidents", detail: "What changed and when",
      explanation:
        "Events form the timeline. Incidents mark a period where something became unhealthy or surprising. Their proximity to another event is evidence to investigate, not automatic proof of cause.",
      question: "What happened, and when did it become a problem?",
      examples: "Launch · update · file growth · memory-pressure incident",
      symbol: "clock.arrow.circlepath", tint: EntityVisualStyle.color(for: .event)),
    ReferenceItem(
      id: "evidence", title: "Relationships and evidence",
      detail: "How HAL connects facts, with confidence",
      explanation:
        "HAL links entities using observed facts and labeled inferences. Every inferred relationship should expose its supporting evidence and confidence so ambiguity remains visible.",
      question: "How do we know these things belong together?",
      examples: "Owns · launches · reads and writes · observed · inferred · confidence",
      symbol: "point.3.connected.trianglepath.dotted", tint: .blue),
    ReferenceItem(
      id: "findings", title: "Findings and alerts", detail: "Evidence HAL brings to attention",
      explanation:
        "HAL turns related observations into reviewable findings. A finding states its evidence and confidence; it does not silently convert correlation into certainty.",
      question: "What deserves my attention?", examples: "Performance alert · reclaim opportunity",
      symbol: "exclamationmark.triangle", tint: .orange),
    ReferenceItem(
      id: "decisions", title: "Decisions and safe actions",
      detail: "What you choose to do next",
      explanation:
        "The final layer is human control: inspect, keep, dismiss, or explicitly approve a safe action. Phase 0 demonstrates this model with synthetic data and performs no cleanup.",
      question: "What can I safely decide or do?", examples: "Review · keep · dismiss · reclaim",
      symbol: "checkmark.shield", tint: .red),
  ]

  static func item(forEntityType type: EntityType) -> ReferenceItem? {
    items.first { $0.id == EntityVisualStyle.referenceID(for: type) }
  }
}

struct ReferenceConceptPanel: View {
  let item: ReferenceItem
  let onClose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        HStack(spacing: 9) {
          Image(systemName: item.symbol)
            .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
          Text(item.title).font(.halTitle.bold())
        }
        .foregroundStyle(item.tint)
        Spacer()
        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill")
            .font(.halSection)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Close concept details")
      }
      Text(item.question).font(.halSubsection.bold())
      Text(item.explanation)
        .font(.halBody)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      VStack(alignment: .leading, spacing: 5) {
        Text("Examples")
          .font(.halSmall.weight(.semibold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Text(item.examples).font(.halSecondary)
      }
    }
    .padding(26)
    .frame(maxWidth: 560, alignment: .leading)
    .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20).stroke(item.tint.opacity(0.8), lineWidth: 2)
    }
    .shadow(color: .black.opacity(0.35), radius: 28, y: 14)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("referenceConceptDetail")
  }
}

private struct SystemReferenceView: View {
  let onClose: () -> Void
  @State private var selectedID: String?

  private let items = ReferenceCatalog.items

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 26) {
        HStack(alignment: .top, spacing: 20) {
          VStack(alignment: .leading, spacing: 8) {
            Text("How HAL fits together")
              .font(.halDisplay.bold())
            Text(
              "The complete user-facing model, from what exists on a Mac to an informed decision. Select any section for context. Collector and implementation internals are intentionally omitted."
            )
            .font(.halSubsection)
            .foregroundStyle(.secondary)
          }
          Spacer()
          Button {
            onClose()
          } label: {
            Label("Close", systemImage: "xmark")
          }
          .keyboardShortcut(.cancelAction)
          .accessibilityIdentifier("closeMapReference")
        }

        VStack(alignment: .leading, spacing: 18) {
          VStack(alignment: .leading, spacing: 16) {
            Label("What HAL observes on this Mac", systemImage: "desktopcomputer")
              .font(.halRowTitle)

            HStack(spacing: 12) {
              referenceCard("mac")
              referenceCard("source")
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
              Text("Inside the machine: one software example")
                .font(.halRowTitle)
              Text(
                "The single Software card below is one installed item. Every connected line represents one specific relationship."
              )
              .font(.halSmall)
              .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 0) {
              softwareHubCard()
                .frame(width: 245)

              VStack(spacing: 0) {
                relationshipPath(
                  verb: "launches",
                  targetID: "runtime",
                  followOnVerb: "consumes",
                  followOnTargetID: "resources"
                )
                persistenceRuntimeConnector()
                relationshipPath(
                  verb: "registers startup",
                  targetID: "persistence"
                )
                Spacer().frame(height: 12)
                relationshipPath(
                  verb: "reads and writes",
                  targetID: "data",
                  targetAtFarRight: true
                )
              }
            }

            HStack(spacing: 10) {
              Text("Changes to any component above are recorded as")
                .font(.halSecondary)
                .foregroundStyle(.secondary)
              connectedArrow("")
              referenceCard("history")
                .frame(width: 310)
            }
          }
          .padding(16)
          .background(
            Color(nsColor: .windowBackgroundColor).opacity(0.6),
            in: RoundedRectangle(cornerRadius: 18)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 18)
              .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
          }

          VStack(alignment: .leading, spacing: 12) {
            Text("How HAL turns observations into guidance")
              .font(.halRowTitle)
            Text(
              "This is HAL’s review workflow, not another set of components inside the computer."
            )
            .font(.halSmall)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
              workflowStep(1, itemID: "evidence")
              Image(systemName: "chevron.right").foregroundStyle(.tertiary)
              workflowStep(2, itemID: "findings")
              Image(systemName: "chevron.right").foregroundStyle(.tertiary)
              workflowStep(3, itemID: "decisions")
            }
          }
          .padding(16)
          .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
          .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(Color.secondary.opacity(0.16))
          }
        }
        .padding(22)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selectedID)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))

        VStack(alignment: .leading, spacing: 12) {
          Text("Important distinctions")
            .font(.halSection.bold())
          distinction(
            "User data is not cache",
            "A large project or browser profile may belong to an application without being safe to remove."
          )
          distinction(
            "Installed is not running",
            "An application bundle can exist without any active process or performance impact.")
          distinction(
            "Nearby is not necessarily causal",
            "An event can overlap a slowdown without proving that it caused the slowdown.")
          distinction(
            "Uncertain ownership stays protected",
            "HAL should expose ambiguous or shared data instead of making a confident-looking guess."
          )
        }
      }
      .padding(28)
      .frame(maxWidth: 1_160, alignment: .leading)
    }
    .frame(minWidth: 900, minHeight: 680)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    .clipShape(RoundedRectangle(cornerRadius: 24))
    .shadow(color: .black.opacity(0.28), radius: 30, y: 12)
    .overlay {
      if let selectedItem {
        ZStack {
          Button {
            closeConcept()
          } label: {
            Color.black.opacity(0.16)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Close concept details")

          ReferenceConceptPanel(item: selectedItem, onClose: closeConcept)
            .padding(36)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
      }
    }
  }

  private var selectedItem: ReferenceItem? {
    items.first { $0.id == selectedID }
  }

  private func closeConcept() {
    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
      selectedID = nil
    }
  }

  private func referenceRow(_ itemIDs: [String]) -> some View {
    HStack(spacing: 12) {
      ForEach(itemIDs, id: \.self) { itemID in
        if let item = items.first(where: { $0.id == itemID }) {
          Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
              selectedID = item.id
            }
          } label: {
            VStack(alignment: .leading, spacing: 7) {
              Label(item.title, systemImage: item.symbol)
                .font(.halRowTitle)
                .foregroundStyle(item.tint)
              Text(item.detail)
                .font(.halSecondary)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .padding(14)
            .background(
              item.tint.opacity(selectedID == item.id ? 0.18 : 0.1),
              in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
              RoundedRectangle(cornerRadius: 14)
                .stroke(
                  item.tint.opacity(selectedID == item.id ? 0.9 : 0.3),
                  lineWidth: selectedID == item.id ? 2 : 1)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(item.title). \(item.detail)")
          .accessibilityHint("Shows more context")
        }
      }
    }
  }

  private func referenceCard(_ itemID: String) -> some View {
    Group {
      if let item = items.first(where: { $0.id == itemID }) {
        Button {
          withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            selectedID = item.id
          }
        } label: {
          HStack(spacing: 10) {
            Image(systemName: item.symbol)
              .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
              .foregroundStyle(item.tint)
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title).font(.halRowTitle)
              Text(item.detail)
                .font(.halSmall)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
          }
          .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
          .padding(12)
          .background(item.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
          .overlay {
            RoundedRectangle(cornerRadius: 13).stroke(item.tint.opacity(0.42))
          }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows more context")
      }
    }
  }

  private func relationshipLane(from sourceID: String, verb: String, to targetID: String)
    -> some View
  {
    HStack(spacing: 10) {
      referenceCard(sourceID)
      horizontalArrow(verb)
        .frame(width: 150)
      referenceCard(targetID)
    }
  }

  private func connectedArrow(_ label: String) -> some View {
    HStack(spacing: 0) {
      Rectangle()
        .fill(Color.secondary.opacity(0.45))
        .frame(height: 1)
      if !label.isEmpty {
        Text(label)
          .font(.halSmall.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.78)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(.regularMaterial, in: Capsule())
      }
      Rectangle()
        .fill(Color.secondary.opacity(0.45))
        .frame(height: 1)
      Image(systemName: "arrowtriangle.right.fill")
        .font(.halSmall)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label.isEmpty ? "connects to" : label)
  }

  private func softwareHubCard() -> some View {
    Group {
      if let item = items.first(where: { $0.id == "software" }) {
        Button {
          withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            selectedID = item.id
          }
        } label: {
          VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
              Image(systemName: item.symbol)
                .font(.system(size: EntityVisualStyle.nodeIconSize, weight: .semibold))
              Text(item.title).font(.halRowTitle)
            }
            .foregroundStyle(item.tint)
            Text(item.detail)
              .font(.halSmall)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .padding(12)
          .background(item.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
          .overlay {
            RoundedRectangle(cornerRadius: 13).stroke(item.tint.opacity(0.42))
          }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows more context")
      }
    }
  }

  private func relationshipPath(
    verb: String,
    targetID: String,
    followOnVerb: String? = nil,
    followOnTargetID: String? = nil,
    targetAtFarRight: Bool = false
  ) -> some View {
    HStack(spacing: 0) {
      if let followOnVerb, let followOnTargetID {
        connectedArrow(verb)
          .frame(width: 150)
        referenceCard(targetID)
          .frame(width: 210)
        connectedArrow(followOnVerb)
          .frame(width: 150)
        referenceCard(followOnTargetID)
          .frame(width: 210)
      } else if targetAtFarRight {
        connectedArrow(verb)
          .frame(maxWidth: .infinity)
        referenceCard(targetID)
          .frame(width: 210)
      } else {
        connectedArrow(verb)
          .frame(width: 150)
        referenceCard(targetID)
          .frame(width: 210)
        Spacer(minLength: 360)
      }
    }
  }

  private func persistenceRuntimeConnector() -> some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: 150)
      VStack(spacing: 1) {
        Image(systemName: "arrowtriangle.up.fill")
          .font(.halSmall)
        Rectangle().frame(width: 1)
        Text("can start later")
          .font(.halSmall.weight(.medium))
          .lineLimit(1)
      }
      .foregroundStyle(.secondary)
      .frame(width: 210, height: 44)
      Spacer()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Persistence can start Runtime later")
  }

  private func workflowStep(_ number: Int, itemID: String) -> some View {
    Group {
      if let item = items.first(where: { $0.id == itemID }) {
        Button {
          withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            selectedID = item.id
          }
        } label: {
          HStack(spacing: 10) {
            Text("\(number)")
              .font(.halSmall.bold())
              .foregroundStyle(.secondary)
              .frame(width: 24, height: 24)
              .background(Color.secondary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title).font(.halSecondary.bold())
              Text(item.detail)
                .font(.halSmall)
                .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
          .padding(10)
          .background(
            Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18))
          }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows more context")
      }
    }
  }

  private func horizontalArrow(_ label: String) -> some View {
    VStack(spacing: 2) {
      Text(label.isEmpty ? " " : label)
        .font(.halSmall.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Image(systemName: "arrow.right")
        .foregroundStyle(.secondary)
    }
    .fixedSize()
  }

  private func flowArrow(_ label: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(.halSmall)
        .foregroundStyle(.secondary)
      Image(systemName: "arrow.down")
        .foregroundStyle(.secondary)
    }
  }

  private func flowBranch(_ label: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(.halSmall)
        .foregroundStyle(.secondary)
      Image(systemName: "arrow.down")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private func distinction(_ title: String, _ explanation: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.halRowTitle)
      Text(explanation)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }

}

struct AtlasDetailView: View {
  let model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      contextSummary
      GeometryReader { proxy in
        if proxy.size.width >= 1_050 {
          HSplitView {
            map
              .frame(minWidth: 620)
            inspector
              .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
          }
        } else {
          VSplitView {
            map
              .frame(minHeight: 430)
            inspector
              .frame(minHeight: 210, idealHeight: 260, maxHeight: 340)
          }
        }
      }
    }
  }

  private var map: some View {
    RelationshipCanvas(
      graph: model.presentedGraph,
      layout: model.layout,
      visibleTypes: Set(EntityType.allCases),
      selection: Binding(
        get: { model.selection },
        set: { model.selection = $0 }
      ),
      focusedEntity: Binding(
        get: { model.focusedEntity },
        set: { model.focusedEntity = $0 }
      ),
      configuration: model.configuration.layout
    )
  }

  private var inspector: some View {
    InspectorView(
      graph: model.presentedGraph,
      selection: model.selection,
      onShowEntityTypeInfo: { model.entityTypeReferencePresented = $0 }
    )
  }

  private var contextSummary: some View {
    HStack(alignment: .center, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text(summaryTitle)
          .font(.halSection.bold())
        Text(summaryText)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button {
        model.referencePresented = true
      } label: {
        Label("How this map works", systemImage: "questionmark.circle")
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("mapReferenceButton")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .background(Color(nsColor: .controlBackgroundColor))
  }

  private var summaryTitle: String {
    switch model.destination {
    case .storage: "What could be safely removed?"
    case .applications: "What software is installed?"
    case .startup: "What starts automatically?"
    case .commandLine: "How is the command-line environment assembled?"
    case .shellPath: "How does the shell build PATH?"
    case .filesystem: "Where does observed software live?"
    case .performance:
      model.isSynthetic ? "What changed during the memory spike?" : "What is running now?"
    case .entity(let id): model.fixture.entity(id)?.name ?? "Selected item"
    case .overview: "This Mac"
    }
  }

  private var summaryText: String {
    return switch model.destination {
    case .storage:
      if model.isSynthetic {
        "24.4 GB is likely rebuildable or redownloadable. Profiles, configuration, and application data remain protected."
      } else {
        "HAL observed configured rebuildable or redownloadable roots using metadata only. Sizes were not collected, and no removal action is enabled."
      }
    case .applications:
      if model.isSynthetic {
        "Explore familiar applications alongside Homebrew, Oh My Zsh, and an npm-installed TypeScript package."
      } else {
        "HAL observed \(model.applicationScopeCounts.total) application bundles in the configured read-only search roots."
      }
    case .startup:
      "Startup declarations are shown separately from running processes. A declaration means software may start automatically; it does not prove the software is running now."
    case .commandLine:
      "Package managers, packages, shell frameworks, and observed processes are connected by retained ownership and runtime evidence."
    case .shellPath:
      "Analyze explicitly pasted shell configuration as a deterministic sequence. Variables HAL cannot resolve remain visible instead of being guessed."
    case .filesystem:
      "A curated hierarchy of explanatory locations and observed paths; HAL has not indexed the whole disk."
    case .performance:
      if model.isSynthetic {
        "A Docker build, VS Code indexing, and restored Brave tabs overlapped; HAL does not claim timing alone proves causation."
      } else {
        "HAL retained a bounded point-in-time process sample. It has not collected performance history or inferred a past incident."
      }
    case .entity(let id):
      model.fixture.entity(id)?.summary ?? "Select a connected item to understand its role."
    case .overview:
      "Choose a system to explore."
    }
  }
}

private struct SearchField: View {
  @Binding var query: String
  let results: [Entity]
  let onSelect: (Entity) -> Void
  @State private var presented = false

  var body: some View {
    TextField("Find an app, file, or event", text: $query)
      .textFieldStyle(.plain)
      .padding(.horizontal, 10)
      .frame(width: 250, height: 28)
      .background(Color(nsColor: .controlBackgroundColor))
      .overlay {
        Rectangle()
          .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
      }
      .onSubmit {
        presented = !query.isEmpty
      }
      .onChange(of: query) { _, value in
        if value.isEmpty {
          presented = false
        }
      }
      .popover(isPresented: $presented, arrowEdge: .bottom) {
        Group {
          if results.isEmpty {
            ContentUnavailableView.search(text: query)
          } else {
            List(results) { entity in
              Button {
                onSelect(entity)
                presented = false
              } label: {
                VStack(alignment: .leading) {
                  Text(entity.name)
                  Text(entity.summary)
                    .font(.halSmall)
                    .foregroundStyle(.secondary)
                }
              }
              .buttonStyle(.plain)
            }
          }
        }
        .frame(width: 400, height: min(320, CGFloat(max(results.count, 1) * 62)))
      }
  }
}
