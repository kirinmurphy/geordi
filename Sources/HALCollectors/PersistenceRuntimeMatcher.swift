import Foundation
import HALDomain

public struct PersistenceRuntimeMatcher: Sendable {
  public static let id: CollectorID = "persistence-runtime-correlation"
  public static let version = 1

  private let configuration: PersistenceRuntimeMatchingConfiguration
  private let clock: any HALClock

  public init(
    configuration: PersistenceRuntimeMatchingConfiguration,
    clock: any HALClock = SystemClock()
  ) {
    self.configuration = configuration
    self.clock = clock
  }

  public func match(
    scanID: ScanID,
    declarations: CollectorOutput<PersistenceDeclarationValue>,
    processes: CollectorOutput<ProcessValue>
  ) -> CollectorOutput<PersistenceRuntimeCorrelationValue> {
    let startedAt = clock.now()
    let observations = declarations.observations.sorted {
      $0.value.declarationPath < $1.value.declarationPath
    }.map { declaration in
      let value = correlation(for: declaration.value, processes: processes)
      return CollectedObservation(
        id: ObservationID(
          "persistence-runtime:\(scanID.rawValue):\(declaration.id.rawValue)"
        ),
        scanID: scanID,
        collectorID: Self.id,
        schemaVersion: Self.version,
        observedAt: startedAt,
        subject: declaration.subject,
        sensitivity: declaration.sensitivity,
        sourceReference: declaration.sourceReference,
        value: value
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
        scope: configuration.strategies.sorted { $0.priority > $1.priority }.map(\.id),
        issues: processes.run.issues
      ),
      observations: observations
    )
  }

  private func correlation(
    for declaration: PersistenceDeclarationValue,
    processes: CollectorOutput<ProcessValue>
  ) -> PersistenceRuntimeCorrelationValue {
    switch processes.run.availability {
    case .permissionDenied:
      return result(declaration, state: .permissionDenied)
    case .unavailable, .unsupported:
      return result(declaration, state: .unavailable)
    case .available:
      break
    }
    guard processes.run.state == .complete else {
      return result(declaration, state: .partial)
    }
    guard let programPath = declaration.programPath else {
      return result(declaration, state: .ambiguous, confidence: .ambiguous)
    }

    for strategy in configuration.strategies.sorted(by: strategyOrder) {
      guard strategy.applicableKinds.contains(declaration.kind) else { continue }
      // Security invariant: only retained executable identities may be compared,
      // and only byte-for-byte equality is supported.
      guard
        strategy.declarationIdentityField == "programPath",
        strategy.processIdentityField == "executablePath",
        strategy.comparison == "exact"
      else { continue }
      let matches = processes.observations.filter {
        $0.value.executablePath == programPath
      }.map(\.value.pid).sorted()
      guard !matches.isEmpty else { continue }
      guard matches.count <= configuration.maximumMatchesPerDeclaration else {
        return result(declaration, state: .ambiguous, confidence: .ambiguous)
      }
      return PersistenceRuntimeCorrelationValue(
        declarationPath: declaration.declarationPath,
        processIDs: matches,
        state: .matched,
        strategyID: strategy.id,
        confidence: strategy.confidence
      )
    }
    return result(declaration, state: .unmatched)
  }

  private func result(
    _ declaration: PersistenceDeclarationValue,
    state: PersistenceRuntimeCorrelationState,
    confidence: Confidence? = nil
  ) -> PersistenceRuntimeCorrelationValue {
    PersistenceRuntimeCorrelationValue(
      declarationPath: declaration.declarationPath,
      state: state,
      confidence: confidence
    )
  }

  private func strategyOrder(
    _ lhs: PersistenceRuntimeMatchingStrategy,
    _ rhs: PersistenceRuntimeMatchingStrategy
  ) -> Bool {
    lhs.priority == rhs.priority ? lhs.id < rhs.id : lhs.priority > rhs.priority
  }
}
