import Testing

@testable import HALDomain

@Suite("Domain")
struct DomainTests {
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
}
