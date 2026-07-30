import Foundation
import HALDomain
import HALVisualization
import Testing

@Suite("Display policy")
struct DisplayPolicyTests {
  @Test("Bundled policy is schema validated")
  func bundledPolicy() throws {
    let policy = try DisplayPolicy.bundled()
    #expect(policy.schemaVersion == 2)
    #expect(policy.context("applicationDetail")?.nodeBudget == 12)
  }

  @Test("Presenter retains a configured provenance chain")
  func provenanceChain() {
    let app = Entity(id: "app", type: .application, name: "Warp", summary: "App")
    let package = Entity(id: "cask", type: .package, name: "warp", summary: "Cask")
    let manager = Entity(
      id: "homebrew", type: .packageManager, name: "Homebrew", summary: "Manager")
    let edges = [
      Relationship(
        id: "cask-app",
        source: package.id,
        target: app.id,
        type: .owns,
        confidence: .confirmed,
        explanation: "The cask installs the application.",
        evidence: []
      ),
      Relationship(
        id: "manager-cask",
        source: manager.id,
        target: package.id,
        type: .owns,
        confidence: .confirmed,
        explanation: "Homebrew owns the cask.",
        evidence: []
      ),
    ]
    let source = SystemGraph(
      metadata: FixtureMetadata(id: "test", name: "Test", summary: "Test"),
      entities: [app, package, manager],
      relationships: edges
    )
    let policy = DisplayContextPolicy(
      id: "test",
      nodeBudget: 4,
      relationships: [
        RelationshipDisplayRule(
          type: .owns,
          priority: 100,
          minimumConfidence: .possible,
          traversalDepth: 2
        )
      ]
    )

    let result = DisplayPolicyPresenter().present(source, centeredOn: app.id, policy: policy)

    #expect(result.entity(package.id) != nil)
    #expect(result.entity(manager.id) != nil)
    #expect(Set(result.relationships.map(\.id)) == Set(edges.map(\.id)))
  }

  @Test(
    "Presenter prioritizes active relationships, groups strong locations, and keeps source intact")
  func relevanceProjection() {
    let source = graph()
    let policy = DisplayContextPolicy(
      id: "test",
      nodeBudget: 4,
      relationships: [
        RelationshipDisplayRule(type: .launches, priority: 100, minimumConfidence: .possible),
        RelationshipDisplayRule(
          type: .mayBelongTo,
          priority: 50,
          minimumConfidence: .high,
          groupAfter: 2,
          groupLabel: "support locations"
        ),
      ]
    )

    let result = DisplayPolicyPresenter().present(
      source,
      centeredOn: "app",
      policy: policy
    )

    #expect(source.entities.count == 6)
    #expect(result.entities.count == 3)
    #expect(result.relationships.count == 2)
    #expect(result.entity("process") != nil)
    let group = result.entities.first { $0.name == "2 support locations" }
    #expect(group != nil)
    #expect(group.map(DisplayGroupMetadata.isGroup) == true)
    #expect(group.map { Set(DisplayGroupMetadata.memberIDs(in: $0)) } == Set(["file-a", "file-b"]))
    #expect(result.entity("weak-file") == nil)
  }

  private func graph() -> SystemGraph {
    let entities = [
      Entity(id: "app", type: .application, name: "App", summary: "App"),
      Entity(id: "process", type: .process, name: "Running", summary: "Process"),
      Entity(id: "file-a", type: .file, name: "Support", summary: "File"),
      Entity(id: "file-b", type: .file, name: "Cache", summary: "File"),
      Entity(id: "weak-file", type: .file, name: "Weak", summary: "File"),
      Entity(id: "unrelated", type: .file, name: "Other", summary: "File"),
    ]
    func edge(_ id: String, _ target: EntityID, _ type: RelationshipType, _ confidence: Confidence)
      -> Relationship
    {
      Relationship(
        id: RelationshipID(id),
        source: "app",
        target: target,
        type: type,
        confidence: confidence,
        explanation: id,
        evidence: [Evidence(id: id, kind: .observed, summary: id, source: "test")]
      )
    }
    return SystemGraph(
      metadata: FixtureMetadata(id: "test", name: "Test", summary: "Test"),
      entities: entities,
      relationships: [
        edge("process", "process", .launches, .confirmed),
        edge("file-a", "file-a", .mayBelongTo, .high),
        edge("file-b", "file-b", .mayBelongTo, .high),
        edge("weak", "weak-file", .mayBelongTo, .possible),
      ]
    )
  }
}
