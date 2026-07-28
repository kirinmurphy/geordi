import Foundation
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
