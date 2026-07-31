import Foundation
import HALDomain

public struct ApplicationInventorySnapshotProvider: GraphSnapshotProvider {
  public let scanID: ScanID
  public let collector: ApplicationBundleCollector
  public let signatureCollector: ApplicationSignatureCollector
  public let provenanceCollector: ApplicationProvenanceCollector
  public let associatedLocationCollector: ApplicationAssociatedLocationCollector
  public let rebuildableDataCollector: RebuildableDataCollector?
  public let processCollector: ProcessCollector
  public let processResolver: ProcessApplicationResolver
  public let maxProcessesPerApplication: Int
  public let maxUnmatchedProcesses: Int
  public let persistenceCollector: PersistenceCollector
  public let persistenceResolver: PersistenceApplicationResolver
  public let persistenceRuntimeMatcher: PersistenceRuntimeMatcher?
  public let homebrewCollector: HomebrewCollector?
  public let runtimeCollector: RuntimeCollector?
  public let packageEcosystemCollector: PackageEcosystemCollector?
  public let commandLineSoftwareCollector: CommandLineSoftwareCollector?
  public let shellFrameworkCollector: ShellFrameworkCollector?
  public let projector: ApplicationGraphProjector
  public let applicationClassifications: ApplicationClassificationConfiguration?

  public init(
    scanID: ScanID,
    roots: [ApplicationSearchRoot],
    setupEvidence: ApplicationSetupEvidenceConfiguration? = nil,
    provenanceConfiguration: ApplicationProvenanceConfiguration,
    associatedLocationConfiguration: ApplicationAssociatedLocationConfiguration,
    rebuildableDataConfiguration: RebuildableDataConfiguration? = nil,
    processConfiguration: ProcessCollectorConfiguration,
    persistenceRoots: [PersistenceSearchRoot],
    persistenceRuntimeMatchingConfiguration: PersistenceRuntimeMatchingConfiguration? = nil,
    homebrewConfiguration: HomebrewInstallationConfiguration? = nil,
    runtimeConfiguration: RuntimeCollectorConfiguration? = nil,
    packageEcosystemConfiguration: PackageEcosystemConfiguration? = nil,
    commandLineSoftwareConfiguration: CommandLineSoftwareConfiguration? = nil,
    shellFrameworkConfiguration: ShellFrameworkConfiguration? = nil,
    applicationClassifications: ApplicationClassificationConfiguration? = nil,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    signatureInspector: any CodeSignatureInspecting = SecurityCodeSignatureInspector(),
    provenanceInspector: any ApplicationProvenanceInspecting =
      FileSystemApplicationProvenanceInspector(),
    associatedLocationInspector: any AssociatedLocationInspecting =
      FileSystemAssociatedLocationInspector(),
    associatedLocationEnumerator: any AssociatedLocationEnumerating =
      FileSystemAssociatedLocationEnumerator(),
    rebuildableDataInspector: any RebuildableDataInspecting =
      FileSystemRebuildableDataInspector(),
    processSampler: any ProcessSampling = PSProcessSampler(),
    maxUnmatchedProcesses: Int = 0,
    clock: any HALClock = SystemClock()
  ) {
    self.scanID = scanID
    collector = ApplicationBundleCollector(
      roots: roots,
      setupMarkerURL: setupEvidence?.url,
      setupTolerance: TimeInterval(setupEvidence?.toleranceSeconds ?? 300),
      clock: clock
    )
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
      enumerator: associatedLocationEnumerator,
      clock: clock
    )
    rebuildableDataCollector = rebuildableDataConfiguration.map {
      RebuildableDataCollector(
        configuration: $0,
        userHome: userHome,
        inspector: rebuildableDataInspector,
        clock: clock
      )
    }
    processCollector = ProcessCollector(sampler: processSampler, clock: clock)
    processResolver = ProcessApplicationResolver(
      configuration: processConfiguration,
      clock: clock
    )
    maxProcessesPerApplication = processConfiguration.maxProcessesPerApplication
    self.maxUnmatchedProcesses = maxUnmatchedProcesses
    self.applicationClassifications = applicationClassifications
    persistenceCollector = PersistenceCollector(
      roots: persistenceRoots,
      clock: clock
    )
    persistenceResolver = PersistenceApplicationResolver(clock: clock)
    persistenceRuntimeMatcher = persistenceRuntimeMatchingConfiguration.map {
      PersistenceRuntimeMatcher(configuration: $0, clock: clock)
    }
    homebrewCollector = homebrewConfiguration.map {
      HomebrewCollector(configuration: $0, clock: clock)
    }
    runtimeCollector = runtimeConfiguration.map {
      RuntimeCollector(configuration: $0, userHome: userHome, clock: clock)
    }
    packageEcosystemCollector = packageEcosystemConfiguration.map {
      PackageEcosystemCollector(configuration: $0, userHome: userHome, clock: clock)
    }
    commandLineSoftwareCollector = commandLineSoftwareConfiguration.map {
      CommandLineSoftwareCollector(configuration: $0, userHome: userHome, clock: clock)
    }
    shellFrameworkCollector = shellFrameworkConfiguration.map {
      ShellFrameworkCollector(configuration: $0, userHome: userHome, clock: clock)
    }
    projector = ApplicationGraphProjector()
  }

  public init(
    scanID: ScanID,
    configuration: ApplicationCollectorConfiguration,
    provenanceConfiguration: ApplicationProvenanceConfiguration,
    associatedLocationConfiguration: ApplicationAssociatedLocationConfiguration,
    rebuildableDataConfiguration: RebuildableDataConfiguration? = nil,
    processConfiguration: ProcessCollectorConfiguration,
    persistenceConfiguration: PersistenceCollectorConfiguration,
    persistenceRuntimeMatchingConfiguration: PersistenceRuntimeMatchingConfiguration? = nil,
    homebrewConfiguration: HomebrewInstallationConfiguration? = nil,
    runtimeConfiguration: RuntimeCollectorConfiguration? = nil,
    packageEcosystemConfiguration: PackageEcosystemConfiguration? = nil,
    commandLineSoftwareConfiguration: CommandLineSoftwareConfiguration? = nil,
    shellFrameworkConfiguration: ShellFrameworkConfiguration? = nil,
    applicationClassifications: ApplicationClassificationConfiguration? = nil,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    signatureInspector: any CodeSignatureInspecting = SecurityCodeSignatureInspector(),
    provenanceInspector: any ApplicationProvenanceInspecting =
      FileSystemApplicationProvenanceInspector(),
    associatedLocationInspector: any AssociatedLocationInspecting =
      FileSystemAssociatedLocationInspector(),
    associatedLocationEnumerator: any AssociatedLocationEnumerating =
      FileSystemAssociatedLocationEnumerator(),
    rebuildableDataInspector: any RebuildableDataInspecting =
      FileSystemRebuildableDataInspector(),
    processSampler: any ProcessSampling = PSProcessSampler(),
    clock: any HALClock = SystemClock()
  ) throws {
    try self.init(
      scanID: scanID,
      roots: configuration.searchRoots(userHome: userHome),
      setupEvidence: configuration.setupEvidence,
      provenanceConfiguration: provenanceConfiguration,
      associatedLocationConfiguration: associatedLocationConfiguration,
      rebuildableDataConfiguration: rebuildableDataConfiguration,
      processConfiguration: processConfiguration,
      persistenceRoots: try persistenceConfiguration.resolvedRoots(userHome: userHome),
      persistenceRuntimeMatchingConfiguration: persistenceRuntimeMatchingConfiguration,
      homebrewConfiguration: homebrewConfiguration,
      runtimeConfiguration: runtimeConfiguration,
      packageEcosystemConfiguration: packageEcosystemConfiguration,
      commandLineSoftwareConfiguration: commandLineSoftwareConfiguration,
      shellFrameworkConfiguration: shellFrameworkConfiguration,
      applicationClassifications: applicationClassifications,
      userHome: userHome,
      signatureInspector: signatureInspector,
      provenanceInspector: provenanceInspector,
      associatedLocationInspector: associatedLocationInspector,
      associatedLocationEnumerator: associatedLocationEnumerator,
      rebuildableDataInspector: rebuildableDataInspector,
      processSampler: processSampler,
      maxUnmatchedProcesses: processConfiguration.maxUnmatchedProcesses,
      clock: clock
    )
  }

  public func snapshot() -> GraphSnapshot {
    do {
      return try cancellableSnapshot()
    } catch {
      return unavailableSnapshot(error)
    }
  }

  public func cancellableSnapshot() throws -> GraphSnapshot {
    try Task.checkCancellation()
    let applications = collector.collect(scanID: scanID)
    try Task.checkCancellation()
    let signatures = signatureCollector.collect(
      scanID: scanID,
      applications: applications.observations
    )
    let provenance = provenanceCollector.collect(
      scanID: scanID,
      applications: applications.observations
    )
    try Task.checkCancellation()
    let associatedLocations = associatedLocationCollector.collect(
      scanID: scanID,
      applications: applications.observations,
      signatures: signatures.observations
    )
    try Task.checkCancellation()
    let rebuildableData = rebuildableDataCollector?.collect(scanID: scanID)
    try Task.checkCancellation()
    let processes = processCollector.collect(scanID: scanID)
    let processResolutions = processResolver.resolve(
      scanID: scanID,
      processes: processes,
      applications: applications.observations
    )
    try Task.checkCancellation()
    let persistence = persistenceCollector.collect(scanID: scanID)
    let persistenceResolutions = persistenceResolver.resolve(
      scanID: scanID,
      declarations: persistence,
      applications: applications.observations
    )
    let persistenceRuntimeCorrelations = persistenceRuntimeMatcher?.match(
      scanID: scanID,
      declarations: persistence,
      processes: processes
    )
    try Task.checkCancellation()
    let homebrew = homebrewCollector?.collect(scanID: scanID)
    try Task.checkCancellation()
    let runtimes = runtimeCollector?.collect(scanID: scanID)
    try Task.checkCancellation()
    let packageEcosystems = packageEcosystemCollector?.collect(scanID: scanID)
    try Task.checkCancellation()
    let commandLineSoftware = commandLineSoftwareCollector?.collect(scanID: scanID)
    try Task.checkCancellation()
    let shellFrameworks = shellFrameworkCollector?.collect(scanID: scanID)
    try Task.checkCancellation()
    let snapshot = projector.snapshot(
      scanID: scanID,
      output: applications,
      signatures: signatures,
      provenance: provenance,
      associatedLocations: associatedLocations,
      rebuildableData: rebuildableData,
      processes: processes,
      processResolutions: processResolutions,
      maxProcessesPerApplication: maxProcessesPerApplication,
      maxUnmatchedProcesses: maxUnmatchedProcesses,
      persistence: persistence,
      persistenceResolutions: persistenceResolutions,
      persistenceRuntimeCorrelations: persistenceRuntimeCorrelations,
      homebrew: homebrew,
      runtimes: runtimes,
      packageEcosystems: packageEcosystems,
      commandLineSoftware: commandLineSoftware,
      shellFrameworks: shellFrameworks,
      applicationClassifications: applicationClassifications
    )
    try snapshot.graph.validate()
    return snapshot
  }

  private func unavailableSnapshot(_ error: Error) -> GraphSnapshot {
    let now = Date()
    return GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(
          id: "live-applications-\(scanID.rawValue)",
          name: "This Mac",
          summary: "Application inventory collection was unavailable."
        ),
        entities: [],
        relationships: []
      ),
      scan: ScanContext(
        id: scanID,
        environment: .liveReadOnly,
        startedAt: now,
        completedAt: now,
        collectorRuns: [
          CollectorRun(
            collectorID: "application-inventory",
            collectorVersion: 1,
            availability: .unavailable,
            state: .failed,
            startedAt: now,
            completedAt: now,
            issues: [
              CollectionIssue(
                id: "application-inventory-failure",
                severity: .error,
                summary: String(describing: error)
              )
            ]
          )
        ]
      )
    )
  }
}
