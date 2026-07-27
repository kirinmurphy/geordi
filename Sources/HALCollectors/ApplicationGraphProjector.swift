import Foundation
import HALDomain

public struct ApplicationGraphProjector: Sendable {
  public init() {}

  public func snapshot(
    scanID: ScanID,
    output: CollectorOutput<ApplicationBundleValue>,
    signatures: CollectorOutput<ApplicationSignatureValue>? = nil
  ) -> GraphSnapshot {
    let signaturesByPath = Dictionary(
      uniqueKeysWithValues: (signatures?.observations ?? []).map {
        ($0.value.applicationPath, $0.value)
      }
    )
    let entities = output.observations.map { observation in
      let value = observation.value
      return Entity(
        id: entityID(for: observation),
        type: .application,
        name: value.name,
        summary: "An application bundle observed on this Mac.",
        details: details(
          for: value,
          signature: signaturesByPath[value.path]
        )
      )
    }
    let completedAt = [output.run.completedAt, signatures?.run.completedAt]
      .compactMap { $0 }
      .max()
    let startedAt = min(output.run.startedAt, signatures?.run.startedAt ?? output.run.startedAt)
    var collectorRuns = [output.run]
    if let signatures {
      collectorRuns.append(signatures.run)
    }
    let graph = SystemGraph(
      metadata: FixtureMetadata(
        id: "live-applications-\(scanID.rawValue)",
        version: ApplicationBundleCollector.version,
        name: "This Mac",
        summary: "A read-only application inventory observed on this Mac."
      ),
      entities: entities,
      relationships: []
    )
    return GraphSnapshot(
      graph: graph,
      scan: ScanContext(
        id: scanID,
        environment: .liveReadOnly,
        startedAt: startedAt,
        completedAt: completedAt,
        collectorRuns: collectorRuns
      )
    )
  }

  private func entityID(
    for observation: CollectedObservation<ApplicationBundleValue>
  ) -> EntityID {
    let primary = observation.subject.primary
    return EntityID("application:\(primary.kind.rawValue):\(primary.value)")
  }

  private func details(
    for value: ApplicationBundleValue,
    signature: ApplicationSignatureValue?
  ) -> [Detail] {
    var details = [Detail("Path", value.path)]
    if let bundleIdentifier = value.bundleIdentifier {
      details.append(Detail("Bundle identifier", bundleIdentifier))
    }
    if let version = value.version {
      details.append(Detail("Version", version))
    }
    if let buildVersion = value.buildVersion {
      details.append(Detail("Build", buildVersion))
    }
    if let executableName = value.executableName {
      details.append(Detail("Executable", executableName))
    }
    if let signature {
      details.append(Detail("Signature", signature.status.rawValue.capitalized))
      if let signingIdentifier = signature.signingIdentifier {
        details.append(Detail("Signing identifier", signingIdentifier))
      }
      if let teamIdentifier = signature.teamIdentifier {
        details.append(Detail("Team identifier", teamIdentifier))
      }
      if !signature.authorities.isEmpty {
        details.append(
          Detail(
            "Signing authorities",
            signature.authorities.joined(separator: " → ")
          )
        )
      }
      if signature.platformBinary == true {
        details.append(Detail("Platform binary", "Yes"))
      }
    }
    return details
  }
}
