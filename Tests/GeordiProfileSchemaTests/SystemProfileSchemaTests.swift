import Foundation
import GeordiDomain
import GeordiProfileSchema
import Testing

@Suite("System profile schema")
struct SystemProfileSchemaTests {
  @Test("Canonical export is deterministic, sorted, and round trips")
  func deterministicExport() throws {
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "export", name: "Export", summary: "Export"),
      entities: [
        Entity(id: "z", type: .file, name: "Z", summary: "Z"),
        Entity(
          id: "a",
          type: .application,
          name: "A",
          summary: "A",
          details: [Detail("Z detail", "2"), Detail("A detail", "1")],
          instances: [
            EntityInstance(id: "Instance 1", details: [Detail("PID", "42")])
          ]
        ),
      ],
      relationships: [
        Relationship(
          id: "edge",
          source: "a",
          target: "z",
          type: .mayBelongTo,
          confidence: .possible,
          explanation: "Possible",
          evidence: [
            Evidence(id: "z-evidence", kind: .inferred, summary: "Z", source: "Test"),
            Evidence(id: "a-evidence", kind: .observed, summary: "A", source: "Test"),
          ]
        )
      ]
    )

    let first = try SystemProfileSchema.encode(graph)
    let second = try SystemProfileSchema.encode(graph)
    #expect(first == second)
    #expect(first.last == 0x0A)
    let decoded = try SystemProfileSchema.decode(first).graph()
    #expect(decoded.metadata.version == SystemProfileSchema.currentVersion)
    #expect(decoded.metadata.id == graph.metadata.id)
    #expect(decoded.entities.map(\.id) == ["a", "z"])
    #expect(decoded.entity("a")?.instances.first?.details == [Detail("PID", "42")])
    #expect(decoded.relationships.map(\.id) == ["edge"])

    let text = try #require(String(data: first, encoding: .utf8))
    let a = try #require(text.range(of: "\"id\" : \"a\""))
    let z = try #require(text.range(of: "\"id\" : \"z\""))
    let aEvidence = try #require(text.range(of: "\"id\" : \"a-evidence\""))
    let zEvidence = try #require(text.range(of: "\"id\" : \"z-evidence\""))
    #expect(a.lowerBound < z.lowerBound)
    #expect(aEvidence.lowerBound < zEvidence.lowerBound)
  }

  @Test("Strict decoding rejects unknown fields with a field path")
  func unknownField() {
    let data = Data(
      """
      {
        "schemaVersion": 3,
        "id": "profile",
        "name": "Profile",
        "summary": "Summary",
        "entities": [],
        "relationships": [],
        "unexpected": true
      }
      """.utf8
    )

    #expect(throws: (any Error).self) {
      try SystemProfileSchema.decode(data)
    }
  }

  @Test("Schema rejects unsupported versions")
  func unsupportedVersion() {
    let data = Data(
      """
      {
        "schemaVersion": 1,
        "id": "profile",
        "name": "Profile",
        "summary": "Summary",
        "entities": [],
        "relationships": []
      }
      """.utf8
    )

    #expect(throws: (any Error).self) {
      try SystemProfileSchema.decode(data)
    }
  }

  @Test("Declarative enum values remain in parity with Swift domain enums")
  func enumParity() throws {
    let schemaObject = try #require(
      try JSONSerialization.jsonObject(
        with: SystemProfileSchema.declarativeSchemaData()
      ) as? [String: Any]
    )
    let definitions = try #require(schemaObject["$defs"] as? [String: Any])

    #expect(
      try schemaEnum("entityType", in: definitions)
        == Set(EntityType.allCases.map(\.rawValue))
    )
    #expect(
      try schemaEnum("relationshipType", in: definitions)
        == Set(RelationshipType.allCases.map(\.rawValue))
    )
    #expect(
      try schemaEnum("confidence", in: definitions)
        == Set(Confidence.allCases.map(\.rawValue))
    )
    #expect(
      try schemaEnum("evidenceKind", in: definitions)
        == Set(EvidenceKind.allCases.map(\.rawValue))
    )
    #expect(
      try schemaEnum("presentationTint", in: definitions)
        == Set(EntityPresentationTint.allCases.map(\.rawValue))
    )
  }

  @Test("Schema enforces relationship endpoints and evidence")
  func relationshipIntegrity() throws {
    let data = Data(
      """
      {
        "schemaVersion": 3,
        "id": "profile",
        "name": "Profile",
        "summary": "Summary",
        "entities": [
          {
            "id": "app",
            "type": "application",
            "name": "App",
            "summary": "App",
            "details": []
          }
        ],
        "relationships": [
          {
            "id": "edge",
            "source": "app",
            "target": "missing",
            "type": "launches",
            "confidence": "possible",
            "explanation": "Test",
            "evidence": [
              {
                "id": "evidence",
                "kind": "inferred",
                "summary": "Test",
                "source": "Test"
              }
            ]
          }
        ]
      }
      """.utf8
    )

    #expect(
      throws: SystemProfileSchemaError.missingEndpoint(
        relationship: "edge",
        endpoint: "missing"
      )
    ) {
      try SystemProfileSchema.decode(data)
    }
  }

  private func schemaEnum(
    _ name: String,
    in definitions: [String: Any]
  ) throws -> Set<String> {
    let definition = try #require(definitions[name] as? [String: Any])
    let values = try #require(definition["enum"] as? [String])
    return Set(values)
  }
}
