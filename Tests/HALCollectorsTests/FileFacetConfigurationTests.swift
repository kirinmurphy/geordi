import HALCollectors
import HALDomain
import Testing

@Suite("File facet configuration")
struct FileFacetConfigurationTests {
  @Test("Bundled facets are schema validated and enrich normalized files")
  func bundled() throws {
    let configuration = try FileFacetConfiguration.bundled()
    let file = Entity(
      id: "cache",
      type: .file,
      name: "Cache",
      summary: "Cache",
      details: [Detail("Category", "Cache")]
    )
    let graph = configuration.enriching(
      SystemGraph(
        metadata: FixtureMetadata(id: "facets", name: "Facets", summary: "Facets"),
        entities: [file],
        relationships: []
      )
    )
    let enriched = try #require(graph.entity("cache"))

    #expect(enriched.detail(.fileRole) == "Cache")
    #expect(enriched.detail(.fileRebuildability) == "Rebuildable")
    #expect(enriched.detail(.fileOwnership) == "Associated")
    #expect(enriched.detail(.fileSensitivity) == "Operational")
    #expect(enriched.detail(.fileKind) == "Directory")
  }

  @Test("Unknown file categories remain explicit")
  func fallback() throws {
    let facets = try FileFacetConfiguration.bundled().facets(for: "Unclassified")
    #expect(facets.role == "Other")
    #expect(facets.rebuildability == "Unknown")
    #expect(facets.ownership == "Unresolved")
  }
}
