import HALDomain
import Testing

@testable import HALApp

@Suite("Application story")
struct ApplicationStoryModelTests {
  @Test("Story separates activity, startup, ownership, and associated data")
  func categorizedStory() {
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "story", name: "Story", summary: "Story"),
      entities: [
        Entity(
          id: "app",
          type: .application,
          name: "Example",
          summary: "An example application.",
          details: [
            Detail("Current state", "Running"),
            Detail("Signature", "Valid"),
            Detail("Installed with", "Homebrew cask example"),
          ]
        ),
        Entity(id: "process", type: .process, name: "Example process", summary: "Running"),
        Entity(id: "startup", type: .persistence, name: "Example helper", summary: "Startup"),
        Entity(id: "cache", type: .file, name: "Example cache", summary: "Rebuildable"),
        Entity(
          id: "manager", type: .packageManager, name: "Example Manager", summary: "Owner"),
      ],
      relationships: [
        relationship("launch", source: "app", target: "process", type: .launches),
        relationship("startup-link", source: "app", target: "startup", type: .persistsThrough),
        relationship("data", source: "app", target: "cache", type: .owns),
        relationship("owner", source: "manager", target: "app", type: .owns),
      ]
    )

    let story = ApplicationStoryModel(application: graph.entity("app")!, graph: graph)
    #expect(story.processes.map(\.entity.id) == ["process"])
    #expect(story.startupItems.map(\.entity.id) == ["startup"])
    #expect(story.associatedItems.map(\.entity.id) == ["cache"])
    #expect(story.owners.map(\.entity.id) == ["manager"])
    #expect(story.currentState == "Running")
    #expect(story.status == .running)
    #expect(story.unknowns.isEmpty)
  }

  @Test("Story explains missing evidence rather than dropping sections")
  func missingStates() {
    let application = Entity(
      id: "app",
      type: .application,
      name: "Unknown Example",
      summary: "An application with no connected evidence."
    )
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "missing", name: "Missing", summary: "Missing"),
      entities: [application],
      relationships: []
    )

    let story = ApplicationStoryModel(application: application, graph: graph)
    #expect(story.currentState == "Not observed running")
    #expect(story.status == .offline)
    #expect(story.unknowns.count == 4)
  }

  @Test("Story keeps possible associations separate from strong associations")
  func possibleAssociations() {
    let application = Entity(id: "app", type: .application, name: "Example", summary: "App")
    let strong = Entity(id: "strong", type: .file, name: "Bundle match", summary: "Strong")
    let possible = Entity(id: "possible", type: .file, name: "Name match", summary: "Possible")
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "confidence", name: "Confidence", summary: "Confidence"),
      entities: [application, strong, possible],
      relationships: [
        relationship("strong", source: "app", target: "strong", type: .mayBelongTo),
        relationship(
          "possible", source: "app", target: "possible", type: .mayBelongTo,
          confidence: .possible),
      ]
    )

    let story = ApplicationStoryModel(application: application, graph: graph)
    #expect(story.associatedItems.map(\.entity.id) == ["strong"])
    #expect(story.possibleAssociatedItems.map(\.entity.id) == ["possible"])
  }

  @Test("Story turns App Store receipt evidence into a useful source conclusion")
  func appStoreSource() {
    let application = Entity(
      id: "app",
      type: .application,
      name: "Store Example",
      summary: "An App Store application.",
      details: [
        Detail("Download origin", "Not observed"),
        Detail("App Store receipt", "Present"),
      ]
    )
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "store", name: "Store", summary: "Store"),
      entities: [application],
      relationships: []
    )

    let story = ApplicationStoryModel(application: application, graph: graph)
    #expect(story.provenance == [Detail("Installation source", "App Store")])
  }

  @Test("Story status prioritizes health and warning details")
  func healthStatus() {
    let warningApplication = Entity(
      id: "warning",
      type: .application,
      name: "Warning Example",
      summary: "Warnings",
      details: [Detail("Warnings", "2"), Detail("Current state", "Running")]
    )
    let unhealthyApplication = Entity(
      id: "unhealthy",
      type: .application,
      name: "Broken Example",
      summary: "Broken",
      details: [Detail("Application health", "Unhealthy"), Detail("Warnings", "2")]
    )
    let graph = SystemGraph(
      metadata: FixtureMetadata(id: "health", name: "Health", summary: "Health"),
      entities: [warningApplication, unhealthyApplication],
      relationships: []
    )

    #expect(
      ApplicationStoryModel(application: warningApplication, graph: graph).status == .warnings(2)
    )
    #expect(
      ApplicationStoryModel(application: unhealthyApplication, graph: graph).status == .unhealthy
    )
  }

  private func relationship(
    _ id: String,
    source: EntityID,
    target: EntityID,
    type: RelationshipType,
    confidence: Confidence = .confirmed
  ) -> Relationship {
    Relationship(
      id: RelationshipID(id),
      source: source,
      target: target,
      type: type,
      confidence: confidence,
      explanation: "Evidence-backed connection.",
      evidence: [
        Evidence(
          id: "\(id)-evidence",
          kind: .observed,
          summary: "Observed.",
          source: "Test"
        )
      ]
    )
  }
}
