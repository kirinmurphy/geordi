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
            OverviewView(model: model)
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
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 5) {
        Text("HAL")
          .font(.largeTitle.bold())
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
                Image(systemName: application.id == "app.photos" ? "photo" : "app")
                  .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                  Text(application.name)
                  Text(application.details.first?.value ?? application.summary)
                    .font(.caption)
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
                    .font(.caption)
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
              .font(.caption.weight(.semibold))
            Text(model.isSynthetic ? "No machine access" : "Read-only application access")
              .font(.caption2)
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
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
          if index == 0, title == "Home", model.destination != .overview {
            Button("Home") {
              model.navigate(to: .overview)
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityHint("Return to the inventory")
          } else {
            Text(title)
              .font(index == model.breadcrumb.count - 1 ? .headline : .subheadline)
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
        Image(systemName: freshnessSymbol(freshness))
          .font(.caption.bold())
        Text(freshnessText(freshness))
          .font(.caption.weight(.semibold))
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
          .font(.caption.bold())
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        if let actionTitle, let action {
          Button(actionTitle, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        if allowsDismissal {
          Button {
            withAnimation(.easeInOut(duration: 0.18)) {
              isVisible = false
            }
          } label: {
            Image(systemName: "xmark")
              .font(.caption.bold())
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 30) {
        if model.isSynthetic, !model.welcomeDismissed {
          WelcomePrompt(
            linkAction: model.linkToMac,
            dismissAction: model.dismissWelcome
          )
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
        } else {
          LiveCoverageNotice(model: model)
        }

        inventorySection(
          title: model.isSynthetic ? "User’s Applications" : "Observed Applications",
          symbol: "square.grid.2x2",
          headerAccessory: {
            if !model.isSynthetic, let configuration = model.applicationClassifications {
              HStack(spacing: 10) {
                let counts = model.applicationScopeCounts
                Text(
                  "\(counts.visible) visible · \(counts.hidden) hidden · \(counts.uncertain) unclassified"
                )
                  .font(.callout)
                  .foregroundStyle(.secondary)
                Picker(
                  "Software type",
                  selection: Binding(
                    get: { model.selectedApplicationCategoryID },
                    set: { model.selectedApplicationCategoryID = $0 }
                  )
                ) {
                  Text(configuration.allApplicationsLabel).tag(String?.none)
                  ForEach(model.applicationCategoryOptions) { category in
                    Text(category.label).tag(Optional(category.id))
                  }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .accessibilityLabel("Software type")
              }
            }
          }
        ) {
          if applications.isEmpty {
            Text("No applications match this software type.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 8)
          } else {
            ForEach(Array(applications.enumerated()), id: \.element.id) { index, application in
              if index > 0 { Divider() }
              InventoryRow(
                symbol: applicationSymbol(application.id),
                tint: applicationTint(application.id),
                title: application.name,
                subtitle: applicationBehavior(application),
                trailing: detail("Synthetic footprint", in: application)
                  ?? detail("Current state", in: application) ?? ""
              ) { model.focus(application) }
            }
          }
        }

        if model.isSynthetic {
          inventorySection(
            title: "Rebuildable Data",
            symbol: "arrow.3.trianglepath",
            headerActionTitle: "Reclaim File Space",
            headerAction: { model.navigate(to: .storage) }
          ) {
            ForEach(Array(reclaimCandidates.enumerated()), id: \.element.id) { index, file in
              if index > 0 { Divider() }
              InventoryRow(
                symbol: "folder",
                tint: .green,
                title: file.name,
                subtitle: file.summary,
                trailing: detail("Synthetic size", in: file) ?? ""
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
  }

  private var applications: [Entity] {
    model.applications(in: model.selectedApplicationCategoryID)
  }

  private var allApplications: [Entity] {
    model.applications(in: nil)
  }

  private var reclaimCandidates: [Entity] {
    let ids = Set(
      model.fixture.relationships.filter { $0.target == "resource.storage" }.map(\.source))
    return model.fixture.entities.filter { ids.contains($0.id) && $0.type == .file }
  }

  private func detail(_ label: String, in entity: Entity) -> String? {
    entity.details.first { $0.label == label }?.value
  }

  private func applicationBehavior(_ application: Entity) -> String {
    switch application.id {
    case "app.docker": "Running · Linux VM and backend active"
    case "app.vscode": "Running · Extension host and TypeScript service active"
    case "app.cmux": "Running · One zsh session represented"
    case "app.chatgpt": "Running · Starts automatically"
    case "app.brave": "Running · Renderer processes active"
    default: application.summary
    }
  }

  private func applicationSymbol(_ id: EntityID) -> String {
    switch id {
    case "app.docker": "shippingbox.fill"
    case "app.vscode": "chevron.left.forwardslash.chevron.right"
    case "app.cmux": "terminal.fill"
    case "app.chatgpt": "bubble.left.and.bubble.right.fill"
    case "app.brave": "globe"
    default: "app"
    }
  }

  private func applicationTint(_ id: EntityID) -> Color {
    switch id {
    case "app.docker": .blue
    case "app.vscode": .cyan
    case "app.cmux": .purple
    case "app.chatgpt": .mint
    case "app.brave": .orange
    default: .accentColor
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
          .font(.title2.bold())
          .foregroundStyle(tint)
        Spacer()
        headerAccessory()
        if let headerActionTitle, let headerAction {
          Button(action: headerAction) {
            Text(headerActionTitle)
          }
          .buttonStyle(AppButtonStyle(.inlineCTA))
          .accessibilityHint("Open reclaimable storage review")
        } else if let subtitle {
          Text(subtitle)
            .font(.callout)
            .foregroundStyle(.secondary)
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
          .font(.title2.bold())
        Spacer()
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
        ForEach(metrics) { metric in
          VStack(alignment: .leading, spacing: 7) {
            Label(metric.title, systemImage: metric.symbol)
              .font(.callout.weight(.semibold))
              .foregroundStyle(metric.tint)
            Text(metric.value)
              .font(.title2.bold())
            Text(metric.context)
              .font(.caption)
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
          .font(.title2.bold())
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
              .font(.title2.bold())
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
        .font(.caption)

        Text(
          "HAL is reading application bundles, signing facts, conventional related locations, current processes, and startup declarations. It will not modify applications or machine data."
        )
        .font(.callout)
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

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "checkmark.shield")
        .font(.title2)
        .foregroundStyle(.green)
      VStack(alignment: .leading, spacing: 5) {
        Text(model.linkCompletionPending ? "Your application atlas is ready" : "This Mac is linked")
          .font(.headline)
        Text(
          "HAL read application bundles, signing and download provenance, conventional related locations, current processes, and startup declarations. It did not change applications or machine data. Storage totals and performance history are not collected yet."
        )
        .foregroundStyle(.secondary)
        let coverage = model.collectorCoverageCounts
        Text(
          "\(coverage.complete) of \(coverage.total) collectors complete"
            + (coverage.limited > 0 ? " · \(coverage.limited) limited" : "")
            + " · \(model.applicationEvidenceFactCount) application evidence facts"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(coverage.limited > 0 ? .orange : .secondary)
        ForEach(
          model.scanContext.collectorRuns.flatMap(\.issues),
          id: \.id
        ) { issue in
          Label(issue.summary, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(issue.severity == .error ? .red : .orange)
        }
        if model.collectionActivity == .refresh {
          ProgressView("Checking the same read-only sources again…")
            .controlSize(.small)
        } else if model.linkCompletionPending {
          Button("Explore installed applications") {
            model.exploreLinkedApplications()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
        } else {
          if let result = model.lastRefreshResult,
            let completedAt = model.lastRefreshCompletedAt
          {
            Text(refreshSummary(result: result, completedAt: completedAt))
              .font(.caption.weight(.medium))
              .foregroundStyle(.secondary)
          }
          HStack(spacing: 10) {
            Button("Check this Mac again") { model.refreshLiveData() }
              .buttonStyle(.bordered)
              .controlSize(.small)
            Text("Reruns the same enabled read-only collectors.")
              .font(.caption)
              .foregroundStyle(.secondary)
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
        .font(.callout.weight(kind == .cta ? .semibold : .medium))
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
  let subtitle: String
  let trailing: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: symbol)
          .font(.title3)
          .foregroundStyle(tint)
          .frame(width: 32, height: 32)
          .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.headline)
          Text(subtitle)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        Text(trailing)
          .font(.callout.weight(.medium))
          .foregroundStyle(.secondary)
        Image(systemName: "chevron.right")
          .font(.caption.bold())
          .foregroundStyle(.tertiary)
      }
      .padding(.vertical, 11)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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
          Text(item.title).font(.title.bold())
        }
        .foregroundStyle(item.tint)
        Spacer()
        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Close concept details")
      }
      Text(item.question).font(.title3.bold())
      Text(item.explanation)
        .font(.body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      VStack(alignment: .leading, spacing: 5) {
        Text("Examples")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Text(item.examples).font(.callout)
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
              .font(.largeTitle.bold())
            Text(
              "The complete user-facing model, from what exists on a Mac to an informed decision. Select any section for context. Collector and implementation internals are intentionally omitted."
            )
            .font(.title3)
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
              .font(.headline)

            HStack(spacing: 12) {
              referenceCard("mac")
              referenceCard("source")
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
              Text("Inside the machine: one software example")
                .font(.headline)
              Text(
                "The single Software card below is one installed item. Every connected line represents one specific relationship."
              )
              .font(.caption)
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
                .font(.callout)
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
              .font(.headline)
            Text(
              "This is HAL’s review workflow, not another set of components inside the computer."
            )
            .font(.caption)
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
            .font(.title2.bold())
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
                .font(.headline)
                .foregroundStyle(item.tint)
              Text(item.detail)
                .font(.callout)
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
              Text(item.title).font(.headline)
              Text(item.detail)
                .font(.caption)
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
          .font(.caption.weight(.medium))
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
        .font(.system(size: 8))
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
              Text(item.title).font(.headline)
            }
            .foregroundStyle(item.tint)
            Text(item.detail)
              .font(.caption)
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
          .font(.system(size: 8))
        Rectangle().frame(width: 1)
        Text("can start later")
          .font(.caption2.weight(.medium))
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
              .font(.caption.bold())
              .foregroundStyle(.secondary)
              .frame(width: 24, height: 24)
              .background(Color.secondary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
              Text(item.title).font(.callout.bold())
              Text(item.detail)
                .font(.caption)
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
        .font(.caption.weight(.medium))
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
        .font(.caption)
        .foregroundStyle(.secondary)
      Image(systemName: "arrow.down")
        .foregroundStyle(.secondary)
    }
  }

  private func flowBranch(_ label: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Image(systemName: "arrow.down")
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  private func distinction(_ title: String, _ explanation: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.headline)
      Text(explanation)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
  }

}

private struct AtlasDetailView: View {
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
          .font(.title2.bold())
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
    case .performance: "What changed during the memory spike?"
    case .entity(let id): model.fixture.entity(id)?.name ?? "Selected item"
    case .overview: "This Mac"
    }
  }

  private var summaryText: String {
    switch model.destination {
    case .storage:
      "24.4 GB is likely rebuildable or redownloadable. Profiles, configuration, and application data remain protected."
    case .applications:
      "Explore familiar applications alongside Homebrew, Oh My Zsh, and an npm-installed TypeScript package."
    case .performance:
      "A Docker build, VS Code indexing, and restored Brave tabs overlapped; HAL does not claim timing alone proves causation."
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
                    .font(.caption)
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
