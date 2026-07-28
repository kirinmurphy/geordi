import Foundation
import HALDomain

public struct ProcessApplicationResolver: Sendable {
  public static let id: CollectorID = "process-application-resolution"
  public static let version = 1

  private let configuration: ProcessCollectorConfiguration
  private let clock: any HALClock

  public init(
    configuration: ProcessCollectorConfiguration,
    clock: any HALClock = SystemClock()
  ) {
    self.configuration = configuration
    self.clock = clock
  }

  public func resolve(
    scanID: ScanID,
    processes: CollectorOutput<ProcessValue>,
    applications: [CollectedObservation<ApplicationBundleValue>]
  ) -> CollectorOutput<ProcessApplicationResolutionValue> {
    let startedAt = clock.now()
    let strategies = configuration.strategies.sorted { $0.priority > $1.priority }
    let observations = processes.observations.map { process in
      CollectedObservation(
        id: ObservationID("process-resolution:\(scanID.rawValue):\(process.value.pid)"),
        scanID: scanID,
        collectorID: Self.id,
        schemaVersion: Self.version,
        observedAt: startedAt,
        subject: process.subject,
        sensitivity: process.sensitivity,
        sourceReference: process.sourceReference,
        value: resolution(
          for: process.value,
          applications: applications,
          strategies: strategies
        )
      )
    }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: processes.run.availability,
        state: processes.run.state,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: strategies.map(\.id),
        issues: processes.run.issues
      ),
      observations: observations
    )
  }

  private func resolution(
    for process: ProcessValue,
    applications: [CollectedObservation<ApplicationBundleValue>],
    strategies: [ProcessResolutionStrategy]
  ) -> ProcessApplicationResolutionValue {
    guard let executablePath = process.executablePath else {
      return ProcessApplicationResolutionValue(
        processID: process.pid,
        state: process.accessibility == .inaccessible ? .inaccessible : .unmatched
      )
    }
    for strategy in strategies {
      let matchedApplications = applications.filter {
        matches(
          executablePath: executablePath,
          application: $0.value,
          strategy: strategy.kind
        )
      }.map(\.value.path).sorted()
      guard !matchedApplications.isEmpty else { continue }
      return ProcessApplicationResolutionValue(
        processID: process.pid,
        state: matchedApplications.count == 1 ? .matched : .ambiguous,
        applicationPaths: matchedApplications,
        strategyID: strategy.id,
        confidence: matchedApplications.count == 1 ? strategy.confidence : .ambiguous
      )
    }
    return ProcessApplicationResolutionValue(processID: process.pid, state: .unmatched)
  }

  private func matches(
    executablePath: String,
    application: ApplicationBundleValue,
    strategy: ProcessResolutionStrategy.Kind
  ) -> Bool {
    switch strategy {
    case .exactMainExecutable:
      guard let executableName = application.executableName else { return false }
      return executablePath
        == URL(fileURLWithPath: application.path)
        .appending(path: "Contents/MacOS/\(executableName)").path
    case .containedInApplicationBundle:
      return executablePath.hasPrefix(
        URL(fileURLWithPath: application.path).standardizedFileURL.path + "/"
      )
    }
  }
}
