import Foundation
import HALCollectors
import Testing

@Suite("Rebuildable-data detector configuration")
struct RebuildableDataConfigurationTests {
  @Test("Bundled detectors are schema validated, bounded, and evidence bearing")
  func bundledConfiguration() throws {
    let configuration = try RebuildableDataConfiguration.bundled()
    let home = URL(filePath: "/Users/example", directoryHint: .isDirectory)

    #expect(configuration.schemaVersion == 3)
    #expect(configuration.measurementPolicy.maxEntriesPerLocation == 250_000)
    #expect(configuration.measurementPolicy.maxDurationMilliseconds == 5_000)
    #expect(configuration.measurementPolicy.stayOnFileSystem)
    #expect(configuration.measurementPolicy.symbolicLinkPolicy == .doNotFollow)
    #expect(
      configuration.measurementPolicy.hardLinkPolicy == .countAllocatedBytesOncePerFileID
    )
    #expect(configuration.measurementPolicy.clonePolicy == .allocatedBytesMayOverlap)
    #expect(
      configuration.detectors.map(\.id) == [
        "xcode-derived-data", "homebrew-download-cache", "npm-download-cache",
      ])
    #expect(configuration.detectors.allSatisfy { !$0.locations.isEmpty })
    #expect(configuration.detectors.allSatisfy { !$0.evidenceRule.explanation.isEmpty })
    #expect(
      try configuration.detectors.flatMap { try $0.resolvedLocations(userHome: home) }
        .allSatisfy { $0.path.hasPrefix("/Users/example/") })
  }

  @Test("Unknown classifications and unsafe paths fail with explicit diagnostics")
  func semanticValidation() throws {
    let schema = try RebuildableDataConfiguration.declarativeSchemaData()
    let unknownClassification = Data(
      """
      {
        "schemaVersion": 3,
        "measurementPolicy": {
          "maxEntriesPerLocation": 250000,
          "maxDepth": 64,
          "maxDurationMilliseconds": 5000,
          "cancellationCheckIntervalEntries": 256,
          "stayOnFileSystem": true,
          "symbolicLinkPolicy": "doNotFollow",
          "hardLinkPolicy": "countAllocatedBytesOncePerFileID",
          "clonePolicy": "allocatedBytesMayOverlap"
        },
        "classifications": [{
          "id": "cache",
          "label": "Cache",
          "rebuildability": "rebuildable"
        }],
        "detectors": [{
          "id": "bad",
          "classificationID": "missing",
          "locations": [{ "id": "bad-path", "path": "$USER_HOME/../Secret" }],
          "excludedDescendantNames": [],
          "manager": null,
          "evidenceRule": {
            "id": "rule",
            "kind": "pathConvention",
            "confidence": "possible",
            "explanation": "Test"
          }
        }]
      }
      """.utf8
    )

    #expect(throws: RebuildableDataConfigurationError.self) {
      try RebuildableDataConfiguration.decode(unknownClassification, schema: schema)
    }

    let unsafePath = Data(
      try #require(String(data: unknownClassification, encoding: .utf8))
        .replacingOccurrences(of: "\"missing\"", with: "\"cache\"").utf8
    )
    #expect(throws: RebuildableDataConfigurationError.invalidPath("bad-path")) {
      try RebuildableDataConfiguration.decode(unsafePath, schema: schema)
    }
  }

  @Test("Unknown manifest fields fail declarative validation")
  func unknownFields() throws {
    let data = Data(
      """
      {
        "schemaVersion": 3,
        "classifications": [],
        "detectors": [],
        "allowDeletion": true
      }
      """.utf8
    )

    #expect(throws: RebuildableDataConfigurationError.self) {
      try RebuildableDataConfiguration.decode(
        data,
        schema: RebuildableDataConfiguration.declarativeSchemaData()
      )
    }
  }

  @Test("Measurement budgets and filesystem boundaries cannot be disabled")
  func unsafeMeasurementPolicy() throws {
    let configuration = RebuildableDataConfiguration(
      measurementPolicy: RebuildableDataMeasurementPolicy(
        maxEntriesPerLocation: 250_000,
        maxDepth: 64,
        maxDurationMilliseconds: 0,
        cancellationCheckIntervalEntries: 256,
        stayOnFileSystem: false,
        symbolicLinkPolicy: .doNotFollow,
        hardLinkPolicy: .countAllocatedBytesOncePerFileID,
        clonePolicy: .allocatedBytesMayOverlap
      ),
      classifications: [
        RebuildableDataClassification(
          id: "cache",
          label: "Cache",
          rebuildability: .rebuildable
        )
      ],
      detectors: [
        RebuildableDataDetector(
          id: "cache",
          classificationID: "cache",
          locations: [
            RebuildableDataLocation(id: "cache", path: "$USER_HOME/Library/Caches/Test")
          ],
          excludedDescendantNames: [],
          evidenceRule: RebuildableDataEvidenceRule(
            id: "rule",
            kind: .pathConvention,
            confidence: .possible,
            explanation: "Test"
          )
        )
      ]
    )

    #expect(throws: RebuildableDataConfigurationError.self) {
      try RebuildableDataConfiguration.decode(
        JSONEncoder().encode(configuration),
        schema: RebuildableDataConfiguration.declarativeSchemaData()
      )
    }
  }
}
