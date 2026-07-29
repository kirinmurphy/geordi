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
          let rebuildableDataConfiguration = try RebuildableDataConfiguration.bundled()
          let processConfiguration = try ProcessCollectorConfiguration.bundled()
          let persistenceConfiguration = try PersistenceCollectorConfiguration.bundled()
          let homebrewConfiguration = try HomebrewInstallationConfiguration.bundled()
          let runtimeConfiguration = try RuntimeCollectorConfiguration.bundled()
          let packageEcosystemConfiguration = try PackageEcosystemConfiguration.bundled()
          let commandLineSoftwareConfiguration =
            try CommandLineSoftwareConfiguration.bundled()
          let shellFrameworkConfiguration = try ShellFrameworkConfiguration.bundled()
          return try ApplicationInventorySnapshotProvider(
            scanID: ScanID("live-\(UUID().uuidString)"),
            configuration: collectorConfiguration,
            provenanceConfiguration: provenanceConfiguration,
            associatedLocationConfiguration: associatedLocationConfiguration,
            rebuildableDataConfiguration: rebuildableDataConfiguration,
            processConfiguration: processConfiguration,
            persistenceConfiguration: persistenceConfiguration,
            homebrewConfiguration: homebrewConfiguration,
            runtimeConfiguration: runtimeConfiguration,
            packageEcosystemConfiguration: packageEcosystemConfiguration,
            commandLineSoftwareConfiguration: commandLineSoftwareConfiguration,
            shellFrameworkConfiguration: shellFrameworkConfiguration
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
  struct ApplicationScopeCounts: Equatable {
    let visible: Int
    let hidden: Int
    let uncertain: Int
    let total: Int
  }

  enum CollectionActivity: Equatable {
    case initialLink
    case refresh
  }

  enum RefreshResult: Equatable {
    case changed
    case unchanged
  }

  enum Destination: Hashable {
    case overview
    case storage
    case applications
    case startup
    case commandLine
    case shellPath
    case filesystem
    case performance
    case entity(EntityID)
  }

  let configuration: AppConfiguration
  let applicationClassifications: ApplicationClassificationConfiguration?
  private let syntheticProvider: any GraphSnapshotProvider
  private let preferences: any DataSourcePreferenceStore
  private let userDataStore: HALUserDataStore?
  private let liveSnapshot: @Sendable () throws -> GraphSnapshot
  private let displayPolicy: DisplayPolicy?
  private var collectionTask: Task<Void, Never>?
  private var collectionGeneration: UUID?
  var fixture: SystemGraph
  var scanContext: ScanContext
  var dataSourceMode: DataSourceMode
  var isCollecting = false
  var collectionActivity: CollectionActivity?
  var collectionError: String?
  var linkCompletionPending = false
  var linkedCompletionDismissed: Bool
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
    selectedApplicationCategoryID = nil
    self.syntheticProvider = syntheticProvider
    self.preferences = preferences
    self.userDataStore = userDataStore
    self.liveSnapshot = liveSnapshot
    displayPolicy = try? DisplayPolicy.bundled()
    let initialMode = preferences.mode()
    if initialMode == .linkedMac {
      selectedApplicationCategoryID = applicationClassifications?.defaultCategoryID
    }
    dataSourceMode = initialMode
    welcomeDismissed = preferences.syntheticWelcomeDismissed()
    linkedCompletionDismissed = preferences.linkedCompletionDismissed()
    let snapshot =
      initialMode == .linkedMac
      ? ((try? userDataStore?.loadSnapshot()) ?? nil) ?? Self.emptyLinkedSnapshot()
      : syntheticProvider.snapshot()
    fixture = snapshot.graph
    scanContext = snapshot.scan
  }

  var isSynthetic: Bool { dataSourceMode == .synthetic }

  var currentSnapshot: GraphSnapshot {
    GraphSnapshot(graph: fixture, scan: scanContext)
  }

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
        return applicationClassifications.category(
          forApplicationPath: path,
          platformBinary: platformBinaryEvidence(for: application),
          details: application.details
        ).id
      }
    )
    return applicationClassifications.categories.filter {
      $0.kind == .scope
        && (observedCategoryIDs.contains($0.id) || $0.id == selectedApplicationCategoryID)
    }
  }

  func applications(in categoryID: String?) -> [Entity] {
    let applications = fixture.entities.filter { $0.type == .application }
    guard !isSynthetic, let applicationClassifications else {
      return applications
    }
    return applications.filter { application in
      guard let path = application.details.first(where: { $0.label == "Path" })?.value else {
        return false
      }
      return categoryID == nil
        || applicationClassifications.category(
          forApplicationPath: path,
          platformBinary: platformBinaryEvidence(for: application),
          details: application.details
        ).id == categoryID
    }
  }

  func applicationSourceLabel(_ application: Entity) -> String? {
    guard
      !isSynthetic,
      let path = application.details.first(where: { $0.label == "Path" })?.value,
      let applicationClassifications
    else { return nil }
    guard
      let source = applicationClassifications.source(
        forApplicationPath: path,
        platformBinary: platformBinaryEvidence(for: application),
        details: application.details
      )
    else { return nil }
    if source.id == "app-store",
      let timing = application.details.first(where: { $0.label == "Installation timing" })?.value
    {
      return timing == "Present at setup"
        ? "Present at setup · App Store managed"
        : "\(timing) · App Store managed"
    }
    return source.label
  }

  var applicationScopeCounts: ApplicationScopeCounts {
    let all = applications(in: nil)
    let visible = applications(in: selectedApplicationCategoryID).count
    guard !isSynthetic, let applicationClassifications else {
      return ApplicationScopeCounts(
        visible: visible,
        hidden: max(0, all.count - visible),
        uncertain: 0,
        total: all.count
      )
    }
    let fallbackIDs = Set(
      applicationClassifications.categories.filter {
        $0.kind == .scope && $0.isFallback
      }.map(\.id)
    )
    let uncertain = all.filter { application in
      guard let path = application.details.first(where: { $0.label == "Path" })?.value else {
        return true
      }
      return fallbackIDs.contains(
        applicationClassifications.category(
          forApplicationPath: path,
          platformBinary: platformBinaryEvidence(for: application),
          details: application.details
        ).id
      )
    }.count
    return ApplicationScopeCounts(
      visible: visible,
      hidden: max(0, all.count - visible - uncertain),
      uncertain: uncertain,
      total: all.count
    )
  }

  func platformBinaryEvidence(for application: Entity) -> Bool? {
    switch application.details.first(where: { $0.label == "Platform binary" })?.value {
    case "Yes": true
    case "No": false
    default: nil
    }
  }

  var collectorCoverageCounts: (complete: Int, limited: Int, total: Int) {
    let runs = scanContext.collectorRuns
    let complete = runs.filter {
      $0.state == .complete && $0.availability == .available
    }.count
    return (complete, runs.count - complete, runs.count)
  }

  var applicationEvidenceFactCount: Int {
    applications(in: nil).reduce(into: 0) { count, application in
      count +=
        application.details.first { $0.label == "Evidence facts" }
        .flatMap { Int($0.value) } ?? 0
    }
  }

  var unresolvedProcessCounts: (unmatched: Int, inaccessible: Int) {
    fixture.entities.reduce(into: (unmatched: 0, inaccessible: 0)) { counts, entity in
      guard
        entity.type == .process,
        let state = entity.details.first(where: {
          $0.label == "Application resolution"
        })?.value
      else {
        return
      }
      switch state {
      case "Unmatched": counts.unmatched += 1
      case "Inaccessible": counts.inaccessible += 1
      default: break
      }
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
        if activity == .initialLink {
          selectedApplicationCategoryID = applicationClassifications?.defaultCategoryID
        }
        preferences.setMode(.linkedMac)
        navigate(to: .overview)
        switch activity {
        case .initialLink:
          linkCompletionPending = true
          linkedCompletionDismissed = false
          preferences.setLinkedCompletionDismissed(false)
        case .refresh:
          lastRefreshResult = snapshot.graph == previousGraph ? .unchanged : .changed
          lastRefreshCompletedAt = Date()
          lastRefreshDuration = Date().timeIntervalSince(collectionStartedAt)
        }
      } catch {
        guard collectionGeneration == generation, !Task.isCancelled else { return }
        collectionError = Self.collectionFailureMessage(error)
        if linkOnSuccess {
          dataSourceMode = .synthetic
          preferences.setMode(.synthetic)
        }
      }
    }
  }

  static func collectionFailureMessage(_ error: Error) -> String {
    let stage =
      switch error {
      case is ApplicationCollectorConfigurationError:
        "set up application discovery"
      case is ApplicationProvenanceConfigurationError:
        "set up provenance collection"
      case is ApplicationAssociatedLocationConfigurationError:
        "set up associated-location collection"
      case is ProcessCollectorConfigurationError:
        "set up process collection"
      case is PersistenceCollectorConfigurationError:
        "set up startup-item collection"
      case is HomebrewCollectorError:
        "set up Homebrew package collection"
      case is RuntimeCollectorError:
        "set up runtime collection"
      case is PackageEcosystemCollectorError:
        "set up package ecosystem collection"
      case is CommandLineSoftwareCollectorError:
        "set up command-line software collection"
      default:
        "complete read-only collection"
      }
    let detail =
      (error as? LocalizedError)?.errorDescription
      ?? String(describing: error)
    return
      "HAL could not \(stage): \(detail) No applications or machine data were changed."
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
    dismissLinkedCompletion()
    navigate(to: .applications)
  }

  func dismissLinkedCompletion() {
    linkCompletionPending = false
    linkedCompletionDismissed = true
    preferences.setLinkedCompletionDismissed(true)
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
    case .overview, .filesystem, .shellPath:
      return fixture.filtered(to: [.application, .resource, .incident])
    case .storage:
      return isSynthetic
        ? fixture.neighborhood(around: "resource.storage", depth: 2)
        : fixture.filtered(to: [.file, .packageManager])
    case .applications:
      return fixture.filtered(to: [
        .application, .packageManager, .shellFramework, .package, .persistence,
      ])
    case .startup:
      return fixture.filtered(to: [.application, .persistence, .process])
    case .commandLine:
      return fixture.filtered(to: [.packageManager, .shellFramework, .package, .process])
    case .performance:
      return isSynthetic
        ? fixture.neighborhood(around: "incident.build", depth: 2)
        : fixture.filtered(to: [.process])
    case .entity(let id):
      let entity = fixture.entity(id)
      // A package manager is itself the center of an ownership map. Keep that
      // view to its direct installations and managed artifacts so second-hop
      // neighbors do not obscure the complete package inventory.
      let neighborhood = fixture.neighborhood(
        around: id,
        depth: entity?.type == .packageManager ? 1 : 2
      )
      guard !isSynthetic else {
        return neighborhood
      }
      let contextID = entity?.type == .application ? "applicationDetail" : "entityDetail"
      guard let policy = displayPolicy?.context(contextID) else { return neighborhood }
      return DisplayPolicyPresenter().present(
        neighborhood,
        centeredOn: id,
        policy: policy
      )
    }
  }

  var breadcrumb: [String] {
    switch destination {
    case .overview: ["Home"]
    case .storage: ["Home", "Storage"]
    case .applications: ["Home", "Installed software"]
    case .startup: ["Home", "Startup activity"]
    case .commandLine: ["Home", "Command-line environment"]
    case .shellPath: ["Home", "Command-line environment", "PATH Visualizer"]
    case .filesystem: ["Home", "Filesystem Map"]
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
      selection = isSynthetic ? GraphSelection(.entity("resource.storage")) : nil
    case .applications:
      selection = nil
    case .startup, .commandLine, .shellPath:
      selection = nil
    case .filesystem:
      selection = nil
    case .performance:
      selection = isSynthetic ? GraphSelection(.entity("incident.build")) : nil
    case .entity(let id):
      selection = GraphSelection(.entity(id))
    }
    focusedEntity = nil
    searchQuery = ""
  }

  func focus(_ entity: Entity) {
    visibleTypes.insert(entity.type)
    if entity.type == .packageManager {
      let connectedTypes = fixture.relationships(connectedTo: entity.id).compactMap {
        relationship -> EntityType? in
        let counterpartID =
          relationship.source == entity.id ? relationship.target : relationship.source
        return fixture.entity(counterpartID)?.type
      }
      visibleTypes.formUnion(connectedTypes)
    }
    destination = .entity(entity.id)
    selection = GraphSelection(.entity(entity.id))
    focusedEntity = entity.id
  }
}
