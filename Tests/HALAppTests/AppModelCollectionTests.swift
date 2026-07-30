import Foundation
import HALCollectors
import HALDataSource
import HALDomain
import Testing

@testable import HALApp

@Suite("Application collection state")
@MainActor
struct AppModelCollectionTests {
  @Test("Initial link succeeds and hands off to application exploration")
  func initialLinkSuccess() async throws {
    let preferences = MemoryPreferences()
    let live = snapshot(id: "live", entityName: "Collected")
    let model = makeModel(preferences: preferences) { live }

    model.linkToMac()
    #expect(model.isCollecting)
    #expect(model.collectionActivity == .initialLink)
    try await waitUntil { !model.isCollecting }

    #expect(model.dataSourceMode == .linkedMac)
    #expect(model.fixture == live.graph)
    #expect(model.linkCompletionPending)
    #expect(preferences.mode() == .linkedMac)

    model.exploreLinkedApplications()
    #expect(!model.linkCompletionPending)
    #expect(model.destination == .applications)
  }

  @Test("Cancelling initial link ignores a late result and stays synthetic")
  func initialLinkCancellation() async throws {
    let preferences = MemoryPreferences()
    let gate = CollectionGate(result: .success(snapshot(id: "late", entityName: "Late")))
    let model = makeModel(preferences: preferences) { try gate.collect() }
    let original = model.fixture

    model.linkToMac()
    try await waitUntil { gate.hasStarted }
    model.cancelInitialLink()
    gate.release()
    try await Task.sleep(for: .milliseconds(30))

    #expect(!model.isCollecting)
    #expect(model.collectionActivity == nil)
    #expect(model.dataSourceMode == .synthetic)
    #expect(model.fixture == original)
    #expect(preferences.mode() == .synthetic)
  }

  @Test("Unchanged and changed refresh results are distinguished")
  func refreshResults() async throws {
    let original = snapshot(id: "cached", entityName: "Original")
    let changed = snapshot(id: "changed", entityName: "Changed")
    let preferences = MemoryPreferences(mode: .linkedMac)
    let store = try temporaryStore(containing: original)
    defer { try? FileManager.default.removeItem(at: store.root.deletingLastPathComponent()) }
    let sequence = SnapshotSequence([original, changed])
    let model = makeModel(preferences: preferences, store: store) { try sequence.next() }

    model.refreshLiveData()
    try await waitUntil { !model.isCollecting }
    #expect(model.lastRefreshResult == .unchanged)
    #expect(model.lastRefreshCompletedAt != nil)
    #expect(model.lastRefreshDuration != nil)

    model.refreshLiveData()
    try await waitUntil { !model.isCollecting }
    #expect(model.lastRefreshResult == .changed)
    #expect(model.fixture == changed.graph)
  }

  @Test("Refresh failure retains the cached linked snapshot")
  func refreshFailureRetainsData() async throws {
    let cached = snapshot(id: "cached", entityName: "Still here")
    let preferences = MemoryPreferences(mode: .linkedMac)
    let store = try temporaryStore(containing: cached)
    defer { try? FileManager.default.removeItem(at: store.root.deletingLastPathComponent()) }
    let model = makeModel(preferences: preferences, store: store) {
      throw CollectionFailure.denied
    }

    model.refreshLiveData()
    try await waitUntil { !model.isCollecting }

    #expect(model.dataSourceMode == .linkedMac)
    #expect(model.fixture == cached.graph)
    #expect(model.collectionError?.contains("Permission denied") == true)
    #expect(preferences.mode() == .linkedMac)
  }

  @Test("Initial-link failure remains synthetic and can be retried")
  func initialLinkFailure() async throws {
    let preferences = MemoryPreferences()
    let sequence = SnapshotSequence([
      .failure(CollectionFailure.denied),
      .success(snapshot(id: "retry", entityName: "Retry succeeded")),
    ])
    let model = makeModel(preferences: preferences) { try sequence.nextResult() }

    model.linkToMac()
    try await waitUntil { !model.isCollecting }
    #expect(model.dataSourceMode == .synthetic)
    #expect(model.collectionError?.contains("Permission denied") == true)

    model.linkToMac()
    try await waitUntil { !model.isCollecting }
    #expect(model.dataSourceMode == .linkedMac)
    #expect(model.linkCompletionPending)
  }

  @Test("Configuration failures identify the collector and preserve diagnostics")
  func collectorAwareFailure() {
    let message = AppModel.collectionFailureMessage(
      ApplicationCollectorConfigurationError.invalid(
        "Validation failed at $.roots[0].path"
      )
    )

    #expect(message.contains("application discovery"))
    #expect(message.contains("$.roots[0].path"))
    #expect(message.contains("No applications or machine data were changed"))
  }

  @Test("Application scope and collector coverage counts remain explicit")
  func coverageCounts() {
    let unused = snapshot(id: "unused", entityName: "Unused")
    let model = makeModel(preferences: MemoryPreferences()) { unused }

    #expect(model.applicationScopeCounts.visible == 1)
    #expect(model.applicationScopeCounts.total == 1)
    #expect(model.collectorCoverageCounts.total == 0)
    #expect(model.applicationEvidenceFactCount == 0)
  }

  @Test("Linked application inventory defaults to User-installed without a hidden source filter")
  func applicationInventoryUsesVisibleDefaultFilter() throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let linked = GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(id: "sources", name: "Sources", summary: "Sources"),
        entities: [
          Entity(
            id: "warp",
            type: .application,
            name: "Warp",
            summary: "Terminal application",
            details: [
              Detail("Path", "/Applications/Warp.app"),
              Detail("Installed with", "Homebrew cask warp"),
              Detail("Platform binary", "No"),
            ]
          ),
          Entity(
            id: "local",
            type: .application,
            name: "Local",
            summary: "Local application",
            details: [
              Detail("Path", "/Applications/Local.app"),
              Detail("Platform binary", "No"),
            ]
          ),
        ],
        relationships: []
      ),
      scan: ScanContext(
        id: "sources",
        environment: .liveReadOnly,
        startedAt: date,
        completedAt: date
      )
    )
    let store = try temporaryStore(containing: linked)
    defer { try? FileManager.default.removeItem(at: store.root.deletingLastPathComponent()) }
    let model = AppModel(
      configuration: .phaseZero,
      applicationClassifications: try ApplicationClassificationConfiguration.bundled(),
      syntheticProvider: StaticProvider(snapshot(id: "synthetic", entityName: "Fictional")),
      preferences: MemoryPreferences(mode: .linkedMac),
      userDataStore: store,
      liveSnapshot: { linked }
    )

    #expect(model.selectedApplicationCategoryID == "user-installed")
    #expect(
      model.applications(in: model.selectedApplicationCategoryID).map(\.id) == ["warp", "local"])
    #expect(model.applicationScopeCounts.visible == 2)

    model.selectedApplicationCategoryID = "user-installed"
    #expect(
      model.applications(in: model.selectedApplicationCategoryID).map(\.id) == ["warp", "local"]
    )
    #expect(model.applicationSourceLabel(linked.graph.entity("warp")!) == "Homebrew Casks")
  }

  @Test("App Store management does not turn a third-party app into bundled software")
  func thirdPartyAppStoreApplicationStaysUserInstalled() throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let nord = Entity(
      id: "nord",
      type: .application,
      name: "NordVPN",
      summary: "Application",
      details: [
        Detail("Path", "/Applications/NordVPN.app"),
        Detail("Bundle identifier", "com.nordvpn.NordVPN"),
        Detail("Platform binary", "No"),
        Detail("App Store receipt", "Present"),
        Detail("Installation timing", "Predates setup marker"),
      ]
    )
    let linked = GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(id: "nord", name: "Nord", summary: "Nord"),
        entities: [nord],
        relationships: []
      ),
      scan: ScanContext(
        id: "nord",
        environment: .liveReadOnly,
        startedAt: date,
        completedAt: date
      )
    )
    let store = try temporaryStore(containing: linked)
    defer { try? FileManager.default.removeItem(at: store.root.deletingLastPathComponent()) }
    let model = AppModel(
      configuration: .phaseZero,
      applicationClassifications: try ApplicationClassificationConfiguration.bundled(),
      syntheticProvider: StaticProvider(snapshot(id: "synthetic", entityName: "Fictional")),
      preferences: MemoryPreferences(mode: .linkedMac),
      userDataStore: store,
      liveSnapshot: { linked }
    )

    #expect(model.applications(in: "user-installed").map(\.id) == [nord.id])
    #expect(model.applications(in: "bundled-software").isEmpty)
    #expect(model.applicationSourceLabel(nord) == "App Store managed")
  }

  @Test("Relationship-map universe navigation preserves back and forward history")
  func graphUniverseHistory() {
    let unused = snapshot(id: "unused", entityName: "Unused")
    let model = makeModel(preferences: MemoryPreferences()) { unused }
    let first = Entity(id: "first", type: .packageManager, name: "Homebrew", summary: "Manager")
    let second = Entity(id: "second", type: .package, name: "Go", summary: "Package")
    model.fixture = SystemGraph(
      metadata: FixtureMetadata(id: "history", name: "History", summary: "History"),
      entities: [first, second],
      relationships: [
        Relationship(
          id: "owns",
          source: first.id,
          target: second.id,
          type: .owns,
          confidence: .confirmed,
          explanation: "Homebrew owns Go.",
          evidence: []
        )
      ]
    )

    model.focus(first)
    model.focus(second)
    #expect(model.destination == .entity(second.id))
    #expect(model.canGoBackInGraphHistory)

    model.goBackInGraphHistory()
    #expect(model.destination == .entity(first.id))
    #expect(model.canGoForwardInGraphHistory)

    model.goForwardInGraphHistory()
    #expect(model.destination == .entity(second.id))
  }

  @Test("Linked storage and performance views use collected entity types")
  func linkedDestinationScopes() throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let linked = GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(id: "linked", name: "This Mac", summary: "Linked"),
        entities: [
          Entity(id: "app", type: .application, name: "App", summary: "App"),
          Entity(id: "process", type: .process, name: "Process", summary: "Process"),
          Entity(
            id: "cache",
            type: .file,
            name: "Cache",
            summary: "Observed rebuildable root",
            details: [Detail("Rebuildability", "Rebuildable")]
          ),
        ],
        relationships: []
      ),
      scan: ScanContext(
        id: "linked",
        environment: .liveReadOnly,
        startedAt: date,
        completedAt: date
      )
    )
    let store = try temporaryStore(containing: linked)
    defer { try? FileManager.default.removeItem(at: store.root.deletingLastPathComponent()) }
    let model = makeModel(
      preferences: MemoryPreferences(mode: .linkedMac),
      store: store
    ) { linked }

    model.navigate(to: .storage)
    #expect(model.presentedGraph.entities.map(\.id) == ["cache"])

    model.navigate(to: .performance)
    #expect(model.presentedGraph.entities.map(\.id) == ["process"])
  }

  @Test("Package manager focus presents every direct installation and managed artifact")
  func packageManagerFocus() {
    let linked = GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(id: "linked", name: "This Mac", summary: "Linked"),
        entities: [
          Entity(id: "brew", type: .packageManager, name: "Homebrew", summary: "Manager"),
          Entity(id: "go", type: .package, name: "go", summary: "Formula"),
          Entity(id: "app", type: .application, name: "Cask App", summary: "Cask"),
          Entity(id: "cache", type: .file, name: "Cache", summary: "Managed data"),
          Entity(id: "process", type: .process, name: "Go process", summary: "Second hop"),
        ],
        relationships: [
          Relationship(
            id: "brew-go",
            source: "brew",
            target: "go",
            type: .owns,
            confidence: .confirmed,
            explanation: "Installed formula",
            evidence: []
          ),
          Relationship(
            id: "brew-app",
            source: "brew",
            target: "app",
            type: .owns,
            confidence: .confirmed,
            explanation: "Installed cask",
            evidence: []
          ),
          Relationship(
            id: "brew-cache",
            source: "brew",
            target: "cache",
            type: .owns,
            confidence: .confirmed,
            explanation: "Managed cache",
            evidence: []
          ),
          Relationship(
            id: "go-process",
            source: "go",
            target: "process",
            type: .launches,
            confidence: .confirmed,
            explanation: "Second-hop runtime",
            evidence: []
          ),
        ]
      ),
      scan: ScanContext(
        id: "linked",
        environment: .liveReadOnly,
        startedAt: .now,
        completedAt: .now
      )
    )
    let model = makeModel(preferences: MemoryPreferences()) { linked }
    model.fixture = linked.graph
    model.visibleTypes = Set<EntityType>([.packageManager])

    model.focus(linked.graph.entity("brew")!)

    #expect(Set(model.presentedGraph.entities.map(\.id)) == ["brew", "go", "app", "cache"])
    #expect(
      Set(model.presentedGraph.relationships.map(\.id)) == [
        "brew-app", "brew-cache", "brew-go",
      ])
    #expect(
      model.visibleTypes.isSuperset(
        of: Set<EntityType>([.packageManager, .package, .application, .file])
      ))
    #expect(model.selection == GraphSelection(.entity("brew")))
  }

  private func makeModel(
    preferences: MemoryPreferences,
    store: HALUserDataStore? = nil,
    live: @escaping @Sendable () throws -> GraphSnapshot
  ) -> AppModel {
    AppModel(
      configuration: .phaseZero,
      applicationClassifications: nil,
      syntheticProvider: StaticProvider(snapshot(id: "synthetic", entityName: "Fictional")),
      preferences: preferences,
      userDataStore: store,
      liveSnapshot: live
    )
  }

  private func temporaryStore(containing snapshot: GraphSnapshot) throws -> HALUserDataStore {
    let parent = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let store = HALUserDataStore(root: parent.appending(path: "HAL"))
    try store.saveSnapshot(snapshot)
    return store
  }

  private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: @escaping @MainActor () -> Bool
  ) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
      guard clock.now < deadline else { throw WaitFailure.timedOut }
      await Task.yield()
    }
  }

  private func snapshot(id: String, entityName: String) -> GraphSnapshot {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    return GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(id: id, name: id, summary: id),
        entities: [
          Entity(
            id: EntityID("application:\(id)"),
            type: .application,
            name: entityName,
            summary: entityName
          )
        ],
        relationships: []
      ),
      scan: ScanContext(
        id: ScanID(id),
        environment: id == "synthetic" ? .synthetic : .liveReadOnly,
        startedAt: date,
        completedAt: date
      )
    )
  }
}

private struct StaticProvider: GraphSnapshotProvider {
  let value: GraphSnapshot

  init(_ value: GraphSnapshot) {
    self.value = value
  }

  func snapshot() -> GraphSnapshot { value }
}

private final class MemoryPreferences: DataSourcePreferenceStore, @unchecked Sendable {
  private let lock = NSLock()
  private var storedMode: DataSourceMode
  private var welcome = false

  init(mode: DataSourceMode = .synthetic) {
    storedMode = mode
  }

  func mode() -> DataSourceMode {
    lock.withLock { storedMode }
  }

  func setMode(_ mode: DataSourceMode) {
    lock.withLock { storedMode = mode }
  }

  func syntheticWelcomeDismissed() -> Bool {
    lock.withLock { welcome }
  }

  func setSyntheticWelcomeDismissed(_ dismissed: Bool) {
    lock.withLock { welcome = dismissed }
  }
}

private final class CollectionGate: @unchecked Sendable {
  private let started = DispatchSemaphore(value: 0)
  private let released = DispatchSemaphore(value: 0)
  private let result: Result<GraphSnapshot, Error>
  private let lock = NSLock()
  private var startedValue = false

  init(result: Result<GraphSnapshot, Error>) {
    self.result = result
  }

  var hasStarted: Bool { lock.withLock { startedValue } }

  func collect() throws -> GraphSnapshot {
    lock.withLock { startedValue = true }
    started.signal()
    released.wait()
    return try result.get()
  }

  func release() {
    released.signal()
  }
}

private final class SnapshotSequence: @unchecked Sendable {
  private let lock = NSLock()
  private var results: [Result<GraphSnapshot, Error>]

  init(_ snapshots: [GraphSnapshot]) {
    results = snapshots.map(Result.success)
  }

  init(_ results: [Result<GraphSnapshot, Error>]) {
    self.results = results
  }

  func next() throws -> GraphSnapshot { try nextResult() }

  func nextResult() throws -> GraphSnapshot {
    try lock.withLock {
      guard !results.isEmpty else { throw CollectionFailure.exhausted }
      return try results.removeFirst().get()
    }
  }
}

private enum CollectionFailure: LocalizedError {
  case denied
  case exhausted

  var errorDescription: String? {
    switch self {
    case .denied: "Permission denied by test collector."
    case .exhausted: "No test result remains."
    }
  }
}

private enum WaitFailure: Error {
  case timedOut
}
