import Foundation
import HALCollectors
import Testing

@Suite("Process collector configuration")
struct ProcessCollectorConfigurationTests {
  @Test("Bundled resolution strategies are declarative and ordered by priority")
  func bundledConfiguration() throws {
    let configuration = try ProcessCollectorConfiguration.bundled()
    #expect(configuration.schemaVersion == 1)
    #expect(
      configuration.strategies.map(\.kind) == [
        .exactMainExecutable,
        .containedInApplicationBundle,
      ])
    #expect(configuration.strategies[0].priority > configuration.strategies[1].priority)
  }

  @Test("Unknown fields fail declarative validation")
  func rejectsUnknownFields() throws {
    let data = Data(
      """
      {
        "schemaVersion": 1,
        "strategies": [{
          "id": "exact",
          "kind": "exactMainExecutable",
          "confidence": "confirmed",
          "priority": 100,
          "unexpected": true
        }]
      }
      """.utf8
    )

    #expect(throws: ProcessCollectorConfigurationError.self) {
      try ProcessCollectorConfiguration.decode(
        data,
        schema: ProcessCollectorConfiguration.declarativeSchemaData()
      )
    }
  }
}
