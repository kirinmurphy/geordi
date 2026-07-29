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
    #expect(story.sourceSummary == "Homebrew cask example")
    #expect(story.currentState == "Running")
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
    #expect(story.sourceSummary == "Source evidence unavailable")
    #expect(story.unknowns.count == 4)
  }

  private func relationship(
    _ id: String,
    source: EntityID,
    target: EntityID,
    type: RelationshipType
  ) -> Relationship {
    Relationship(
      id: RelationshipID(id),
      source: source,
      target: target,
      type: type,
      confidence: .confirmed,
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
