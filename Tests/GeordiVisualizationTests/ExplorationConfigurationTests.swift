import Foundation
import GeordiDomain
import GeordiFixtures
import GeordiVisualization
import Testing

@Suite("Exploration configuration")
struct ExplorationConfigurationTests {
  @Test("Reference concepts and entity mappings are manifest driven")
  func referenceCatalog() throws {
    let catalog = try ReferenceCatalogConfiguration.bundled()
    #expect(catalog.item(for: .application)?.id == "software")
    #expect(catalog.item(for: .process)?.id == "runtime")
    #expect(catalog.item(for: .packageManager)?.id == "source")
  }

  @Test("Exploration contexts are schema validated and cover every home question")
  func explorationContexts() throws {
    let configuration = try ExplorationContextConfiguration.bundled()
    #expect(
      Set(configuration.contexts.map(\.id))
        == Set(["applications", "startup", "storage", "command-line", "shell-path", "filesystem"])
    )
    #expect(configuration.context("applications")?.presentation == .applicationBrowser)
    #expect(configuration.context("startup")?.drillIn == .boundedRelationships)

    let invalidUnknownKey = """
      {"schemaVersion":1,"contexts":[],"unexpected":true}
      """.data(using: .utf8)!
    #expect(throws: ExplorationContextError.self) {
      try ExplorationContextConfiguration.decode(
        invalidUnknownKey,
        schema: try resource("exploration-contexts.schema")
      )
    }

    let invalidEnum = """
      {"schemaVersion":1,"contexts":[{"id":"bad","question":"Bad","title":"Bad","presentation":"everythingGraph","supportedEntityTypes":["application"],"supportedRelationshipTypes":[],"sections":[],"drillIn":"none","initialItemBudget":1,"emptyTitle":"Empty","emptyMessage":"Empty"}]}
      """.data(using: .utf8)!
    #expect(throws: ExplorationContextError.self) {
      try ExplorationContextConfiguration.decode(
        invalidEnum,
        schema: try resource("exploration-contexts.schema")
      )
    }
  }

  @Test("Exploration presentation is stable across shuffled observations")
  func deterministicExploration() throws {
    let configuration = try ExplorationContextConfiguration.bundled()
    let context = try #require(configuration.context("startup"))
    let graph = FixtureCatalog.familiarMac
    let shuffled = SystemGraph(
      metadata: graph.metadata,
      entities: Array(graph.entities.reversed()),
      relationships: Array(graph.relationships.reversed())
    )
    let presenter = ExplorationPresenter()
    let first = presenter.present(graph: graph, context: context)
    let second = presenter.present(graph: shuffled, context: context)
    #expect(first == second)
    #expect(first.sections.flatMap(\.groups).allSatisfy { $0.id.hasPrefix("exploration-group:") })
    #expect(
      first.sections.flatMap(\.groups).flatMap(\.entityIDs).allSatisfy {
        graph.entity($0) != nil
      })
    #expect(
      Set(
        first.sections.first { $0.id == "launch-agents" }?
          .groups.flatMap(\.entityIDs) ?? []
      ) == Set(["persistence.chatgpt", "persistence.docker"])
    )
    #expect(first.unassignedEntityIDs.isEmpty)

    let atlas = presenter.present(graph: FixtureCatalog.atlasMac, context: context)
    #expect(
      atlas.sections.first { $0.id == "launch-daemons" }?
        .groups.flatMap(\.entityIDs) == ["persistence.cutline"]
    )
  }

  @Test("Exploration empty and unresolved states preserve entity IDs")
  func explorationStates() throws {
    let context = try #require(
      try ExplorationContextConfiguration.bundled().context("startup")
    )
    let unresolved = Entity(
      id: "persistence.unresolved",
      type: .persistence,
      name: "Unknown helper",
      summary: "No owner"
    )
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "states", name: "States", summary: "States"),
      entities: [unresolved],
      relationships: []
    )
    let result = ExplorationPresenter().present(graph: graph, context: context)
    #expect(
      result.sections.first { $0.id == "unresolved-declarations" }?
        .groups.flatMap(\.entityIDs) == [unresolved.id]
    )
    #expect(
      ExplorationPresenter().present(
        graph: SystemGraph(
          metadata: graph.metadata,
          entities: [],
          relationships: []
        ),
        context: context
      ).sections.allSatisfy { $0.groups.isEmpty }
    )
  }

  @Test("Glossary is schema validated and aliases are exact")
  func glossary() throws {
    let glossary = try Glossary.bundled()
    #expect(glossary.hoverDelayMilliseconds == 700)
    #expect(glossary.term(matchingExactAlias: "PID")?.id == "pid")
    #expect(glossary.term(matchingExactAlias: "Bundle identifier")?.id == "bundle-identifier")
    #expect(glossary.term(matchingExactAlias: "Application bundles")?.id == "application-bundle")
    #expect(glossary.term(matchingExactAlias: "process id") == nil)
    #expect(
      glossary.tokens(
        in: "A bundle installer can add an application bundle.",
        context: "overview"
      ).contains {
        if case .term(_, let term) = $0 { return term.id == "bundle-installer" }
        return false
      }
    )

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

  @Test("Terminal availability uses declared identity and capability")
  func terminalAvailability() throws {
    let configuration = try TerminalAdapterConfiguration.bundled()
    let available = TerminalAvailabilityResolver().availableAdapters(
      configuration: configuration,
      installedApplications: [
        InstalledTerminalApplication(
          bundleIdentifier: "dev.warp.Warp-Stable",
          declaredURLSchemes: ["warp"]
        ),
        InstalledTerminalApplication(bundleIdentifier: "com.cmuxterm.app"),
        InstalledTerminalApplication(bundleIdentifier: "unsupported.terminal"),
      ],
      runningBundleIdentifiers: ["com.cmuxterm.app"],
      activationOrder: ["com.cmuxterm.app"],
      preferredBundleIdentifier: "dev.warp.Warp-Stable"
    )

    #expect(available.map(\.adapter.id) == ["cmux", "warp"])
    #expect(available.first?.isRunning == true)
    #expect(available.last?.isPreferred == true)
  }

  @Test("Recent activation ranks running terminals deterministically")
  func activationRanking() throws {
    let configuration = try TerminalAdapterConfiguration.bundled()
    let installed = [
      InstalledTerminalApplication(bundleIdentifier: "com.apple.Terminal"),
      InstalledTerminalApplication(bundleIdentifier: "com.cmuxterm.app"),
    ]
    let available = TerminalAvailabilityResolver().availableAdapters(
      configuration: configuration,
      installedApplications: installed,
      runningBundleIdentifiers: ["com.apple.Terminal", "com.cmuxterm.app"],
      activationOrder: ["com.cmuxterm.app", "com.apple.Terminal"],
      preferredBundleIdentifier: nil
    )
    #expect(available.map(\.adapter.id) == ["cmux", "apple-terminal"])
  }

  @Test("Missing declared URL scheme makes a reviewed strategy unavailable")
  func unavailableStrategy() throws {
    let configuration = try TerminalAdapterConfiguration.bundled()
    let available = TerminalAvailabilityResolver().availableAdapters(
      configuration: configuration,
      installedApplications: [
        InstalledTerminalApplication(bundleIdentifier: "dev.warp.Warp-Stable")
      ],
      runningBundleIdentifiers: [],
      activationOrder: [],
      preferredBundleIdentifier: nil
    )
    #expect(available.isEmpty)
  }

  @Test("Terminal path targets distinguish files, directories, and unsafe input")
  func terminalPathTargets() {
    #expect(
      TerminalPathTarget.directoryPath(
        for: "/Users/example/project",
        exists: true,
        isDirectory: true
      ) == "/Users/example/project"
    )
    #expect(
      TerminalPathTarget.directoryPath(
        for: "/Users/example/project/file.txt",
        exists: true,
        isDirectory: false
      ) == "/Users/example/project"
    )
    #expect(
      TerminalPathTarget.directoryPath(
        for: "relative/file.txt",
        exists: true,
        isDirectory: false
      ) == nil
    )
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

  @Test("Guided proof is schema validated and has a stable story target")
  func guidedProof() throws {
    let configuration = try GuidedProofConfiguration.bundled()
    #expect(configuration.storyEntityID == "app.vscode")
    #expect(configuration.steps.count == 5)
    #expect(FixtureCatalog.familiarMac.entity(EntityID(configuration.storyEntityID)) != nil)

    let invalid = """
      {"schemaVersion":1,"title":"Tour","storyEntityID":"app","steps":[{"id":"one","title":"One","summary":"Summary","symbol":"app","takeaway":"Takeaway","unknown":true}]}
      """.data(using: .utf8)!
    #expect(throws: GuidedProofConfigurationError.self) {
      try GuidedProofConfiguration.decode(
        invalid,
        schema: try resource("guided-proof.schema")
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
        .appending(path: "Sources/GeordiVisualization/Resources/\(name).json")
    )
  }
}
