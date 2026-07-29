import Foundation
import Testing

@testable import HALDomain

@Suite("Domain")
struct DomainTests {
  private let referenceDate = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Relationship direction and evidence remain explicit")
  func relationshipDirection() {
    let relationship = Relationship(
      id: "edge",
      source: "app",
      target: "process",
      type: .launches,
      confidence: .confirmed,
      explanation: "The app launches the process.",
      evidence: [
        Evidence(id: "observation", kind: .observed, summary: "Parent record.", source: "Fixture")
      ]
    )
    #expect(relationship.source == "app")
    #expect(relationship.target == "process")
    #expect(relationship.evidence.first?.kind == .observed)
  }

  @Test("Instance partition separates shared node attributes from varying values")
  func instanceDetailPartition() {
    let partition = EntityInstancePartition(detailsByInstance: [
      (
        id: "Process 1307",
        details: [
          Detail("PID", "1307"),
          Detail("Executable", "/Applications/Dropbox.app/Contents/MacOS/Dropbox"),
          Detail("Memory at observation", "137 MB"),
        ]
      ),
      (
        id: "Process 1310",
        details: [
          Detail("PID", "1310"),
          Detail("Executable", "/Applications/Dropbox.app/Contents/MacOS/Dropbox"),
          Detail("Memory at observation", "95 MB"),
        ]
      ),
    ])

    #expect(
      partition.sharedDetails == [
        Detail("Executable", "/Applications/Dropbox.app/Contents/MacOS/Dropbox")
      ])
    #expect(partition.instances.map(\.id) == ["Process 1307", "Process 1310"])
    #expect(
      partition.instances.allSatisfy {
        $0.details.map(\.label) == [
          "PID", "Memory at observation",
        ]
      })
  }

  @Test("Configuration rejects overlapping semantic columns")
  func configurationValidation() {
    let layout = LayoutConfiguration(
      columnSpacing: 50,
      rowSpacing: 50,
      nodeWidth: 100,
      nodeHeight: 100,
      minimumScale: 1,
      maximumScale: 2
    )
    #expect(throws: ConfigurationError.overlappingLayout) {
      try layout.validate()
    }
  }

  @Test("Graph validates endpoints and human-readable labels")
  func graphValidation() {
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "invalid", name: "Invalid", summary: "Test"),
      entities: [Entity(id: "app", type: .application, name: "Application", summary: "Test")],
      relationships: [
        Relationship(
          id: "broken",
          source: "app",
          target: "missing",
          type: .owns,
          confidence: .possible,
          explanation: "Broken",
          evidence: [Evidence(id: "e", kind: .inferred, summary: "Rule", source: "Test")]
        )
      ]
    )
    #expect(throws: GraphValidationError.missingEndpoint("broken")) {
      try graph.validate()
    }
  }

  @Test("Neighborhood projection preserves context without unrelated entities")
  func neighborhoodProjection() {
    let app = Entity(id: "app", type: .application, name: "App", summary: "App")
    let process = Entity(id: "process", type: .process, name: "Process", summary: "Process")
    let file = Entity(id: "file", type: .file, name: "File", summary: "File")
    let unrelated = Entity(id: "other", type: .application, name: "Other", summary: "Other")
    let evidence = Evidence(id: "e", kind: .observed, summary: "Observed", source: "Test")
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "graph", name: "Graph", summary: "Graph"),
      entities: [app, process, file, unrelated],
      relationships: [
        Relationship(
          id: "launches", source: "app", target: "process", type: .launches,
          confidence: .confirmed, explanation: "Launches", evidence: [evidence]),
        Relationship(
          id: "writes", source: "process", target: "file", type: .readsWrites,
          confidence: .confirmed, explanation: "Writes", evidence: [evidence]),
      ]
    )
    let projection = graph.neighborhood(around: "app", depth: 2)
    #expect(Set(projection.entities.map(\.id)) == ["app", "process", "file"])
    #expect(Set(projection.relationships.map(\.id)) == ["launches", "writes"])
  }

  @Test("Typed observations preserve source, subject, time, and sensitivity")
  func typedObservation() throws {
    struct ApplicationValue: Hashable, Codable, Sendable {
      let bundleIdentifier: String
      let version: String
    }

    let observation = CollectedObservation(
      id: ObservationID("application-1"),
      scanID: ScanID("scan-1"),
      collectorID: CollectorID("applications"),
      schemaVersion: 1,
      observedAt: referenceDate,
      subject: SubjectIdentity(
        primary: IdentityClaim(
          kind: .bundleIdentifier,
          value: "com.example.Application"
        ),
        aliases: [
          IdentityClaim(kind: .canonicalPath, value: "/Applications/Example.app")
        ]
      ),
      sensitivity: .ordinary,
      sourceReference: "/Applications/Example.app/Contents/Info.plist",
      value: ApplicationValue(
        bundleIdentifier: "com.example.Application",
        version: "1.0"
      )
    )

    let encoded = try JSONEncoder().encode(observation)
    let decoded = try JSONDecoder().decode(
      CollectedObservation<ApplicationValue>.self,
      from: encoded
    )
    #expect(decoded == observation)
    #expect(decoded.subject.aliases.first?.kind == .canonicalPath)
  }

  @Test("Freshness distinguishes age, partial results, and permissions")
  func freshnessStates() {
    let policy = FreshnessPolicy(agingAfter: 120, staleAfter: 900)
    let completeRun = CollectorRun(
      collectorID: "applications",
      collectorVersion: 1,
      availability: .available,
      state: .complete,
      startedAt: referenceDate,
      completedAt: referenceDate
    )
    let scan = ScanContext(
      id: "scan",
      environment: .liveReadOnly,
      startedAt: referenceDate,
      completedAt: referenceDate,
      collectorRuns: [completeRun]
    )

    #expect(policy.state(for: scan, at: referenceDate) == .fresh)
    #expect(
      policy.state(
        for: scan,
        at: referenceDate.addingTimeInterval(180)
      ) == .aging
    )
    #expect(
      policy.state(
        for: scan,
        at: referenceDate.addingTimeInterval(1_000)
      ) == .stale
    )

    let deniedRun = CollectorRun(
      collectorID: "protected-files",
      collectorVersion: 1,
      availability: .permissionDenied,
      state: .skipped,
      startedAt: referenceDate,
      completedAt: referenceDate
    )
    let deniedScan = ScanContext(
      id: "denied",
      environment: .liveReadOnly,
      startedAt: referenceDate,
      completedAt: referenceDate,
      collectorRuns: [deniedRun]
    )
    #expect(policy.state(for: deniedScan, at: referenceDate) == .permissionDenied)
  }

  @Test("Findings retain versioned rules and observation evidence")
  func findingsRemainSeparate() {
    let evidence = Evidence(
      id: "evidence",
      kind: .derived,
      summary: "The cache exceeded the review threshold.",
      source: "Storage rule",
      observationID: "storage-observation",
      observedAt: referenceDate,
      ruleID: "large-cache",
      ruleVersion: 2
    )
    let finding = Finding(
      id: "finding",
      ruleID: "large-cache",
      ruleVersion: 2,
      detectedAt: referenceDate,
      summary: "Review a large cache.",
      relatedEntities: ["file.cache"],
      confidence: .high,
      evidence: [evidence]
    )

    #expect(finding.ruleVersion == 2)
    #expect(finding.evidence.first?.observationID == "storage-observation")
    #expect(finding.state == .active)
  }
}
