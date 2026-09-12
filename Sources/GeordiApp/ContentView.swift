import AppKit
import GeordiCollectors
import GeordiDataSource
import GeordiDomain
import GeordiVisualization
import SwiftUI

struct ContentView: View {
  @State private var model: AppModel
  @State private var unlinkConfirmationPresented = false
  @State private var unlinkError: String?
  @State private var diagnosticExportError: String?
  @State private var linkedStatusExpanded = false
  @State private var freshnessHoverTask: Task<Void, Never>?

  init(
    configuration: AppConfiguration,
    applicationClassifications: ApplicationClassificationConfiguration?,
    syntheticProvider: any GraphSnapshotProvider,
    preferences: any DataSourcePreferenceStore,
    userDataStore: UserDataStore?,
    liveSnapshot: @escaping @Sendable () async throws -> GraphSnapshot
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
      GeometryReader { viewport in
        NavigationSplitView {
          sidebar
        } detail: {
          detailColumn
            .frame(
              minWidth: 0,
              maxWidth: .infinity,
              minHeight: 0,
              maxHeight: .infinity
            )
            .clipped()
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: viewport.size.width, height: viewport.size.height)
      }
      .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
      .layoutPriority(1)

      dataFreshnessFooter
        .fixedSize(horizontal: false, vertical: true)
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
        "\(AppBrand.displayName) will disconnect live collection and return to the fictional profile. A backup contains the last compiled application inventory."
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

  @ViewBuilder private var detailColumn: some View {
    VStack(spacing: 0) {
      notificationSlot
        .fixedSize(horizontal: false, vertical: true)
      if model.destination != .overview {
        header
          .fixedSize(horizontal: false, vertical: true)
      }
      Group {
        switch model.destination {
        case .overview:
          OverviewView(model: model, diagnosticExportAction: exportRedactedDiagnostics)
        case .filesystem:
          FilesystemMapView(model: model)
        case .shellPath:
          ShellPathVisualizerView()
        case .applications:
          ApplicationBrowserView(model: model)
        case .startup, .storage, .commandLine:
          ExplorationBrowserView(model: model)
        case .entity(let id):
          if let entity = model.fixture.entity(id), entity.type == .application {
            ApplicationStoryView(model: model, application: entity)
          } else {
            AtlasDetailView(model: model)
          }
        case .performance:
          AtlasDetailView(model: model)
        }
      }
      .frame(
        minWidth: 0,
        maxWidth: .infinity,
        minHeight: 0,
        maxHeight: .infinity
      )
      .layoutPriority(1)
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 5) {
        Text(AppBrand.displayName)
          .font(.display.bold())
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
            "Installed software", symbol: "macwindow.on.rectangle", destination: .applications)
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
        Section("Tools") {
          navigationButton("Shell PATH Lab", symbol: "terminal", destination: .shellPath)
        }
      }

      Divider()
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: model.isSynthetic ? "desktopcomputer" : "link")
            .foregroundStyle(.secondary)
          VStack(alignment: .leading, spacing: 2) {
            Text(model.isSynthetic ? "Fictional profile" : "Linked to this Mac")
              .font(.small.weight(.semibold))
            Text(model.isSynthetic ? "No machine access" : "Read-only application access")
              .font(.small)
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
    .accessibilityIdentifier("globalSidebar")
  }

  private var header: some View {
    HStack(spacing: 12) {
      Button {
        model.navigateBack()
      } label: {
        Label("Back", systemImage: "chevron.left")
      }
      .buttonStyle(.borderless)
      .disabled(!model.canNavigateBack)
      .keyboardShortcut("[", modifiers: .command)

      Button {
        model.navigateHome()
      } label: {
        Label("Home", systemImage: "house")
      }
      .buttonStyle(.borderless)

      Divider().frame(height: 22)

      HStack(spacing: 6) {
        ForEach(Array(model.breadcrumb.enumerated()), id: \.offset) { index, title in
          if index > 0 {
            Image(systemName: "chevron.right")
              .font(.small)
              .foregroundStyle(.tertiary)
          }
          if index == 0, title == "Home", model.destination != .overview {
            Text("Home")
              .font(.secondary.weight(.medium))
              .foregroundStyle(.secondary)
          } else {
            Text(title)
              .font(index == model.breadcrumb.count - 1 ? .rowTitle : .secondary)
              .foregroundStyle(index == model.breadcrumb.count - 1 ? .primary : .secondary)
          }
        }
      }
      Spacer()
    }
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity, minHeight: 54)
    .background(.bar)
    .overlay(alignment: .bottom) {
      Divider()
    }
    .zIndex(1)
    .accessibilityIdentifier("globalNavigationBar")
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
                .font(.small)
            }
          }
        }
        .buttonStyle(.plain)
        .onHover(perform: scheduleFreshnessStatusPresentation)
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
          : "Freshness reflects when \(AppBrand.displayName) collected this snapshot and whether collection was complete."
      )
      .accessibilityElement(children: .combine)
      .accessibilityLabel(freshnessText(freshness))
      .accessibilityHint(
        "Click or pause the pointer to show collection status and refresh actions."
      )
      .accessibilityIdentifier("dataFreshnessFooter")
      .onDisappear {
        freshnessHoverTask?.cancel()
        freshnessHoverTask = nil
      }
    }
  }

  private func scheduleFreshnessStatusPresentation(_ hovering: Bool) {
    freshnessHoverTask?.cancel()
    freshnessHoverTask = nil
    guard hovering, !linkedStatusExpanded else { return }
    freshnessHoverTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(700))
      guard !Task.isCancelled else { return }
      linkedStatusExpanded = true
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
            "Everything shown is deterministic synthetic data. \(AppBrand.displayName) is not scanning this Mac.",
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
    panel.nameFieldStringValue = "\(AppBrand.displayName)-live-data-backup.json"
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
    panel.nameFieldStringValue = "\(AppBrand.displayName)-redacted-diagnostic.json"
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
          .font(.small.bold())
        Text(message)
          .font(.small)
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
              .font(.small.bold())
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
  @State private var hoveredSoftwareGroupID: String?
  @State private var applicationFilterPresented = false

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
            title: "Command-Line Inventory",
            subtitle:
              "Executable commands organized by their observed installation location",
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
    if !model.isSynthetic {
      return model.fixture.entities.filter {
        $0.type == .file && $0.detail(.rebuildability) != nil
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
          .font(.section.bold())
        Spacer()
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
        ForEach(metrics) { metric in
          VStack(alignment: .leading, spacing: 7) {
            Label(metric.title, systemImage: metric.symbol)
              .font(.secondary.weight(.semibold))
              .foregroundStyle(metric.tint)
            Text(metric.value)
              .font(.section.bold())
            Text(metric.context)
              .font(.small)
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
        Label("Welcome to \(AppBrand.displayName)", systemImage: "sparkles")
          .font(.section.bold())
        Spacer()
        Button(action: dismissAction) {
          Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss welcome")
      }
      Text(
        "\(AppBrand.displayName) explains the software and activity on a Mac while keeping observations, evidence, and uncertainty visible."
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
              .font(.section.bold())
            Text("\(AppBrand.displayName) is building a read-only application atlas.")
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
        .font(.small)

        Text(
          "\(AppBrand.displayName) is reading application bundles, signing facts, conventional related locations, current processes, and startup declarations. It will not modify applications or machine data."
        )
        .font(.secondary)
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
        .font(.section)
        .foregroundStyle(.green)
      VStack(alignment: .leading, spacing: 5) {
        Text("This Mac is linked")
          .font(.rowTitle)
        Text(
          "\(AppBrand.displayName) found your installed software and built a read-only map. Start exploring, or check the observation details."
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
    let freshness = model.dataFreshness()
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Collection Health")
          .font(.section.bold())
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: statusSymbol(freshness))
            .foregroundStyle(statusColor(freshness))
          VStack(alignment: .leading, spacing: 3) {
            Text(statusTitle(freshness))
              .font(.rowTitle)
            Text(statusExplanation(freshness))
              .font(.secondary)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusColor(freshness).opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
          RoundedRectangle(cornerRadius: 10)
            .stroke(statusColor(freshness).opacity(0.28))
        }
        Text(
          "\(AppBrand.displayName) only read configured sources. It did not change applications or machine data."
        )
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
        ForEach(Array(model.scanContext.collectorRuns.enumerated()), id: \.offset) { _, run in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(run.collectorID.rawValue)
                .font(.rowTitle)
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
          if model.isSynthetic {
            Button(model.isCollecting ? "Linking…" : "Link to This Mac") {
              model.linkToMac()
            }
            .disabled(model.isCollecting)
          } else {
            Button(model.isCollecting ? "Checking…" : "Check This Mac Again") {
              model.refreshLiveData()
            }
            .disabled(model.isCollecting)
          }
          Button("Export Redacted Diagnostics…") { exportAction() }
        }
        .buttonStyle(.bordered)
      }
      .padding(20)
    }
    .frame(width: 520, height: 520)
  }

  private func statusTitle(_ freshness: FreshnessState) -> String {
    if model.isSynthetic { return "Deterministic fixture is current" }
    return switch freshness {
    case .fresh: "Observation is current"
    case .aging: "Observation is getting older"
    case .stale: "Observation is stale"
    case .partial: "Observation is partial"
    case .unavailable: "Data is unavailable"
    case .permissionDenied: "Permission limits this observation"
    case .neverCollected: "This Mac has not been observed"
    }
  }

  private func statusExplanation(_ freshness: FreshnessState) -> String {
    if model.isSynthetic {
      return
        "This reproducible example does not read this Mac. Link explicitly to collect current read-only observations."
    }
    let timestamp =
      model.scanContext.completedAt.map {
        " Last completed \($0.formatted(date: .abbreviated, time: .shortened))."
      } ?? ""
    let explanation =
      switch freshness {
      case .fresh:
        "\(AppBrand.displayName) completed a recent read-only check."
      case .aging:
        "The retained snapshot may no longer reflect recent changes. You can check again now."
      case .stale:
        "The retained snapshot is old enough that \(AppBrand.displayName) recommends checking again."
      case .partial:
        "One or more configured sources did not complete normally. Existing observations remain usable."
      case .unavailable:
        "Configured sources were unavailable during the last check."
      case .permissionDenied:
        "macOS denied access to at least one configured source. Checking again can retry after permissions change."
      case .neverCollected:
        "Run a read-only check to create the first observation."
      }
    return explanation + timestamp
  }

  private func statusSymbol(_ freshness: FreshnessState) -> String {
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

  private func statusColor(_ freshness: FreshnessState) -> Color {
    switch freshness {
    case .fresh: .green
    case .aging, .partial, .permissionDenied: .orange
    case .stale: .red
    case .unavailable, .neverCollected: .secondary
    }
  }

  private func impact(for run: CollectorRun) -> String {
    if run.state == .complete && run.availability == .available {
      return "This source was observed normally."
    }
    if run.availability == .permissionDenied {
      return "macOS access limits this source; granting access may improve coverage."
    }
    if run.issues.allSatisfy({ $0.severity == .information }) {
      return
        "\(AppBrand.displayName) logged a parser or coverage detail; no Mac repair is required."
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
        .font(.secondary.weight(kind == .cta ? .semibold : .medium))
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

private struct ApplicationFilterOption: View {
  let label: String
  let isSelected: Bool
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack {
        Text(label)
          .font(.secondary.weight(isSelected ? .bold : .regular))
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .font(.small.bold())
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .background(
        !isSelected && isHovering ? Color.accentColor.opacity(0.13) : .clear,
        in: RoundedRectangle(cornerRadius: 7)
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovering = hovering
      if !isSelected && hovering {
        NSCursor.pointingHand.set()
      } else {
        NSCursor.arrow.set()
      }
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
            .frame(
              width: compact ? IconSize.base : IconSize.large,
              height: compact ? IconSize.base : IconSize.large
            )
        } else {
          Image(systemName: symbol)
            .font(.system(size: IconSize.base, weight: .semibold))
            .foregroundStyle(tint)
            .frame(
              width: compact ? IconSize.base : IconSize.large,
              height: compact ? IconSize.base : IconSize.large
            )
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.rowTitle)
          if let subtitle {
            Text(subtitle)
              .font(.secondary)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.leading)
          }
        }
        Spacer()
        Text(trailing)
          .font(.secondary.weight(.medium))
          .foregroundStyle(.secondary)
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .bold))
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
  static let configuration: ReferenceCatalogConfiguration = {
    do {
      return try ReferenceCatalogConfiguration.bundled()
    } catch {
      preconditionFailure("Required reference catalog failed validation: \(error)")
    }
  }()

  static let items = configuration.items.map {
    ReferenceItem(
      id: $0.id,
      title: $0.title,
      detail: $0.detail,
      explanation: $0.explanation,
      question: $0.question,
      examples: $0.examples,
      symbol: $0.symbol,
      tint: color(for: $0.tint)
    )
  }

  static func item(forEntityType type: EntityType) -> ReferenceItem? {
    guard let definition = configuration.item(for: type) else { return nil }
    return items.first { $0.id == definition.id }
  }

  private static func color(for tint: EntityPresentationTint) -> Color {
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
          Text(item.title).font(.heading.bold())
        }
        .foregroundStyle(item.tint)
        Spacer()
        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill")
            .font(.section)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Close concept details")
      }
      Text(item.question).font(.subsection.bold())
      Text(item.explanation)
        .font(.paragraph)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      VStack(alignment: .leading, spacing: 5) {
        Text("Examples")
          .font(.small.weight(.semibold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Text(item.examples).font(.secondary)
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
            Text("How \(AppBrand.displayName) fits together")
              .font(.display.bold())
            Text(
              "The complete user-facing model, from what exists on a Mac to an informed decision. Select any section for context. Collector and implementation internals are intentionally omitted."
            )
            .font(.subsection)
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
            Label(
              "What \(AppBrand.displayName) observes on this Mac", systemImage: "desktopcomputer"
            )
            .font(.rowTitle)

            HStack(spacing: 12) {
              referenceCard("mac")
              referenceCard("source")
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
              Text("Inside the machine: one software example")
                .font(.rowTitle)
              Text(
                "The single Software card below is one installed item. Every connected line represents one specific relationship."
              )
              .font(.small)
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
                .font(.secondary)
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
            Text("How \(AppBrand.displayName) turns observations into guidance")
              .font(.rowTitle)
            Text(
              "This is \(AppBrand.displayName)’s review workflow, not another set of components inside the computer."
            )
            .font(.small)
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
            .font(.section.bold())
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
            "\(AppBrand.displayName) should expose ambiguous or shared data instead of making a confident-looking guess."
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
                .font(.rowTitle)
                .foregroundStyle(item.tint)
              Text(item.detail)
                .font(.secondary)
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
              Text(item.title).font(.rowTitle)
              Text(item.detail)
                .font(.small)
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
          .font(.small.weight(.medium))
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
        .font(.small)
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
              Text(item.title).font(.rowTitle)
            }
            .foregroundStyle(item.tint)
            Text(item.detail)
              .font(.small)
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
          .font(.small)
        Rectangle().frame(width: 1)
        Text("can start later")
          .font(.small.weight(.medium))
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
              .font(.small.bold())
              .foregroundStyle(.secondary)
              .frame(width: 24, height: 24)
              .background(Color.secondary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title).font(.secondary.bold())
              Text(item.detail)
                .font(.small)
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
        .font(.small.weight(.medium))
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
        .font(.small)
        .foregroundStyle(.secondary)
      Image(systemName: "arrow.down")
        .foregroundStyle(.secondary)
    }
  }

  private func flowBranch(_ label: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(.small)
        .foregroundStyle(.secondary)
      Image(systemName: "arrow.down")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private func distinction(_ title: String, _ explanation: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.rowTitle)
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
      configuration: model.configuration.layout,
      centerEntityID: centerEntityID,
      onRecenterEntity: model.focus
    )
  }

  private var centerEntityID: EntityID? {
    guard case .entity(let id) = model.destination else { return nil }
    return id
  }

  private var inspector: some View {
    InspectorView(
      graph: model.presentedGraph,
      sourceGraph: model.fixture,
      selection: model.selection,
      onShowEntityTypeInfo: { model.entityTypeReferencePresented = $0 },
      onOpenEntity: model.focus,
      canGoBack: model.canGoBackInGraphHistory,
      canGoForward: model.canGoForwardInGraphHistory,
      onGoBack: model.goBackInGraphHistory,
      onGoForward: model.goForwardInGraphHistory
    )
  }

  private var contextSummary: some View {
    HStack(alignment: .center, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text(summaryTitle)
          .font(.section.bold())
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
        "\(AppBrand.displayName) observed configured rebuildable or redownloadable roots using metadata only. Sizes were not collected, and no removal action is enabled."
      }
    case .applications:
      if model.isSynthetic {
        "Explore familiar applications alongside Homebrew, Oh My Zsh, and an npm-installed TypeScript package."
      } else {
        "\(AppBrand.displayName) observed \(model.applicationScopeCounts.total) application bundles in the configured read-only search roots."
      }
    case .startup:
      "Startup declarations are shown separately from running processes. A declaration means software may start automatically; it does not prove the software is running now."
    case .commandLine:
      "Package managers, packages, shell frameworks, and observed processes are connected by retained ownership and runtime evidence."
    case .shellPath:
      "Analyze explicitly pasted shell configuration as a deterministic sequence. Variables \(AppBrand.displayName) cannot resolve remain visible instead of being guessed."
    case .filesystem:
      "A curated hierarchy of explanatory locations and observed paths; \(AppBrand.displayName) has not indexed the whole disk."
    case .performance:
      if model.isSynthetic {
        "A Docker build, VS Code indexing, and restored Brave tabs overlapped; \(AppBrand.displayName) does not claim timing alone proves causation."
      } else {
        "\(AppBrand.displayName) retained a bounded point-in-time process sample. It has not collected performance history or inferred a past incident."
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
                  if let distinguishingDetail = entity.details.first?.value {
                    Text(distinguishingDetail)
                      .font(.small)
                      .foregroundStyle(.secondary)
                  } else if entity.type != .application {
                    Text(entity.summary)
                      .font(.small)
                      .foregroundStyle(.secondary)
                  }
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
