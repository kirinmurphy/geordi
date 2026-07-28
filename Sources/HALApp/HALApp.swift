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
        applicationClassifications: try? ApplicationClassificationConfiguration.bundled(),
        syntheticProvider: SyntheticGraphProvider(
          fixtureID: AppConfiguration.phaseZero.initialFixtureID
        ),
        preferences: UserDefaultsDataSourcePreferenceStore(),
        userDataStore: try? HALUserDataStore.applicationSupport(),
        liveSnapshot: {
          let collectorConfiguration = try ApplicationCollectorConfiguration.bundled()
          let provenanceConfiguration = try ApplicationProvenanceConfiguration.bundled()
          let associatedLocationConfiguration =
            try ApplicationAssociatedLocationConfiguration.bundled()
          let processConfiguration = try ProcessCollectorConfiguration.bundled()
          let persistenceConfiguration = try PersistenceCollectorConfiguration.bundled()
          return try ApplicationInventorySnapshotProvider(
            scanID: ScanID("live-\(UUID().uuidString)"),
            configuration: collectorConfiguration,
            provenanceConfiguration: provenanceConfiguration,
            associatedLocationConfiguration: associatedLocationConfiguration,
            processConfiguration: processConfiguration,
            persistenceConfiguration: persistenceConfiguration
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
  enum CollectionActivity {
    case initialLink
    case refresh
  }

  enum RefreshResult {
    case changed
    case unchanged
  }

  enum Destination: Hashable {
    case overview
    case storage
    case applications
    case performance
    case entity(EntityID)
  }

  let configuration: AppConfiguration
  let applicationClassifications: ApplicationClassificationConfiguration?
  private let syntheticProvider: any GraphSnapshotProvider
  private let preferences: any DataSourcePreferenceStore
  private let userDataStore: HALUserDataStore?
  private let liveSnapshot: @Sendable () throws -> GraphSnapshot
  private var collectionTask: Task<Void, Never>?
  private var collectionGeneration: UUID?
  var fixture: SystemGraph
  var scanContext: ScanContext
  var dataSourceMode: DataSourceMode
  var isCollecting = false
  var collectionActivity: CollectionActivity?
  var collectionError: String?
  var linkCompletionPending = false
  var lastRefreshResult: RefreshResult?
  var lastRefreshCompletedAt: Date?
  var lastRefreshDuration: TimeInterval?
  var welcomeDismissed: Bool
  var destination: Destination = .overview
  var selection: GraphSelection?
  var focusedEntity: EntityID?
  var searchQuery = ""
  var visibleTypes = Set(EntityType.allCases)
  var inspectorPresented = true
  var referencePresented = false
  var entityTypeReferencePresented: EntityType?
  var selectedApplicationCategoryID: String?

  init(
    configuration: AppConfiguration,
    applicationClassifications: ApplicationClassificationConfiguration?,
    syntheticProvider: any GraphSnapshotProvider,
    preferences: any DataSourcePreferenceStore,
    userDataStore: HALUserDataStore?,
    liveSnapshot: @escaping @Sendable () throws -> GraphSnapshot
  ) {
    self.configuration = configuration
    self.applicationClassifications = applicationClassifications
    selectedApplicationCategoryID = applicationClassifications?.defaultCategoryID
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

  var applicationCategoryOptions: [ApplicationClassificationCategory] {
    guard let applicationClassifications else { return [] }
    let observedCategoryIDs = Set(
      fixture.entities.compactMap { application -> String? in
        guard
          application.type == .application,
          let path = application.details.first(where: { $0.label == "Path" })?.value
        else {
          return nil
        }
        return applicationClassifications.category(forApplicationPath: path).id
      }
    )
    return applicationClassifications.categories.filter {
      observedCategoryIDs.contains($0.id) || $0.id == selectedApplicationCategoryID
    }
  }

  func applications(in categoryID: String?) -> [Entity] {
    let applications = fixture.entities.filter { $0.type == .application }
    guard !isSynthetic, let categoryID, let applicationClassifications else {
      return applications
    }
    return applications.filter { application in
      guard let path = application.details.first(where: { $0.label == "Path" })?.value else {
        return false
      }
      return applicationClassifications.category(forApplicationPath: path).id == categoryID
    }
  }

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
    let activity: CollectionActivity = linkOnSuccess ? .initialLink : .refresh
    let collectionStartedAt = Date()
    let previousGraph = fixture
    let generation = UUID()
    isCollecting = true
    collectionActivity = activity
    collectionGeneration = generation
    collectionError = nil
    let collect = liveSnapshot
    collectionTask = Task {
      defer {
        if collectionGeneration == generation {
          isCollecting = false
          collectionActivity = nil
          collectionTask = nil
          collectionGeneration = nil
        }
      }
      do {
        let snapshot = try await Task.detached { try collect() }.value
        guard collectionGeneration == generation, !Task.isCancelled else { return }
        try userDataStore?.saveSnapshot(snapshot)
        fixture = snapshot.graph
        scanContext = snapshot.scan
        dataSourceMode = .linkedMac
        preferences.setMode(.linkedMac)
        navigate(to: .overview)
        switch activity {
        case .initialLink:
          linkCompletionPending = true
        case .refresh:
          lastRefreshResult = snapshot.graph == previousGraph ? .unchanged : .changed
          lastRefreshCompletedAt = Date()
          lastRefreshDuration = Date().timeIntervalSince(collectionStartedAt)
        }
      } catch {
        guard collectionGeneration == generation, !Task.isCancelled else { return }
        collectionError = "HAL could not read this Mac: \(error.localizedDescription)"
        if linkOnSuccess {
          dataSourceMode = .synthetic
          preferences.setMode(.synthetic)
        }
      }
    }
  }

  func cancelInitialLink() {
    guard collectionActivity == .initialLink else { return }
    collectionGeneration = nil
    collectionTask?.cancel()
    collectionTask = nil
    isCollecting = false
    collectionActivity = nil
    collectionError = nil
  }

  func exploreLinkedApplications() {
    linkCompletionPending = false
    navigate(to: .applications)
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
    linkCompletionPending = false
    lastRefreshResult = nil
    lastRefreshCompletedAt = nil
    lastRefreshDuration = nil
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
