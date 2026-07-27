import AppKit
import HALCollectors
import HALDataSource
import HALDomain
import HALFixtures
import HALVisualization
import SwiftUI

@main
struct HALApp: App {
  @NSApplicationDelegateAdaptor(HALApplicationDelegate.self) private var applicationDelegate

  var body: some Scene {
    WindowGroup {
      ContentView(
        configuration: .phaseZero,
        syntheticProvider: SyntheticGraphProvider(
          fixtureID: AppConfiguration.phaseZero.initialFixtureID
        ),
        preferences: UserDefaultsDataSourcePreferenceStore(),
        userDataStore: try? HALUserDataStore.applicationSupport(),
        liveSnapshot: {
          let collectorConfiguration = try ApplicationCollectorConfiguration.bundled()
          let provenanceConfiguration = try ApplicationProvenanceConfiguration.bundled()
          return try ApplicationInventorySnapshotProvider(
            scanID: ScanID("live-\(UUID().uuidString)"),
            configuration: collectorConfiguration,
            provenanceConfiguration: provenanceConfiguration
          ).snapshot()
        }
      )
      .frame(minWidth: 1_080, minHeight: 680)
    }
    .windowStyle(.hiddenTitleBar)
    .commands {
      SidebarCommands()
      InspectorCommands()
    }
  }
}

final class HALApplicationDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.activate(ignoringOtherApps: true)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

@MainActor
@Observable
final class AppModel {
  enum Destination: Hashable {
    case overview
    case storage
    case applications
    case performance
    case entity(EntityID)
  }

  let configuration: AppConfiguration
  private let syntheticProvider: any GraphSnapshotProvider
  private let preferences: any DataSourcePreferenceStore
  private let userDataStore: HALUserDataStore?
  private let liveSnapshot: @Sendable () throws -> GraphSnapshot
  var fixture: SystemGraph
  var scanContext: ScanContext
  var dataSourceMode: DataSourceMode
  var isCollecting = false
  var collectionError: String?
  var welcomeDismissed: Bool
  var destination: Destination = .overview
  var selection: GraphSelection?
  var focusedEntity: EntityID?
  var searchQuery = ""
  var visibleTypes = Set(EntityType.allCases)
  var inspectorPresented = true
  var referencePresented = false
  var entityTypeReferencePresented: EntityType?

  init(
    configuration: AppConfiguration,
    syntheticProvider: any GraphSnapshotProvider,
    preferences: any DataSourcePreferenceStore,
    userDataStore: HALUserDataStore?,
    liveSnapshot: @escaping @Sendable () throws -> GraphSnapshot
  ) {
    self.configuration = configuration
    self.syntheticProvider = syntheticProvider
    self.preferences = preferences
    self.userDataStore = userDataStore
    self.liveSnapshot = liveSnapshot
    let initialMode = preferences.mode()
    dataSourceMode = initialMode
    welcomeDismissed = preferences.syntheticWelcomeDismissed()
    let snapshot =
      initialMode == .linkedMac
      ? ((try? userDataStore?.loadSnapshot()) ?? nil) ?? Self.emptyLinkedSnapshot()
      : syntheticProvider.snapshot()
    fixture = snapshot.graph
    scanContext = snapshot.scan
  }

  var isSynthetic: Bool { dataSourceMode == .synthetic }

  private static func emptyLinkedSnapshot() -> GraphSnapshot {
    let startedAt = Date()
    return GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(
          id: "live-applications-pending",
          name: "This Mac",
          summary: "Waiting for the first read-only application inventory."
        ),
        entities: [],
        relationships: []
      ),
      scan: ScanContext(
        id: "live-pending",
        environment: .liveReadOnly,
        startedAt: startedAt
      )
    )
  }

  func resumeLinkedMacIfNeeded() {
    guard dataSourceMode == .linkedMac else { return }
    refreshLiveData()
  }

  func linkToMac() {
    guard dataSourceMode == .synthetic else { return }
    refreshLiveData(linkOnSuccess: true)
  }

  func refreshLiveData(linkOnSuccess: Bool = false) {
    guard !isCollecting else { return }
    isCollecting = true
    collectionError = nil
    let collect = liveSnapshot
    Task {
      do {
        let snapshot = try await Task.detached { try collect() }.value
        try userDataStore?.saveSnapshot(snapshot)
        fixture = snapshot.graph
        scanContext = snapshot.scan
        dataSourceMode = .linkedMac
        preferences.setMode(.linkedMac)
        navigate(to: .overview)
      } catch {
        collectionError = "HAL could not read this Mac: \(error.localizedDescription)"
        if linkOnSuccess {
          dataSourceMode = .synthetic
          preferences.setMode(.synthetic)
        }
      }
      isCollecting = false
    }
  }

  func dismissWelcome() {
    welcomeDismissed = true
    preferences.setSyntheticWelcomeDismissed(true)
  }

  func unlinkMac(backupURL: URL? = nil) throws {
    if let backupURL {
      guard let userDataStore else {
        throw HALUserDataStoreError.noCompiledData
      }
      try userDataStore.exportBackup(to: backupURL)
    }
    try userDataStore?.reset()
    preferences.setMode(.synthetic)
    preferences.setSyntheticWelcomeDismissed(false)
    dataSourceMode = .synthetic
    welcomeDismissed = false
    collectionError = nil
    let snapshot = syntheticProvider.snapshot()
    fixture = snapshot.graph
    scanContext = snapshot.scan
    navigate(to: .overview)
  }

  var layout: LayoutResult {
    SemanticLayout(configuration: configuration.layout).layout(presentedGraph)
  }

  var searchResults: [Entity] {
    GraphNavigator(graph: fixture).search(searchQuery, visibleTypes: visibleTypes)
  }

  var presentedGraph: SystemGraph {
    switch destination {
    case .overview:
      fixture.filtered(to: [.application, .resource, .incident])
    case .storage:
      fixture.neighborhood(around: "resource.storage", depth: 2)
    case .applications:
      fixture.filtered(to: [
        .application, .packageManager, .shellFramework, .package, .persistence,
      ])
    case .performance:
      fixture.neighborhood(around: "incident.build", depth: 2)
    case .entity(let id):
      fixture.neighborhood(around: id, depth: 2)
    }
  }

  var breadcrumb: [String] {
    switch destination {
    case .overview: ["Home"]
    case .storage: ["Home", "Storage"]
    case .applications: ["Home", "Installed software"]
    case .performance: ["Home", "Performance"]
    case .entity(let id):
      ["Home", fixture.entity(id)?.name ?? "Item"]
    }
  }

  func dataFreshness(at currentDate: Date = Date()) -> FreshnessState {
    if scanContext.environment == .synthetic {
      return .fresh
    }
    return FreshnessPolicy(agingAfter: 2 * 60, staleAfter: 15 * 60)
      .state(for: scanContext, at: currentDate)
  }

  func navigate(to destination: Destination) {
    self.destination = destination
    switch destination {
    case .overview:
      selection = nil
    case .storage:
      selection = GraphSelection(.entity("resource.storage"))
    case .applications:
      selection = nil
    case .performance:
      selection = GraphSelection(.entity("incident.build"))
    case .entity(let id):
      selection = GraphSelection(.entity(id))
    }
    focusedEntity = nil
    searchQuery = ""
  }

  func focus(_ entity: Entity) {
    if !visibleTypes.contains(entity.type) {
      visibleTypes.insert(entity.type)
    }
    destination = .entity(entity.id)
    selection = GraphSelection(.entity(entity.id))
    focusedEntity = entity.id
  }
}
