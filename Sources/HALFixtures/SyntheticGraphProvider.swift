import Foundation
import HALDomain

public struct SyntheticGraphProvider: GraphSnapshotProvider {
  public static let defaultTimestamp = Date(timeIntervalSince1970: 1_753_545_600)

  public let fixtureID: String
  private let clock: any HALClock

  public init(
    fixtureID: String,
    clock: any HALClock = FixedClock(SyntheticGraphProvider.defaultTimestamp)
  ) {
    self.fixtureID = fixtureID
    self.clock = clock
  }

  public func snapshot() -> GraphSnapshot {
    let graph = FixtureCatalog.fixture(id: fixtureID) ?? FixtureCatalog.all[0]
    let timestamp = clock.now()
    let collectorRun = CollectorRun(
      collectorID: "synthetic-fixture",
      collectorVersion: graph.metadata.version,
      availability: .available,
      state: .complete,
      startedAt: timestamp,
      completedAt: timestamp,
      scope: [graph.metadata.id]
    )
    return GraphSnapshot(
      graph: graph,
      scan: ScanContext(
        id: ScanID("synthetic-\(graph.metadata.id)-v\(graph.metadata.version)"),
        environment: .synthetic,
        startedAt: timestamp,
        completedAt: timestamp,
        collectorRuns: [collectorRun]
      )
    )
  }
}
