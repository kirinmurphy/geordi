import Foundation
import GeordiDomain

private enum IndependentCollectionResult: Sendable {
  case signatures(CollectorOutput<ApplicationSignatureValue>)
  case provenance(CollectorOutput<ApplicationProvenanceValue>)
  case rebuildableData(CollectorOutput<RebuildableDataValue>)
  case processes(CollectorOutput<ProcessValue>)
  case persistence(CollectorOutput<PersistenceDeclarationValue>)
  case homebrew(CollectorOutput<HomebrewInventoryValue>)
  case runtimes(CollectorOutput<RuntimeValue>)
  case packageEcosystems(CollectorOutput<PackageEcosystemInventoryValue>)
  case commandLineSoftware(CollectorOutput<CommandLineSoftwareValue>)
  case shellFrameworks(CollectorOutput<ShellFrameworkValue>)
}

enum BoundedCollectionScheduler {
  static func run<Result: Sendable>(
    _ jobs: [@Sendable () throws -> Result],
    limit: Int
  ) async throws -> [Result] {
    precondition(limit > 0)
    return try await withThrowingTaskGroup(of: (Int, Result).self) { group in
      var nextIndex = 0
      var results = [Result?](repeating: nil, count: jobs.count)

      func submitNext() {
        guard nextIndex < jobs.count else { return }
        let index = nextIndex
        let job = jobs[index]
        nextIndex += 1
        group.addTask {
          try Task.checkCancellation()
          let result = try job()
          try Task.checkCancellation()
          return (index, result)
        }
      }

      for _ in 0..<min(limit, jobs.count) {
        submitNext()
      }
      while let (index, result) = try await group.next() {
        results[index] = result
        submitNext()
      }
      return results.compactMap { $0 }
    }
  }
}

public struct ApplicationInventorySnapshotProvider: Sendable {
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
    clock: any TimeSource = SystemClock()
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
    clock: any TimeSource = SystemClock()
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

  public func cancellableSnapshot(maxConcurrentTasks: Int = 4) async throws -> GraphSnapshot {
    precondition(maxConcurrentTasks > 0)
    try Task.checkCancellation()
    let applications = collector.collect(scanID: scanID)
    guard !applications.observations.isEmpty else {
      throw ApplicationInventorySnapshotError.noApplicationsObserved
    }
    try Task.checkCancellation()

    var jobs: [@Sendable () throws -> IndependentCollectionResult] = [
      {
        .signatures(
          signatureCollector.collect(
            scanID: scanID,
            applications: applications.observations
          )
        )
      },
      {
        .provenance(
          provenanceCollector.collect(
            scanID: scanID,
            applications: applications.observations
          )
        )
      },
      { .processes(processCollector.collect(scanID: scanID)) },
      { .persistence(persistenceCollector.collect(scanID: scanID)) },
    ]
    if let rebuildableDataCollector {
      jobs.append { .rebuildableData(rebuildableDataCollector.collect(scanID: scanID)) }
    }
    if let homebrewCollector {
      jobs.append { .homebrew(homebrewCollector.collect(scanID: scanID)) }
    }
    if let runtimeCollector {
      jobs.append { .runtimes(runtimeCollector.collect(scanID: scanID)) }
    }
    if let packageEcosystemCollector {
      jobs.append { .packageEcosystems(packageEcosystemCollector.collect(scanID: scanID)) }
    }
    if let commandLineSoftwareCollector {
      jobs.append {
        .commandLineSoftware(commandLineSoftwareCollector.collect(scanID: scanID))
      }
    }
    if let shellFrameworkCollector {
      jobs.append { .shellFrameworks(shellFrameworkCollector.collect(scanID: scanID)) }
    }

    let results = try await BoundedCollectionScheduler.run(
      jobs,
      limit: maxConcurrentTasks
    )
    var signatures: CollectorOutput<ApplicationSignatureValue>?
    var provenance: CollectorOutput<ApplicationProvenanceValue>?
    var rebuildableData: CollectorOutput<RebuildableDataValue>?
    var processes: CollectorOutput<ProcessValue>?
    var persistence: CollectorOutput<PersistenceDeclarationValue>?
    var homebrew: CollectorOutput<HomebrewInventoryValue>?
    var runtimes: CollectorOutput<RuntimeValue>?
    var packageEcosystems: CollectorOutput<PackageEcosystemInventoryValue>?
    var commandLineSoftware: CollectorOutput<CommandLineSoftwareValue>?
    var shellFrameworks: CollectorOutput<ShellFrameworkValue>?
    for result in results {
      switch result {
      case .signatures(let output): signatures = output
      case .provenance(let output): provenance = output
      case .rebuildableData(let output): rebuildableData = output
      case .processes(let output): processes = output
      case .persistence(let output): persistence = output
      case .homebrew(let output): homebrew = output
      case .runtimes(let output): runtimes = output
      case .packageEcosystems(let output): packageEcosystems = output
      case .commandLineSoftware(let output): commandLineSoftware = output
      case .shellFrameworks(let output): shellFrameworks = output
      }
    }
    guard
      let signatures,
      let provenance,
      let processes,
      let persistence
    else {
      preconditionFailure("Required collection stages did not produce results.")
    }

    try Task.checkCancellation()
    let associatedLocations = associatedLocationCollector.collect(
      scanID: scanID,
      applications: applications.observations,
      signatures: signatures.observations
    )
    let processResolutions = processResolver.resolve(
      scanID: scanID,
      processes: processes,
      applications: applications.observations
    )
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

}

public enum ApplicationInventorySnapshotError: LocalizedError, Equatable, Sendable {
  case noApplicationsObserved

  public var errorDescription: String? {
    switch self {
    case .noApplicationsObserved:
      "The required application collector completed without observing any applications."
    }
  }
}
