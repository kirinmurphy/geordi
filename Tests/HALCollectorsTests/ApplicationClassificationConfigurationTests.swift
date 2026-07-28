import Foundation
import HALCollectors
import Testing

@Suite("Application classification configuration")
struct ApplicationClassificationConfigurationTests {
  @Test("Bundled categories classify nested system paths before broad locations")
  func bundledCategoriesClassifyPaths() throws {
    let configuration = try ApplicationClassificationConfiguration.bundled()
    let home = URL(filePath: "/Users/example", directoryHint: .isDirectory)

    #expect(configuration.defaultCategoryID == "user-installed")
    #expect(
      configuration.category(forApplicationPath: "/Applications/Firefox.app", userHome: home).id
        == "user-installed"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/System/Applications/Utilities/Terminal.app",
        userHome: home
      ).id == "system-utilities"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/System/Applications/Calendar.app",
        userHome: home
      ).id == "bundled-software"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Users/example/Applications/Local.app",
        userHome: home
      ).id == "user-installed"
    )
    #expect(
      configuration.category(forApplicationPath: "/opt/Other.app", userHome: home).id == "other"
    )
  }

  @Test("Classification schema rejects unknown fields")
  func unknownFieldIsRejected() throws {
    let data = Data(
      """
      {
        "schemaVersion": 1,
        "allApplicationsLabel": "All",
        "defaultCategoryID": "other",
        "categories": [{
          "id": "other",
          "label": "Other",
          "summary": "Fallback",
          "priority": 0,
          "isFallback": true,
          "pathPrefixes": [],
          "color": "gray"
        }]
      }
      """.utf8
    )

    #expect(throws: Error.self) {
      try ApplicationClassificationConfiguration.decode(
        data,
        schema: ApplicationClassificationConfiguration.declarativeSchemaData()
      )
    }
  }

  @Test("Classification requires exactly one fallback and a known default")
  func semanticRulesAreValidated() throws {
    let schema = try ApplicationClassificationConfiguration.declarativeSchemaData()
    let missingFallback = Data(
      """
      {
        "schemaVersion": 1,
        "allApplicationsLabel": "All",
        "defaultCategoryID": "apps",
        "categories": [{
          "id": "apps",
          "label": "Apps",
          "summary": "Apps",
          "priority": 1,
          "isFallback": false,
          "pathPrefixes": [{ "path": "/Applications", "scope": "system" }]
        }]
      }
      """.utf8
    )

    #expect(
      throws: ApplicationClassificationConfigurationError.invalidFallbackCount
    ) {
      try ApplicationClassificationConfiguration.decode(missingFallback, schema: schema)
    }
  }
}
