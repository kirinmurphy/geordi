import Foundation
import HALDomain
import HALFixtures
import Testing

@Suite("Synthetic fixture contracts")
struct FixtureTests {
  @Test("All required fixtures validate and have stable versions")
  func fixturesValidate() throws {
    #expect(FixtureCatalog.all.count >= 4)
    for fixture in FixtureCatalog.all {
      try fixture.validate()
      #expect(fixture.metadata.version == 2)
    }
  }

  @Test("Every committed profile manifest validates through the central schema")
  func profileManifestsValidate() throws {
    #expect(try FixtureCatalog.validateManifestProfiles() == 7)
  }

  @Test("Catalog has all required Phase 0 scenarios")
  func requiredScenarios() {
    let ids = Set(FixtureCatalog.all.map(\.metadata.id))
    #expect(
      ids.isSuperset(of: [
        "familiar-mac",
        "atlas-mac",
        "simple-application",
        "helper-rich-application",
        "resource-incident",
        "ambiguous-ownership",
        "observation-states",
      ]))
  }

  @Test("Observation-state fixture exercises incomplete and negative evidence")
  func observationStates() {
    let graph = FixtureCatalog.observationStates
    let states = Set(
      graph.entities.compactMap {
        $0.details.first { $0.label == "Evidence state" }?.value
      }
    )

    #expect(
      states == [
        "Partial", "Unavailable", "Permission denied", "Ambiguous", "Stale", "Negative",
      ])
    #expect(graph.relationships.first?.confidence == .ambiguous)
    #expect(
      graph.entity("app.negative")?.details.contains {
        $0.label == "App Store receipt" && $0.value == "Not observed"
      } == true)
  }

  @Test("Familiar Mac represents recognizable software shapes")
  func familiarSoftwareShapes() throws {
    let graph = FixtureCatalog.familiarMac
    try graph.validate()
    let expected: Set<EntityID> = [
      "app.docker", "app.vscode", "app.cmux", "app.chatgpt", "app.brave",
      "tool.homebrew", "tool.ohmyzsh", "package.typescript",
    ]
    #expect(Set(graph.entities.map(\.id)).isSuperset(of: expected))
    let applications = graph.entities.filter { $0.type == .application }
    #expect(applications.allSatisfy { $0.presentation != nil })
    #expect(graph.entity("app.docker")?.presentation?.symbol == "shippingbox.fill")
    #expect(
      graph.relationships.contains {
        $0.source == "process.docker" && $0.target == "process.vm"
      })
    #expect(
      graph.relationships.contains {
        $0.source == "tool.homebrew" && $0.target == "app.vscode"
      })
    #expect(
      graph.relationships.contains {
        $0.source == "process.cmux" && $0.target == "process.zsh"
      })
  }

  @Test("Familiar Mac is explicitly fictional")
  func familiarMacIsFictional() {
    #expect(
      FixtureCatalog.familiarMac.metadata.summary.localizedCaseInsensitiveContains("fictional"))
  }

  @Test("Inventory homepage has alert and reclaim summaries")
  func inventorySummaries() {
    let graph = FixtureCatalog.familiarMac
    #expect(graph.entity("incident.build") != nil)
    #expect(graph.entity("resource.storage") != nil)
    let reclaimSources = Set(
      graph.relationships.filter { $0.target == "resource.storage" }.map(\.source))
    #expect(reclaimSources.count == 5)
    #expect(reclaimSources.allSatisfy { graph.entity($0)?.type == .file })
  }

  @Test("Inventory lists only user-selected application examples")
  func userInstalledApplicationInventory() {
    let apps = FixtureCatalog.familiarMac.entities.filter { $0.type == .application }
    #expect(
      Set(apps.map(\.name)) == [
        "Docker Desktop", "Visual Studio Code", "cmux", "ChatGPT", "Brave Browser",
      ])
    #expect(
      apps.allSatisfy { entity in
        entity.details.contains { $0.label == "Installed with" }
      })
  }

  @Test("Category maps use bounded relevant neighborhoods")
  func boundedCategoryNeighborhoods() {
    let graph = FixtureCatalog.familiarMac
    let storage = graph.neighborhood(around: "resource.storage", depth: 2)
    let performance = graph.neighborhood(around: "incident.build", depth: 2)
    #expect(storage.entities.count < graph.entities.count)
    #expect(performance.entities.count < graph.entities.count)
    #expect(storage.entity("resource.storage") != nil)
    #expect(performance.entity("incident.build") != nil)
    #expect(!storage.entities.contains { $0.id == "file.brave-profile" })
  }

  @Test("Atlas Mac connects the three primary use cases")
  func atlasMacUseCases() throws {
    let graph = FixtureCatalog.atlasMac
    try graph.validate()
    #expect(graph.entities.filter { $0.type == .application }.count == 4)
    #expect(graph.entities.contains { $0.id == "resource.storage" })
    #expect(graph.entities.contains { $0.id == "incident.render" })
    #expect(
      graph.relationships.contains {
        $0.source == "file.cutline-cache" && $0.target == "resource.storage"
      })
    #expect(
      graph.relationships.contains {
        $0.source == "process.render" && $0.target == "resource.memory"
      })
  }

  @Test("Synthetic reclaim candidates protect user and shared data")
  func reclaimSafety() {
    let graph = FixtureCatalog.atlasMac
    let protected = ["file.cutline-projects", "file.cloudline-copy", "file.shared-media"]
    for id in protected {
      let removal = graph.entity(EntityID(id))?.details.first { $0.label == "Removal" }?.value
      #expect(removal == "Protected" || removal == "Not a cleanup candidate")
    }
  }

  @Test("Ambiguous ownership cannot be presented as confident")
  func ambiguityIsHonest() {
    let graph = FixtureCatalog.ambiguousOwnership
    let ownership = graph.relationships.filter {
      $0.type == .mayBelongTo || $0.type == .shares
    }
    #expect(!ownership.isEmpty)
    #expect(ownership.allSatisfy { $0.confidence == .ambiguous })
    #expect(
      ownership.allSatisfy {
        $0.explanation.localizedCaseInsensitiveContains("plausible")
          || $0.explanation.localizedCaseInsensitiveContains("cannot")
          || $0.explanation.localizedCaseInsensitiveContains("not exclusively")
      })
  }

  @Test("Incident uses correlation language rather than unsupported causation")
  func incidentWording() {
    let nearby = FixtureCatalog.resourceIncident.relationships.filter {
      $0.type == .occurredNear
    }
    #expect(nearby.count == 2)
    #expect(
      nearby.allSatisfy {
        !$0.explanation.localizedCaseInsensitiveContains("caused")
      })
  }

  @Test("Synthetic provider preserves deterministic scan context")
  func syntheticProviderContext() {
    let timestamp = Date(timeIntervalSince1970: 1_753_545_600)
    let provider = SyntheticGraphProvider(
      fixtureID: "simple-application",
      clock: FixedClock(timestamp)
    )

    let first = provider.snapshot()
    let second = provider.snapshot()
    #expect(first == second)
    #expect(first.graph.metadata.id == "simple-application")
    #expect(first.scan.environment == .synthetic)
    #expect(first.scan.completedAt == timestamp)
    #expect(!first.scan.isPartial)
    #expect(first.scan.collectorRuns.map(\.collectorID) == ["synthetic-fixture"])
  }
}
