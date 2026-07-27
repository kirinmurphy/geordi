import Foundation
import HALDomain

public struct ApplicationInventorySnapshotProvider: GraphSnapshotProvider {
  public let scanID: ScanID
  public let collector: ApplicationBundleCollector
  public let signatureCollector: ApplicationSignatureCollector
  public let projector: ApplicationGraphProjector

  public init(
    scanID: ScanID,
    roots: [ApplicationSearchRoot],
    signatureInspector: any CodeSignatureInspecting = SecurityCodeSignatureInspector(),
    clock: any HALClock = SystemClock()
  ) {
    self.scanID = scanID
    collector = ApplicationBundleCollector(roots: roots, clock: clock)
    signatureCollector = ApplicationSignatureCollector(
      inspector: signatureInspector,
      clock: clock
    )
    projector = ApplicationGraphProjector()
  }

  public init(
    scanID: ScanID,
    configuration: ApplicationCollectorConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    signatureInspector: any CodeSignatureInspecting = SecurityCodeSignatureInspector(),
    clock: any HALClock = SystemClock()
  ) throws {
    try self.init(
      scanID: scanID,
      roots: configuration.searchRoots(userHome: userHome),
      signatureInspector: signatureInspector,
      clock: clock
    )
  }

  public func snapshot() -> GraphSnapshot {
    let applications = collector.collect(scanID: scanID)
    let signatures = signatureCollector.collect(
      scanID: scanID,
      applications: applications.observations
    )
    return projector.snapshot(
      scanID: scanID,
      output: applications,
      signatures: signatures
    )
  }
}
