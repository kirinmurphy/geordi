import Foundation
import GeordiDomain

public enum RedactedDiagnosticExporter {
  public static func data(for snapshot: GraphSnapshot) throws -> Data {
    let redacted = snapshot.redactedForDiagnostics()
    try redacted.graph.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    var data = try encoder.encode(redacted)
    data.append(0x0A)
    return data
  }

  public static func write(_ snapshot: GraphSnapshot, to destination: URL) throws {
    try data(for: snapshot).write(to: destination, options: .atomic)
  }
}

extension GraphSnapshot {
  fileprivate func redactedForDiagnostics() -> GraphSnapshot {
    let orderedEntities = graph.entities.sorted { $0.id.rawValue < $1.id.rawValue }
    let identifiers = Dictionary(
      uniqueKeysWithValues: orderedEntities.enumerated().map { offset, entity in
        (entity.id, EntityID("\(entity.type.rawValue)-\(offset + 1)"))
      }
    )
    let entities = orderedEntities.enumerated().map { offset, entity in
      Entity(
        id: identifiers[entity.id]!,
        type: entity.type,
        name: "\(entity.type.rawValue.capitalized) \(offset + 1)",
        summary: "Redacted \(entity.type.rawValue) diagnostic record.",
        details: entity.details.compactMap(redactedDetail),
        presentation: nil
      )
    }
    let relationships = graph.relationships.sorted { $0.id.rawValue < $1.id.rawValue }
      .enumerated().compactMap { offset, relationship -> Relationship? in
        guard
          let source = identifiers[relationship.source],
          let target = identifiers[relationship.target]
        else {
          return nil
        }
        return Relationship(
          id: RelationshipID("relationship-\(offset + 1)"),
          source: source,
          target: target,
          type: relationship.type,
          confidence: relationship.confidence,
          explanation: "Redacted diagnostic relationship.",
          evidence: relationship.evidence.enumerated().map { evidenceOffset, evidence in
            Evidence(
              id: "evidence-\(offset + 1)-\(evidenceOffset + 1)",
              kind: evidence.kind,
              summary: "Redacted \(evidence.kind.rawValue) evidence.",
              source: "Redacted evidence source",
              observedAt: evidence.observedAt,
              ruleID: evidence.ruleID.map { _ in "redacted-rule" },
              ruleVersion: evidence.ruleVersion
            )
          }
        )
      }
    let runs = scan.collectorRuns.enumerated().map { runOffset, run in
      CollectorRun(
        collectorID: run.collectorID,
        collectorVersion: run.collectorVersion,
        availability: run.availability,
        state: run.state,
        startedAt: run.startedAt,
        completedAt: run.completedAt,
        scope: [],
        issues: run.issues.enumerated().map { issueOffset, issue in
          CollectionIssue(
            id: "issue-\(runOffset + 1)-\(issueOffset + 1)",
            severity: issue.severity,
            summary: "Collector reported a \(issue.severity.rawValue) issue.",
            affectedScope: nil
          )
        }
      )
    }
    return GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(
          id: "redacted-diagnostic",
          version: graph.metadata.version,
          name: "Redacted \(AppBrand.displayName) Diagnostic",
          summary: "Identifiers, names, paths, scopes, and free-form values were redacted."
        ),
        entities: entities,
        relationships: relationships
      ),
      scan: ScanContext(
        id: "redacted-scan",
        environment: scan.environment,
        startedAt: scan.startedAt,
        completedAt: scan.completedAt,
        collectorRuns: runs
      )
    )
  }

  fileprivate func redactedDetail(_ detail: Detail) -> Detail? {
    switch DetailKey(rawValue: detail.label) {
    case .build, .version:
      guard detail.value.contains(where: \.isNumber) else { return nil }
      return Detail(detail.label, detail.value.diagnosticToken)
    case .evidenceFacts:
      guard Int(detail.value) != nil else { return nil }
      return detail
    case .appStoreReceipt, .applicationResolution, .currentState, .evidenceState,
      .platformBinary, .signature:
      return Detail(detail.label, detail.value.diagnosticStatus)
    case .none, .some:
      return nil
    }
  }
}

extension String {
  fileprivate var diagnosticToken: String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".+_-"))
    guard
      count <= 32,
      unicodeScalars.allSatisfy(allowed.contains)
    else {
      return "<redacted>"
    }
    return self
  }

  fileprivate var diagnosticStatus: String {
    let allowed = [
      "Ambiguous", "Complete", "Confirmed", "Inaccessible", "Invalid", "Matched",
      "Negative", "No", "Not observed", "Partial", "Permission denied", "Possible",
      "Present", "Stale", "Unavailable", "Unmatched", "Unsigned", "Valid", "Yes",
    ]
    return allowed.contains(self) ? self : "<redacted>"
  }
}
