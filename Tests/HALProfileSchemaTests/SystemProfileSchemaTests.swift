import Foundation
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

    #expect(throws: SystemProfileSchemaError.unknownKey("$.unexpected")) {
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

    #expect(throws: SystemProfileSchemaError.unsupportedVersion(2)) {
      try SystemProfileSchema.decode(data)
    }
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
}
