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
        case .startup, .storage, .commandLine:
          ExplorationBrowserView(model: model)
        case .dupeReview:
          DupeReviewView(model: model)
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
        HStack(alignment: .top, spacing: 5) {
          Text(AppBrand.displayName)
            .font(.custom("Courier New", size: 20).weight(.medium))
          Text("BETA")
            .font(.custom("Courier New", size: 13).weight(.semibold))
            .tracking(1)
            .foregroundStyle(.secondary)
            .baselineOffset(5)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 12)

      Divider()

      List {
        Section {
          navigationButton("Home", symbol: "laptopcomputer", destination: .overview)
        }
        // Mirrors the Home question cards one-to-one — same destinations,
        // same order, same symbols — so the sidebar and the Home page are
        // two views of one navigation contract.
        Section("Explore") {
          navigationButton(
            "What starts automatically", symbol: "power", destination: .startup)
          navigationButton(
            "Reclaimable data", symbol: "arrow.3.trianglepath", destination: .storage)
          navigationButton(
            "Command-line tools", symbol: "terminal", destination: .commandLine)
          navigationButton(
            "Where software lives", symbol: "folder.badge.gearshape", destination: .filesystem)
          navigationButton(
            "Shell PATH Lab", symbol: "point.3.connected.trianglepath.dotted",
            destination: .shellPath)
          if model.isSynthetic {
            navigationButton(
              "Performance", symbol: "gauge.with.dots.needle.50percent",
              destination: .performance)
          }
        }
        Section("Tools") {
          navigationButton("Duplicate review", symbol: "square.on.square", destination: .dupeReview)
        }
      }
      // The navigation column reads as a slightly lighter inset beneath
      // the title, separated by the divider above.
      .scrollContentBackground(.hidden)
      .background(Color(nsColor: .controlBackgroundColor))

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
          // Data-source actions live behind one menu; the sidebar footer
          // stays a status line, not a control panel.
          Menu {
            Button("Check again") { model.refreshLiveData() }
            Divider()
            Button("Return to fictional Mac…") {
              unlinkConfirmationPresented = true
            }
          } label: {
            Image(systemName: "ellipsis.circle")
              .foregroundStyle(.secondary)
          }
          .menuStyle(.borderlessButton)
          .menuIndicator(.visible)
          .fixedSize()
          .disabled(model.isCollecting)
          .help("Data source actions")
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
          .hoverHighlight()
      }
      .buttonStyle(.plain)
      .disabled(!model.canNavigateBack)
      .keyboardShortcut("[", modifiers: .command)

      Divider().frame(height: 22)

      HStack(spacing: 6) {
        ForEach(Array(model.breadcrumb.enumerated()), id: \.offset) { index, title in
          if index > 0 {
            Image(systemName: "chevron.right")
              .font(.small)
              .foregroundStyle(.tertiary)
          }
          if index == 0, title == "Home", model.destination != .overview {
            Button {
              model.navigateHome()
            } label: {
              Text("Home")
                .font(.secondary.weight(.medium))
                .foregroundStyle(.primary)
                .hoverHighlight()
            }
            .buttonStyle(.plain)
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
        .hoverHighlight()
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
        .hoverHighlight(hPadding: 8, vPadding: 4)
    }
    .buttonStyle(.plain)
  }
}
