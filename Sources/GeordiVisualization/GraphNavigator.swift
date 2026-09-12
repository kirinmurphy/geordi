import GeordiDomain

public struct GraphNavigator: Sendable {
  public let graph: SystemGraph

  public init(graph: SystemGraph) {
    self.graph = graph
  }

  public func highlightedRelationships(for selection: GraphSelection?) -> Set<RelationshipID> {
    guard let selection else { return [] }
    switch selection.value {
    case .entity(let id):
      return Set(graph.relationships(connectedTo: id).map(\.id))
    case .relationship(let id):
      return [id]
    }
  }

  public func highlightedEntities(for selection: GraphSelection?) -> Set<EntityID> {
    guard let selection else { return [] }
    switch selection.value {
    case .entity(let id):
      let edges = graph.relationships(connectedTo: id)
      return Set([id] + edges.flatMap { [$0.source, $0.target] })
    case .relationship(let id):
      guard let edge = graph.relationship(id) else { return [] }
      return [edge.source, edge.target]
    }
  }

  public func search(_ query: String, visibleTypes: Set<EntityType>) -> [Entity] {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return [] }
    return graph.entities.filter {
      visibleTypes.contains($0.type)
        && ($0.name.localizedCaseInsensitiveContains(normalized)
          || $0.summary.localizedCaseInsensitiveContains(normalized)
          || $0.details.contains {
            $0.label.localizedCaseInsensitiveContains(normalized)
              || $0.value.localizedCaseInsensitiveContains(normalized)
          })
    }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }
}
