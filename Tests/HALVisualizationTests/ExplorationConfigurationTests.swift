import Foundation
import HALDomain
import HALVisualization
import Testing

@Suite("Exploration configuration")
struct ExplorationConfigurationTests {
  @Test("Glossary is schema validated and aliases are exact")
  func glossary() throws {
    let glossary = try Glossary.bundled()
    #expect(glossary.hoverDelayMilliseconds == 700)
    #expect(glossary.term(matchingExactAlias: "PID")?.id == "pid")
    #expect(glossary.term(matchingExactAlias: "process id") == nil)

    let invalid = """
      {"schemaVersion":1,"hoverDelayMilliseconds":700,"terms":[],"extra":true}
      """.data(using: .utf8)!
    let schema = try resource("glossary.schema")
    #expect(throws: GlossaryError.self) {
      try Glossary.decode(invalid, schema: schema)
    }
  }

  @Test("Terminal adapters are manifest driven and reject unknown keys")
  func terminalAdapters() throws {
    let configuration = try TerminalAdapterConfiguration.bundled()
    #expect(configuration.adapters.contains { $0.bundleIdentifier == "com.apple.Terminal" })
    let invalid = """
      {"schemaVersion":1,"adapters":[{"id":"x","displayName":"X","bundleIdentifier":"x.y","strategy":"workspace-open","command":"unsafe"}]}
      """.data(using: .utf8)!
    #expect(throws: TerminalAdapterConfigurationError.self) {
      try TerminalAdapterConfiguration.decode(
        invalid,
        schema: try resource("terminal-adapters.schema")
      )
    }
  }

  @Test("Filesystem projection is deterministic, sparse, and does not enumerate")
  func filesystemProjection() throws {
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "test", name: "Test", summary: "Test"),
      entities: [
        Entity(
          id: "app",
          type: .application,
          name: "Example",
          summary: "Example",
          details: [Detail("Path", "/Applications/Example.app")]
        )
      ],
      relationships: []
    )
    let catalog = try FilesystemLocationCatalog.bundled()
    let projector = FilesystemProjector()
    let first = projector.project(graph: graph, catalog: catalog, homeDirectory: "/Users/test")
    let second = projector.project(graph: graph, catalog: catalog, homeDirectory: "/Users/test")
    #expect(first == second)
    #expect(first.contains { $0.id == "applications" && $0.entityIDs == ["app"] })
    #expect(!first.contains { $0.id == "user-caches" })
    #expect(first.allSatisfy { $0.state == .observed || $0.state == .notEnumerated })
  }

  @Test("Filesystem catalog rejects traversal and unknown fields")
  func filesystemSafety() throws {
    let invalid = """
      {"schemaVersion":1,"locations":[{"id":"bad","pathTemplate":"/tmp/../private","displayLabel":"Bad","purpose":"Bad","sensitivity":"private","symbol":"folder","enumerationAllowed":false,"maximumDepth":0,"entryBudget":0}]}
      """.data(using: .utf8)!
    #expect(throws: FilesystemLocationError.self) {
      try FilesystemLocationCatalog.decode(
        invalid,
        schema: try resource("filesystem-locations.schema")
      )
    }
  }

  private func resource(_ name: String) throws -> Data {
    let repository = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    return try Data(
      contentsOf:
        repository
        .appending(path: "Sources/HALVisualization/Resources/\(name).json")
    )
  }
}
