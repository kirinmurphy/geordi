import Foundation
import HALCollectors
import Testing

@Suite("Process collector configuration")
struct ProcessCollectorConfigurationTests {
  @Test("Bundled resolution strategies are declarative and ordered by priority")
  func bundledConfiguration() throws {
    let configuration = try ProcessCollectorConfiguration.bundled()
    #expect(configuration.schemaVersion == 2)
    #expect(configuration.maxProcessesPerApplication == 8)
    #expect(configuration.maxUnmatchedProcesses == 12)
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
        "schemaVersion": 2,
        "maxProcessesPerApplication": 8,
        "maxUnmatchedProcesses": 12,
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

  @Test("Version-one process policy is rejected instead of silently gaining a budget")
  func rejectsOlderVersion() throws {
    let data = Data(
      """
      {
        "schemaVersion": 1,
        "maxProcessesPerApplication": 8,
        "strategies": [{
          "id": "exact",
          "kind": "exactMainExecutable",
          "confidence": "confirmed",
          "priority": 100
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
