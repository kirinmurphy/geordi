import Foundation
import HALDomain

public struct ApplicationGraphProjector: Sendable {
  public init() {}

  public func snapshot(
    scanID: ScanID,
    output: CollectorOutput<ApplicationBundleValue>,
    signatures: CollectorOutput<ApplicationSignatureValue>? = nil,
    provenance: CollectorOutput<ApplicationProvenanceValue>? = nil,
    associatedLocations: CollectorOutput<ApplicationAssociatedLocationValue>? = nil,
    processes: CollectorOutput<ProcessValue>? = nil,
    processResolutions: CollectorOutput<ProcessApplicationResolutionValue>? = nil,
    maxProcessesPerApplication: Int = 8
  ) -> GraphSnapshot {
    let signaturesByPath = Dictionary(
      uniqueKeysWithValues: (signatures?.observations ?? []).map {
        ($0.value.applicationPath, $0.value)
      }
    )
    let provenanceByPath = Dictionary(
      uniqueKeysWithValues: (provenance?.observations ?? []).map {
        ($0.value.applicationPath, $0.value)
      }
    )
    let applicationEntities = output.observations.map { observation in
      let value = observation.value
      return Entity(
        id: entityID(for: observation),
        type: .application,
        name: value.name,
        summary: "An application bundle observed on this Mac.",
        details: details(
          for: value,
          signature: signaturesByPath[value.path],
          provenance: provenanceByPath[value.path]
        )
      )
    }
    let applicationIDsByPath = Dictionary(
      uniqueKeysWithValues: output.observations.map {
        ($0.value.path, entityID(for: $0))
      }
    )
    let presentAssociations = preferredPresentAssociations(
      associatedLocations?.observations ?? []
    )
    let locationEntities = Dictionary(
      presentAssociations.map { association in
        let value = association.value
        return (
          locationEntityID(for: value),
          Entity(
            id: locationEntityID(for: value),
            type: .file,
            name: URL(fileURLWithPath: value.locationPath).lastPathComponent,
            summary:
              "A conventional \(value.categoryLabel.lowercased()) location observed on this Mac.",
            details: [
              Detail("Category", value.categoryLabel),
              Detail("Path", value.locationPath),
              Detail(
                "Association basis",
                value.match == .bundleIdentifier
                  ? "Exact bundle identifier" : "Application name convention"
              ),
            ]
          )
        )
      },
      uniquingKeysWith: { first, _ in first }
    ).values.sorted { $0.id.rawValue < $1.id.rawValue }
    let relationships = presentAssociations.compactMap { association -> Relationship? in
      let value = association.value
      guard let applicationID = applicationIDsByPath[value.applicationPath] else {
        return nil
      }
      let exact = value.match == .bundleIdentifier
      return Relationship(
        id: RelationshipID(
          "associated-location:\(applicationID.rawValue):\(value.locationID)"
        ),
        source: applicationID,
        target: locationEntityID(for: value),
        type: .mayBelongTo,
        confidence: exact ? .high : .possible,
        explanation:
          exact
          ? "This location uses the application's exact bundle identifier, a strong conventional association that may be stale."
          : "This location matches the application name, but HAL cannot establish exclusive ownership.",
        evidence: [
          Evidence(
            id: "\(association.id.rawValue):observed",
            kind: .observed,
            summary: "The location exists at the recorded path.",
            source: "Read-only filesystem metadata",
            observationID: association.id,
            observedAt: association.observedAt
          ),
          Evidence(
            id: "\(association.id.rawValue):match",
            kind: exact ? .derived : .inferred,
            summary:
              exact
              ? "The final path component contains the exact application bundle identifier."
              : "The final path component matches the application name.",
            source: "Associated-location manifest rule",
            observationID: association.id,
            observedAt: association.observedAt,
            ruleID: value.locationID,
            ruleVersion: ApplicationAssociatedLocationCollector.version
          ),
        ]
      )
    }
    let processesByPID = Dictionary(
      uniqueKeysWithValues: (processes?.observations ?? []).map {
        ($0.value.pid, $0)
      }
    )
    let visibleProcessResolutions = preferredProcessResolutions(
      processResolutions?.observations ?? [],
      processesByPID: processesByPID,
      limit: maxProcessesPerApplication
    )
    let processEntities = visibleProcessResolutions.compactMap { resolution -> Entity? in
      guard let process = processesByPID[resolution.value.processID] else { return nil }
      var details = [Detail("PID", "\(process.value.pid)")]
      if let parentPID = process.value.parentPID {
        details.append(Detail("Parent PID", "\(parentPID)"))
      }
      if let bytes = process.value.residentMemoryBytes {
        details.append(
          Detail(
            "Memory at observation",
            ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
          )
        )
      }
      if let path = process.value.executablePath {
        details.append(Detail("Executable", path))
      }
      return Entity(
        id: processEntityID(process.value.pid),
        type: .process,
        name: process.value.name,
        summary: "A process observed in the point-in-time snapshot.",
        details: details
      )
    }
    let processRelationships = visibleProcessResolutions.compactMap {
      resolution -> Relationship? in
      guard
        let applicationPath = resolution.value.applicationPaths.first,
        let applicationID = applicationIDsByPath[applicationPath],
        let process = processesByPID[resolution.value.processID],
        let confidence = resolution.value.confidence,
        let strategyID = resolution.value.strategyID
      else {
        return nil
      }
      return Relationship(
        id: RelationshipID("application-process:\(applicationID.rawValue):\(process.value.pid)"),
        source: applicationID,
        target: processEntityID(process.value.pid),
        type: .launches,
        confidence: confidence,
        explanation:
          confidence == .confirmed
          ? "The observed executable exactly matches the application's main executable."
          : "The observed executable is contained inside the application bundle.",
        evidence: [
          Evidence(
            id: "\(resolution.id.rawValue):process",
            kind: .observed,
            summary: "The process and executable path were present in one point-in-time snapshot.",
            source: "Read-only process snapshot",
            observationID: process.id,
            observedAt: process.observedAt
          ),
          Evidence(
            id: "\(resolution.id.rawValue):resolution",
            kind: .derived,
            summary: "The executable path matched the application using a configured strategy.",
            source: "Process-to-application resolver",
            observationID: resolution.id,
            observedAt: resolution.observedAt,
            ruleID: strategyID,
            ruleVersion: ProcessApplicationResolver.version
          ),
        ]
      )
    }
    let completedAt = [
      output.run.completedAt,
      signatures?.run.completedAt,
      provenance?.run.completedAt,
      associatedLocations?.run.completedAt,
      processes?.run.completedAt,
      processResolutions?.run.completedAt,
    ]
    .compactMap { $0 }
    .max()
    let startedAt =
      [
        output.run.startedAt,
        signatures?.run.startedAt,
        provenance?.run.startedAt,
        associatedLocations?.run.startedAt,
        processes?.run.startedAt,
        processResolutions?.run.startedAt,
      ].compactMap { $0 }.min() ?? output.run.startedAt
    var collectorRuns = [output.run]
    if let signatures {
      collectorRuns.append(signatures.run)
    }
    if let provenance {
      collectorRuns.append(provenance.run)
    }
    if let associatedLocations {
      collectorRuns.append(associatedLocations.run)
    }
    if let processes {
      collectorRuns.append(processes.run)
    }
    if let processResolutions {
      collectorRuns.append(processResolutions.run)
    }
    let graph = SystemGraph(
      metadata: FixtureMetadata(
        id: "live-applications-\(scanID.rawValue)",
        version: ApplicationBundleCollector.version,
        name: "This Mac",
        summary: "A read-only application inventory observed on this Mac."
      ),
      entities: applicationEntities + processEntities + locationEntities,
      relationships: processRelationships + relationships
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

  private func preferredProcessResolutions(
    _ resolutions: [CollectedObservation<ProcessApplicationResolutionValue>],
    processesByPID: [Int32: CollectedObservation<ProcessValue>],
    limit: Int
  ) -> [CollectedObservation<ProcessApplicationResolutionValue>] {
    Dictionary(
      grouping: resolutions.filter {
        $0.value.state == .matched && $0.value.applicationPaths.count == 1
      },
      by: { $0.value.applicationPaths[0] }
    )
    .values
    .flatMap { matches in
      matches.sorted {
        let left = processesByPID[$0.value.processID]?.value.residentMemoryBytes ?? 0
        let right = processesByPID[$1.value.processID]?.value.residentMemoryBytes ?? 0
        if left != right { return left > right }
        return $0.value.processID < $1.value.processID
      }.prefix(limit)
    }
    .sorted { $0.value.processID < $1.value.processID }
  }

  private func processEntityID(_ pid: Int32) -> EntityID {
    EntityID("process:pid:\(pid)")
  }

  private func preferredPresentAssociations(
    _ observations: [CollectedObservation<ApplicationAssociatedLocationValue>]
  ) -> [CollectedObservation<ApplicationAssociatedLocationValue>] {
    let present = observations.filter { $0.value.status == .present }
    return Dictionary(
      grouping: present,
      by: { "\($0.value.applicationPath)|\($0.value.locationPath)" }
    )
    .values
    .compactMap { candidates in
      candidates.sorted {
        matchPriority($0.value.match) > matchPriority($1.value.match)
      }.first
    }
    .sorted {
      if $0.value.applicationPath != $1.value.applicationPath {
        return $0.value.applicationPath < $1.value.applicationPath
      }
      return $0.value.locationPath < $1.value.locationPath
    }
  }

  private func matchPriority(_ match: AssociatedLocationMatch) -> Int {
    switch match {
    case .bundleIdentifier: 2
    case .applicationName: 1
    }
  }

  private func locationEntityID(
    for value: ApplicationAssociatedLocationValue
  ) -> EntityID {
    EntityID("file:associated-location:\(value.locationPath)")
  }

  private func entityID(
    for observation: CollectedObservation<ApplicationBundleValue>
  ) -> EntityID {
    let primary = observation.subject.primary
    return EntityID("application:\(primary.kind.rawValue):\(primary.value)")
  }

  private func details(
    for value: ApplicationBundleValue,
    signature: ApplicationSignatureValue?,
    provenance: ApplicationProvenanceValue?
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
    for fact in provenance?.facts ?? [] {
      details.append(
        Detail(
          fact.displayLabel,
          provenanceDescription(for: fact)
        )
      )
    }
    return details
  }

  private func provenanceDescription(for fact: ApplicationProvenanceFact) -> String {
    switch fact.status {
    case .present:
      fact.detail ?? "Present"
    case .absent:
      "Not retained"
    case .unreadable:
      "Unavailable"
    }
  }
}
