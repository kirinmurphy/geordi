import Foundation
import HALCollectors
import Testing

@Suite("Persistence collector configuration")
struct PersistenceCollectorConfigurationTests {
  @Test("Bundled roots are declarative and exclude Apple system declarations")
  func bundledConfiguration() throws {
    let configuration = try PersistenceCollectorConfiguration.bundled()
    let roots = try configuration.resolvedRoots(
      userHome: URL(fileURLWithPath: "/Users/tester")
    )

    #expect(roots.count == 3)
    #expect(roots.contains { $0.url.path == "/Users/tester/Library/LaunchAgents" })
    #expect(!roots.contains { $0.url.path.hasPrefix("/System/Library") })
  }

  @Test("Unknown fields and parent traversal fail validation")
  func invalidConfiguration() throws {
    let data = Data(
      """
      {
        "schemaVersion": 1,
        "roots": [{
          "id": "unsafe",
          "path": "$USER_HOME/../LaunchAgents",
          "kind": "launchAgent",
          "scope": "user"
        }]
      }
      """.utf8
    )
    let configuration = try PersistenceCollectorConfiguration.decode(
      data,
      schema: PersistenceCollectorConfiguration.declarativeSchemaData()
    )
    #expect(throws: PersistenceCollectorConfigurationError.invalidPath("unsafe")) {
      try configuration.resolvedRoots(userHome: URL(fileURLWithPath: "/Users/tester"))
    }
  }
}
