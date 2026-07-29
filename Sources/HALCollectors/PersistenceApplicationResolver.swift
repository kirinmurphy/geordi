import Foundation
import HALDomain

public struct PersistenceApplicationResolver: Sendable {
  public static let id: CollectorID = "persistence-application-resolution"
  public static let version = 1

  private let clock: any HALClock

  public init(clock: any HALClock = SystemClock()) {
    self.clock = clock
  }

  public func resolve(
    scanID: ScanID,
    declarations: CollectorOutput<PersistenceDeclarationValue>,
    applications: [CollectedObservation<ApplicationBundleValue>]
  ) -> CollectorOutput<PersistenceApplicationResolutionValue> {
    let startedAt = clock.now()
    let observations = declarations.observations.map { declaration in
      CollectedObservation(
        id: ObservationID("persistence-resolution:\(declaration.value.declarationPath)"),
        scanID: scanID,
        collectorID: Self.id,
        schemaVersion: Self.version,
        observedAt: startedAt,
        subject: declaration.subject,
        sensitivity: declaration.sensitivity,
        sourceReference: declaration.sourceReference,
        value: resolution(for: declaration.value, applications: applications)
      )
    }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: declarations.run.availability,
        state: declarations.run.availability == .available ? .complete : .skipped,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: ["declared-program-path"]
      ),
      observations: observations
    )
  }

  private func resolution(
    for declaration: PersistenceDeclarationValue,
    applications: [CollectedObservation<ApplicationBundleValue>]
  ) -> PersistenceApplicationResolutionValue {
    guard let program = declaration.programPath, program.hasPrefix("/") else {
      return PersistenceApplicationResolutionValue(
        declarationPath: declaration.declarationPath,
        state: .unmatched
      )
    }
    let matches = applications.filter {
      program.hasPrefix($0.value.path + "/")
    }.map(\.value.path).sorted()
    return PersistenceApplicationResolutionValue(
      declarationPath: declaration.declarationPath,
      applicationPaths: matches,
      state: matches.isEmpty ? .unmatched : (matches.count == 1 ? .matched : .ambiguous),
      confidence: matches.count == 1 ? .high : (matches.isEmpty ? nil : .ambiguous)
    )
  }
}
