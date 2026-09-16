import Foundation
import GeordiCollectors
import GeordiDataSource
import GeordiDomain
import GeordiFixtures
import Testing

@testable import GeordiApp

/// Home-page reclaimable-data contract. The Home "Reclaimable Data" section
/// renders exactly what `AppModel.reclaimCandidates` selects — these tests
/// simulate that selection end-to-end for both data sources: the committed
/// synthetic profile, and a live snapshot produced by the real
/// collector → projector pipeline.
@Suite("Home reclaimable candidates")
@MainActor
struct ReclaimableCandidatesTests {
  @Test("Synthetic profile yields the five reclaimable caches")
  func syntheticFixtureSelectsReclaimables() {
    let model = makeSyntheticModel(FixtureCatalog.familiarMac)

    #expect(model.isSynthetic)
    let candidates = model.reclaimCandidates
    #expect(candidates.count == 5)
    #expect(candidates.allSatisfy { $0.type == .file })
    #expect(
      Set(candidates.map(\.name)) == [
        "Docker build cache",
        "VS Code workspace cache",
        "Brave browser cache",
        "Homebrew download cache",
        "npm cache",
      ])

    let total = candidates.compactMap { file -> Double? in
      guard
        let raw = file.details.first(where: { $0.label == "Synthetic size" })?.value
      else { return nil }
      return Double(raw.prefix { $0.isNumber || $0 == "." })
    }.reduce(0, +)
    #expect(abs(total - 23.5) < 0.01)
  }

  @Test("Linked Mac shows detector-observed rebuildable roots on Home")
  func linkedMacSurfacesRebuildables() async throws {
    let live = try makeLiveSnapshot()
    let model = makeLinkedModel(live: live)

    model.linkToMac()
    try await waitUntil { !model.isCollecting }

    #expect(!model.isSynthetic)
    let candidates = model.reclaimCandidates
    #expect(candidates.count == 1)
    #expect(candidates[0].type == .file)
    #expect(candidates[0].name == "present")
    #expect(candidates[0].detail(.rebuildability) == "Rebuildable")
    #expect(candidates[0].detail(.path) == "/test-home/present")
  }

  // MARK: - Helpers

  private func makeSyntheticModel(_ graph: SystemGraph) -> AppModel {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let snapshot = GraphSnapshot(
      graph: graph,
      scan: ScanContext(
        id: ScanID("synthetic"),
        environment: .synthetic,
        startedAt: date,
        completedAt: date
      )
    )
    let parent = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    return AppModel(
      configuration: .phaseZero,
      applicationClassifications: nil,
      syntheticProvider: StaticProvider(value: snapshot),
      preferences: MemoryPreferences(),
      userDataStore: UserDataStore(root: parent.appending(path: "UserData")),
      liveSnapshot: { snapshot }
    )
  }

  private func makeLinkedModel(live: GraphSnapshot) -> AppModel {
    let parent = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    return AppModel(
      configuration: .phaseZero,
      applicationClassifications: nil,
      syntheticProvider: StaticProvider(value: syntheticSnapshot()),
      preferences: MemoryPreferences(),
      userDataStore: UserDataStore(root: parent.appending(path: "UserData")),
      liveSnapshot: { live }
    )
  }

  /// Runs the real rebuildable-data collector and real graph projector —
  /// the same pipeline `LiveApplicationSnapshotFactory` drives — with a
  /// stubbed filesystem inspector so the simulation stays sandboxed.
  private func makeLiveSnapshot() throws -> GraphSnapshot {
    let timestamp = Date(timeIntervalSince1970: 1_753_545_600)
    let output = RebuildableDataCollector(
      configuration: RebuildableDataConfiguration(
        classifications: [
          RebuildableDataClassification(
            id: "build",
            label: "Build output",
            rebuildability: .rebuildable
          )
        ],
        detectors: [
          RebuildableDataDetector(
            id: "test-detector",
            classificationID: "build",
            locations: [(id: "present", path: "$USER_HOME/present")].map {
              RebuildableDataLocation(id: $0.id, path: $0.path)
            },
            excludedDescendantNames: [".git"],
            evidenceRule: RebuildableDataEvidenceRule(
              id: "test-rule",
              kind: .toolManagedRoot,
              confidence: .high,
              explanation: "The test tool manages this root."
            )
          )
        ]
      ),
      userHome: URL(fileURLWithPath: "/test-home"),
      inspector: PresentDirectoryInspector(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")
    let applications = CollectorOutput<ApplicationBundleValue>(
      run: CollectorRun(
        collectorID: ApplicationBundleCollector.id,
        collectorVersion: 1,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: []
    )
    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: applications,
      rebuildableData: output
    )
    try snapshot.graph.validate()
    return GraphSnapshot(
      graph: snapshot.graph,
      scan: ScanContext(
        id: ScanID("live"),
        environment: .liveReadOnly,
        startedAt: timestamp,
        completedAt: timestamp
      )
    )
  }

  private func syntheticSnapshot() -> GraphSnapshot {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    return GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(id: "synthetic", name: "synthetic", summary: "synthetic"),
        entities: [
          Entity(
            id: EntityID("application:synthetic"),
            type: .application,
            name: "Fictional",
            summary: "Fictional"
          )
        ],
        relationships: []
      ),
      scan: ScanContext(
        id: ScanID("synthetic"),
        environment: .synthetic,
        startedAt: date,
        completedAt: date
      )
    )
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

  enum WaitFailure: Error { case timedOut }
}

private struct StaticProvider: GraphSnapshotProvider {
  let value: GraphSnapshot
  func snapshot() -> GraphSnapshot { value }
}

private final class MemoryPreferences: DataSourcePreferenceStore, @unchecked Sendable {
  private let lock = NSLock()
  private var storedMode: DataSourceMode
  private var welcome = false

  init(mode: DataSourceMode = .synthetic) {
    storedMode = mode
  }

  func mode() -> DataSourceMode { lock.withLock { storedMode } }

  func setMode(_ mode: DataSourceMode) { lock.withLock { storedMode = mode } }

  func syntheticWelcomeDismissed() -> Bool { lock.withLock { welcome } }

  func setSyntheticWelcomeDismissed(_ dismissed: Bool) { lock.withLock { welcome = dismissed } }
}

private struct PresentDirectoryInspector: RebuildableDataInspecting {
  func inspectLocation(at url: URL) -> RebuildableDataInspection {
    RebuildableDataInspection(status: .present, isDirectory: true, isSymbolicLink: false)
  }
}
