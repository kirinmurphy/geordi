import HALDomain
import HALFixtures
import HALVisualization
import Testing

@Suite("Visualization model")
struct VisualizationTests {
  let configuration = AppConfiguration.phaseZero.layout

  @Test("Semantic layout is deterministic")
  func deterministicLayout() {
    let layout = SemanticLayout(configuration: configuration)
    let first = layout.layout(FixtureCatalog.helperRichApplication)
    let second = layout.layout(FixtureCatalog.helperRichApplication)
    #expect(first == second)
    #expect(first.positions.count == FixtureCatalog.helperRichApplication.entities.count)
  }

  @Test("Semantic columns remain ordered")
  func semanticColumns() {
    let result = SemanticLayout(configuration: configuration)
      .layout(FixtureCatalog.simpleApplication)
    let appX = result.positions["app.notes"]?.x
    let processX = result.positions["process.notes"]?.x
    let fileX = result.positions["file.notes"]?.x
    #expect(appX != nil)
    #expect(processX != nil)
    #expect(fileX != nil)
    #expect(appX! < processX!)
    #expect(processX! < fileX!)
  }

  @Test("Empty semantic stages do not reserve invisible columns")
  func emptyStagesAreRemoved() {
    let result = SemanticLayout(configuration: configuration)
      .layout(FixtureCatalog.simpleApplication)
    #expect(result.groups.map(\.id) == ["software", "runtime", "data", "impact"])
    #expect(result.groups.count == 4)
    #expect(result.size.width < 950)
    #expect(result.size.height >= 220)
  }

  @Test("Dense graphs collapse entity types into five structural stages")
  func denseGraphStages() {
    let result = SemanticLayout(configuration: configuration)
      .layout(FixtureCatalog.familiarMac)
    #expect(result.groups.map(\.id) == ["context", "software", "runtime", "data", "impact"])
    #expect(result.groups.count == 5)
    #expect(result.positions.count == FixtureCatalog.familiarMac.entities.count)
  }

  @Test("Entity selection highlights only direct context")
  func highlightsDirectContext() {
    let graph = FixtureCatalog.helperRichApplication
    let navigator = GraphNavigator(graph: graph)
    let selection = GraphSelection(.entity("process.forge"))
    let edges = navigator.highlightedRelationships(for: selection)
    #expect(edges == ["forge-launches", "forge-renderer", "forge-indexer"])
    #expect(!edges.contains("forge-cache"))
  }

  @Test("Changing selection removes previously highlighted relationships")
  func changingSelectionClearsOldHighlights() {
    let graph = FixtureCatalog.familiarMac
    let navigator = GraphNavigator(graph: graph)
    let incidentEdges = navigator.highlightedRelationships(
      for: GraphSelection(.entity("incident.build")))
    let dockerEdges = navigator.highlightedRelationships(
      for: GraphSelection(.entity("process.vm")))
    #expect(incidentEdges.count == 4)
    #expect(dockerEdges == ["docker-vm", "docker-disk", "docker-build-cache", "docker-memory"])
    #expect(!dockerEdges.contains("vscode-memory"))
    #expect(!dockerEdges.contains("brave-memory"))
  }

  @Test("Filtering preserves selection and search respects visible types")
  func filteringAndSearch() {
    let graph = FixtureCatalog.simpleApplication
    let selection = GraphSelection(.entity("app.notes"))
    let results = GraphNavigator(graph: graph).search(
      "Northstar",
      visibleTypes: [.process]
    )
    #expect(selection.value == .entity("app.notes"))
    #expect(results.map(\.id) == ["process.notes"])
  }
}
