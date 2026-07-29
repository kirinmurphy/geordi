import Foundation
import HALCollectors
import HALDomain
import Testing

@Suite("Application classification configuration")
struct ApplicationClassificationConfigurationTests {
  @Test("Bundled categories classify nested system paths before broad locations")
  func bundledCategoriesClassifyPaths() throws {
    let configuration = try ApplicationClassificationConfiguration.bundled()
    let home = URL(filePath: "/Users/example", directoryHint: .isDirectory)

    #expect(configuration.defaultCategoryID == "user-installed")
    #expect(
      configuration.category(
        forApplicationPath: "/Applications/Firefox.app",
        platformBinary: false,
        userHome: home
      ).id
        == "user-installed"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/System/Applications/Utilities/Terminal.app",
        platformBinary: true,
        userHome: home
      ).id == "system-utilities"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/System/Applications/Calendar.app",
        platformBinary: true,
        userHome: home
      ).id == "bundled-software"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Users/example/Applications/Local.app",
        platformBinary: false,
        userHome: home
      ).id == "user-installed"
    )
    #expect(
      configuration.category(forApplicationPath: "/opt/Other.app", userHome: home).id == "other"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/System/Applications/Calendar.app",
        platformBinary: false,
        userHome: home
      ).id == "bundled-software"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Applications/Platform.app",
        platformBinary: true,
        userHome: home
      ).id == "other"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Applications/Store.app",
        platformBinary: false,
        details: [Detail("App Store receipt", "Present")],
        userHome: home
      ).id == "user-installed"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Applications/StorePlatform.app",
        platformBinary: true,
        details: [Detail("App Store receipt", "Present")],
        userHome: home
      ).id == "other"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Applications/Brew.app",
        platformBinary: false,
        details: [Detail("Installed with", "Homebrew cask brew")],
        userHome: home
      ).id == "user-installed"
    )
    #expect(
      configuration.source(
        forApplicationPath: "/Applications/Store.app",
        platformBinary: false,
        details: [Detail("App Store receipt", "Present")],
        userHome: home
      )?.id == "app-store"
    )
    #expect(
      configuration.source(
        forApplicationPath: "/Applications/Brew.app",
        platformBinary: false,
        details: [Detail("Installed with", "Homebrew cask brew")],
        userHome: home
      )?.id == "homebrew-cask"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Applications/Keynote.app",
        platformBinary: false,
        details: [
          Detail("Bundle identifier", "com.apple.Keynote"),
          Detail("App Store receipt", "Present"),
          Detail("Installation timing", "Present at setup"),
        ],
        userHome: home
      ).id == "bundled-software"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Applications/Pages.app",
        platformBinary: false,
        details: [
          Detail("App Store receipt", "Present"),
          Detail("Installation timing", "Added after setup"),
        ],
        userHome: home
      ).id == "user-installed"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Applications/Warp.app",
        platformBinary: false,
        details: [
          Detail("Installation timing", "Present at setup"),
          Detail("Installed with", "Homebrew cask warp"),
        ],
        userHome: home
      ).id == "user-installed"
    )
    #expect(
      configuration.category(
        forApplicationPath: "/Applications/Unknown.app",
        platformBinary: false,
        details: [Detail("Installation timing", "Unknown")],
        userHome: home
      ).id == "installation-timing-unknown"
    )
  }

  @Test("Classification schema rejects unknown fields")
  func unknownFieldIsRejected() throws {
    let data = Data(
      """
      {
        "schemaVersion": 6,
        "allApplicationsLabel": "All",
        "defaultCategoryID": "other",
        "categories": [{
          "id": "other",
          "kind": "scope",
          "label": "Other",
          "summary": "Fallback",
          "priority": 0,
          "isFallback": true,
          "platformBinaryWhenKnown": null,
          "pathPrefixes": [],
          "detailRules": [],
          "showsInSoftwareSources": false,
          "matchMode": "all",
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
        "schemaVersion": 6,
        "allApplicationsLabel": "All",
        "defaultCategoryID": "apps",
        "categories": [{
          "id": "apps",
          "kind": "scope",
          "label": "Apps",
          "summary": "Apps",
          "priority": 1,
          "isFallback": false,
          "platformBinaryWhenKnown": false,
          "pathPrefixes": [{ "path": "/Applications", "scope": "system" }],
          "detailRules": [],
          "showsInSoftwareSources": false,
          "matchMode": "all"
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

  @Test("Version-one classification policy is rejected")
  func olderVersionIsRejected() throws {
    let data = Data(
      """
      {
        "schemaVersion": 1,
        "allApplicationsLabel": "All",
        "defaultCategoryID": "other",
        "categories": []
      }
      """.utf8
    )

    #expect(throws: ApplicationClassificationConfigurationError.self) {
      try ApplicationClassificationConfiguration.decode(
        data,
        schema: ApplicationClassificationConfiguration.declarativeSchemaData()
      )
    }
  }
}
