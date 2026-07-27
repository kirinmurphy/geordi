import HALDomain

public struct ApplicationInventorySnapshotProvider: GraphSnapshotProvider {
  public let scanID: ScanID
  public let collector: ApplicationBundleCollector
  public let projector: ApplicationGraphProjector

  public init(
    scanID: ScanID,
    roots: [ApplicationSearchRoot],
    clock: any HALClock = SystemClock()
  ) {
    self.scanID = scanID
    collector = ApplicationBundleCollector(roots: roots, clock: clock)
    projector = ApplicationGraphProjector()
  }

  public func snapshot() -> GraphSnapshot {
    projector.snapshot(
      scanID: scanID,
      output: collector.collect(scanID: scanID)
    )
  }
}
