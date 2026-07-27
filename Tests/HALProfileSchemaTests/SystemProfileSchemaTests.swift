import Foundation
import HALDomain
import HALProfileSchema
import Testing

@Suite("System profile schema")
struct SystemProfileSchemaTests {
  @Test("Strict decoding rejects unknown fields with a field path")
  func unknownField() {
    let data = Data(
      """
      {
        "schemaVersion": 1,
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
        "schemaVersion": 2,
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
  }

  @Test("Schema enforces relationship endpoints and evidence")
  func relationshipIntegrity() throws {
    let data = Data(
      """
      {
        "schemaVersion": 1,
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
