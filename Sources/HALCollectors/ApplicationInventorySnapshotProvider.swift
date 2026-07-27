import Foundation
import HALDomain

public struct ApplicationInventorySnapshotProvider: GraphSnapshotProvider {
  public let scanID: ScanID
  public let collector: ApplicationBundleCollector
  public let signatureCollector: ApplicationSignatureCollector
  public let provenanceCollector: ApplicationProvenanceCollector
  public let associatedLocationCollector: ApplicationAssociatedLocationCollector
  public let projector: ApplicationGraphProjector

  public init(
    scanID: ScanID,
    roots: [ApplicationSearchRoot],
    provenanceConfiguration: ApplicationProvenanceConfiguration,
    associatedLocationConfiguration: ApplicationAssociatedLocationConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    signatureInspector: any CodeSignatureInspecting = SecurityCodeSignatureInspector(),
    provenanceInspector: any ApplicationProvenanceInspecting =
      FileSystemApplicationProvenanceInspector(),
    associatedLocationInspector: any AssociatedLocationInspecting =
      FileSystemAssociatedLocationInspector(),
    clock: any HALClock = SystemClock()
  ) {
    self.scanID = scanID
    collector = ApplicationBundleCollector(roots: roots, clock: clock)
    signatureCollector = ApplicationSignatureCollector(
      inspector: signatureInspector,
      clock: clock
    )
    provenanceCollector = ApplicationProvenanceCollector(
      configuration: provenanceConfiguration,
      inspector: provenanceInspector,
      clock: clock
    )
    associatedLocationCollector = ApplicationAssociatedLocationCollector(
      configuration: associatedLocationConfiguration,
      userHome: userHome,
      inspector: associatedLocationInspector,
      clock: clock
    )
    projector = ApplicationGraphProjector()
  }

  public init(
    scanID: ScanID,
    configuration: ApplicationCollectorConfiguration,
    provenanceConfiguration: ApplicationProvenanceConfiguration,
    associatedLocationConfiguration: ApplicationAssociatedLocationConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    signatureInspector: any CodeSignatureInspecting = SecurityCodeSignatureInspector(),
    provenanceInspector: any ApplicationProvenanceInspecting =
      FileSystemApplicationProvenanceInspector(),
    associatedLocationInspector: any AssociatedLocationInspecting =
      FileSystemAssociatedLocationInspector(),
    clock: any HALClock = SystemClock()
  ) throws {
    try self.init(
      scanID: scanID,
      roots: configuration.searchRoots(userHome: userHome),
      provenanceConfiguration: provenanceConfiguration,
      associatedLocationConfiguration: associatedLocationConfiguration,
      userHome: userHome,
      signatureInspector: signatureInspector,
      provenanceInspector: provenanceInspector,
      associatedLocationInspector: associatedLocationInspector,
      clock: clock
    )
  }

  public func snapshot() -> GraphSnapshot {
    let applications = collector.collect(scanID: scanID)
    let signatures = signatureCollector.collect(
      scanID: scanID,
      applications: applications.observations
    )
    let provenance = provenanceCollector.collect(
      scanID: scanID,
      applications: applications.observations
    )
    let associatedLocations = associatedLocationCollector.collect(
      scanID: scanID,
      applications: applications.observations
    )
    return projector.snapshot(
      scanID: scanID,
      output: applications,
      signatures: signatures,
      provenance: provenance,
      associatedLocations: associatedLocations
    )
  }
}
