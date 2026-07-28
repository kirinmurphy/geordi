import Foundation
import HALDataSource
import HALDomain
import Testing

@Suite("Redacted diagnostic export")
struct RedactedDiagnosticExportTests {
  @Test("Export preserves diagnostic structure without local identifiers or paths")
  func redaction() throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let privatePath = "/Users/alice/Secret Project/Private.app"
    let snapshot = GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(
          id: "live-private",
          name: "Alice's Mac",
          summary: privatePath
        ),
        entities: [
          Entity(
            id: EntityID("application:path:\(privatePath)"),
            type: .application,
            name: "Private App",
            summary: "Alice's private application",
            details: [
              Detail("Path", privatePath),
              Detail("Version", "1.2.3"),
              Detail("Signing identifier", "com.alice.private"),
            ]
          ),
          Entity(
            id: EntityID("file:\(privatePath)/Contents"),
            type: .file,
            name: "Secret Project",
            summary: privatePath
          ),
        ],
        relationships: [
          Relationship(
            id: RelationshipID("relationship:\(privatePath)"),
            source: EntityID("application:path:\(privatePath)"),
            target: EntityID("file:\(privatePath)/Contents"),
            type: .mayBelongTo,
            confidence: .possible,
            explanation: privatePath,
            evidence: [
              Evidence(
                id: privatePath,
                kind: .inferred,
                summary: privatePath,
                source: "Filesystem /Users/alice"
              )
            ]
          )
        ]
      ),
      scan: ScanContext(
        id: "live-alice",
        environment: .liveReadOnly,
        startedAt: date,
        completedAt: date,
        collectorRuns: [
          CollectorRun(
            collectorID: "test-collector",
            collectorVersion: 1,
            availability: .available,
            state: .partial,
            startedAt: date,
            completedAt: date,
            scope: [privatePath],
            issues: [
              CollectionIssue(
                id: privatePath,
                severity: .warning,
                summary: "Could not read \(privatePath)",
                affectedScope: privatePath
              )
            ]
          )
        ]
      )
    )

    let data = try RedactedDiagnosticExporter.data(for: snapshot)
    let text = try #require(String(data: data, encoding: .utf8))
    #expect(!text.contains("alice"))
    #expect(!text.contains("Secret Project"))
    #expect(!text.contains("Private App"))
    #expect(!text.contains("com.alice.private"))
    #expect(!text.contains(privatePath))
    #expect(text.contains("\"Version\""))
    #expect(text.contains("1.2.3"))

    let decoded = try JSONDecoder().decode(GraphSnapshot.self, from: data)
    try decoded.graph.validate()
    #expect(decoded.graph.entities.count == 2)
    #expect(decoded.graph.relationships.count == 1)
    #expect(decoded.scan.collectorRuns.first?.scope.isEmpty == true)
    #expect(decoded.scan.collectorRuns.first?.issues.first?.affectedScope == nil)
  }
}
