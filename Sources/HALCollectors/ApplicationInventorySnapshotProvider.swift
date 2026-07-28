import Foundation
import HALDomain

public struct ApplicationInventorySnapshotProvider: GraphSnapshotProvider {
  public let scanID: ScanID
  public let collector: ApplicationBundleCollector
  public let signatureCollector: ApplicationSignatureCollector
  public let provenanceCollector: ApplicationProvenanceCollector
  public let associatedLocationCollector: ApplicationAssociatedLocationCollector
  public let processCollector: ProcessCollector
  public let processResolver: ProcessApplicationResolver
  public let maxProcessesPerApplication: Int
  public let projector: ApplicationGraphProjector

  public init(
    scanID: ScanID,
    roots: [ApplicationSearchRoot],
    provenanceConfiguration: ApplicationProvenanceConfiguration,
    associatedLocationConfiguration: ApplicationAssociatedLocationConfiguration,
    processConfiguration: ProcessCollectorConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    signatureInspector: any CodeSignatureInspecting = SecurityCodeSignatureInspector(),
    provenanceInspector: any ApplicationProvenanceInspecting =
      FileSystemApplicationProvenanceInspector(),
    associatedLocationInspector: any AssociatedLocationInspecting =
      FileSystemAssociatedLocationInspector(),
    processSampler: any ProcessSampling = PSProcessSampler(),
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
    processCollector = ProcessCollector(sampler: processSampler, clock: clock)
    processResolver = ProcessApplicationResolver(
      configuration: processConfiguration,
      clock: clock
    )
    maxProcessesPerApplication = processConfiguration.maxProcessesPerApplication
    projector = ApplicationGraphProjector()
  }

  public init(
    scanID: ScanID,
    configuration: ApplicationCollectorConfiguration,
    provenanceConfiguration: ApplicationProvenanceConfiguration,
    associatedLocationConfiguration: ApplicationAssociatedLocationConfiguration,
    processConfiguration: ProcessCollectorConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    signatureInspector: any CodeSignatureInspecting = SecurityCodeSignatureInspector(),
    provenanceInspector: any ApplicationProvenanceInspecting =
      FileSystemApplicationProvenanceInspector(),
    associatedLocationInspector: any AssociatedLocationInspecting =
      FileSystemAssociatedLocationInspector(),
    processSampler: any ProcessSampling = PSProcessSampler(),
    clock: any HALClock = SystemClock()
  ) throws {
    try self.init(
      scanID: scanID,
      roots: configuration.searchRoots(userHome: userHome),
      provenanceConfiguration: provenanceConfiguration,
      associatedLocationConfiguration: associatedLocationConfiguration,
      processConfiguration: processConfiguration,
      userHome: userHome,
      signatureInspector: signatureInspector,
      provenanceInspector: provenanceInspector,
      associatedLocationInspector: associatedLocationInspector,
      processSampler: processSampler,
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
    let processes = processCollector.collect(scanID: scanID)
    let processResolutions = processResolver.resolve(
      scanID: scanID,
      processes: processes,
      applications: applications.observations
    )
    return projector.snapshot(
      scanID: scanID,
      output: applications,
      signatures: signatures,
      provenance: provenance,
      associatedLocations: associatedLocations,
      processes: processes,
      processResolutions: processResolutions,
      maxProcessesPerApplication: maxProcessesPerApplication
    )
  }
}
