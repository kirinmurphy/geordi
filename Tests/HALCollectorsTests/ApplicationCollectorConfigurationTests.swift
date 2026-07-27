import Foundation
import HALCollectors
import Testing

@Suite("Application collector configuration")
struct ApplicationCollectorConfigurationTests {
  @Test("Bundled roots are declarative, versioned, and safely resolved")
  func bundledRootsResolve() throws {
    let configuration = try ApplicationCollectorConfiguration.bundled()
    let userHome = URL(filePath: "/Users/example", directoryHint: .isDirectory)
    let roots = try configuration.searchRoots(userHome: userHome)

    #expect(configuration.schemaVersion == 1)
    #expect(
      roots.map(\.url.path) == [
        "/Applications",
        "/System/Applications",
        "/Users/example/Applications",
      ])
    #expect(roots.map(\.required) == [true, false, false])
  }

  @Test("Declarative schema rejects unknown collector configuration")
  func unknownFieldIsRejected() throws {
    let data = Data(
      """
      {
        "schemaVersion": 1,
        "roots": [{
          "id": "applications",
          "path": "/Applications",
          "required": true,
          "scope": "system",
          "recursive": true
        }]
      }
      """.utf8
    )

    #expect(throws: Error.self) {
      try ApplicationCollectorConfiguration.decode(
        data,
        schema: ApplicationCollectorConfiguration.declarativeSchemaData()
      )
    }
  }

  @Test("User paths cannot escape the configured home directory")
  func userPathCannotEscapeHome() {
    let configuration = ApplicationCollectorConfiguration(
      roots: [
        ApplicationSearchRootConfiguration(
          id: "unsafe",
          path: "$USER_HOME/../Shared",
          required: false,
          scope: .user
        )
      ]
    )

    #expect(
      throws: ApplicationCollectorConfigurationError.invalidPath("unsafe")
    ) {
      try configuration.searchRoots(
        userHome: URL(filePath: "/Users/example", directoryHint: .isDirectory)
      )
    }
  }
}
