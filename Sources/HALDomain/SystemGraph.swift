import Foundation

public struct FixtureMetadata: Hashable, Codable, Sendable {
  public let id: String
  public let version: Int
  public let name: String
  public let summary: String

  public init(id: String, version: Int = 1, name: String, summary: String) {
    self.id = id
    self.version = version
    self.name = name
    self.summary = summary
  }
}

public struct SystemGraph: Hashable, Codable, Sendable {
  public let metadata: FixtureMetadata
  public let entities: [Entity]
  public let relationships: [Relationship]

  public init(
    metadata: FixtureMetadata,
    entities: [Entity],
    relationships: [Relationship]
  ) {
    self.metadata = metadata
    self.entities = entities
    self.relationships = relationships
  }

  public func entity(_ id: EntityID) -> Entity? {
    entities.first { $0.id == id }
  }

  public func relationship(_ id: RelationshipID) -> Relationship? {
    relationships.first { $0.id == id }
  }

  public func relationships(connectedTo id: EntityID) -> [Relationship] {
    relationships.filter { $0.source == id || $0.target == id }
  }

  public func neighborhood(around center: EntityID, depth: Int = 1) -> SystemGraph {
    var included: Set<EntityID> = [center]
    var frontier: Set<EntityID> = [center]
    for _ in 0..<max(depth, 0) {
      let connected = relationships.filter {
        frontier.contains($0.source) || frontier.contains($0.target)
      }
      let next = Set(connected.flatMap { [$0.source, $0.target] })
      frontier = next.subtracting(included)
      included.formUnion(next)
    }
    return SystemGraph(
      metadata: metadata,
      entities: entities.filter { included.contains($0.id) },
      relationships: relationships.filter {
        included.contains($0.source) && included.contains($0.target)
      }
    )
  }

  public func filtered(to types: Set<EntityType>) -> SystemGraph {
    let included = Set(entities.filter { types.contains($0.type) }.map(\.id))
    return SystemGraph(
      metadata: metadata,
      entities: entities.filter { included.contains($0.id) },
      relationships: relationships.filter {
        included.contains($0.source) && included.contains($0.target)
      }
    )
  }

  public func validate() throws {
    guard metadata.version > 0 else { throw GraphValidationError.invalidVersion }
    let entityIDs = entities.map(\.id)
    guard Set(entityIDs).count == entityIDs.count else {
      throw GraphValidationError.duplicateEntity
    }
    let relationshipIDs = relationships.map(\.id)
    guard Set(relationshipIDs).count == relationshipIDs.count else {
      throw GraphValidationError.duplicateRelationship
    }
    let validIDs = Set(entityIDs)
    for relationship in relationships
    where !validIDs.contains(relationship.source) || !validIDs.contains(relationship.target) {
      throw GraphValidationError.missingEndpoint(relationship.id)
    }
    guard
      entities.allSatisfy({
        !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      })
    else {
      throw GraphValidationError.missingHumanReadableName
    }
    guard relationships.allSatisfy({ !$0.evidence.isEmpty }) else {
      throw GraphValidationError.missingEvidence
    }
  }
}

public struct SystemGraphIndex: Sendable {
  public let entitiesByID: [EntityID: Entity]
  public let relationshipsByID: [RelationshipID: Relationship]
  public let relationshipsByEntityID: [EntityID: [Relationship]]
  public let entitiesByType: [EntityType: [Entity]]

  public init(graph: SystemGraph) {
    entitiesByID = Dictionary(
      graph.entities.map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    relationshipsByID = Dictionary(
      graph.relationships.map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    var adjacency: [EntityID: [Relationship]] = [:]
    for relationship in graph.relationships {
      adjacency[relationship.source, default: []].append(relationship)
      if relationship.target != relationship.source {
        adjacency[relationship.target, default: []].append(relationship)
      }
    }
    relationshipsByEntityID = adjacency.mapValues {
      $0.sorted { $0.id.rawValue < $1.id.rawValue }
    }
    entitiesByType = Dictionary(grouping: graph.entities, by: \.type)
  }

  public func entity(_ id: EntityID) -> Entity? {
    entitiesByID[id]
  }

  public func relationship(_ id: RelationshipID) -> Relationship? {
    relationshipsByID[id]
  }

  public func relationships(connectedTo id: EntityID) -> [Relationship] {
    relationshipsByEntityID[id] ?? []
  }

  public func entities(ofType type: EntityType) -> [Entity] {
    entitiesByType[type] ?? []
  }
}

public enum GraphValidationError: Error, Equatable {
  case invalidVersion
  case duplicateEntity
  case duplicateRelationship
  case missingEndpoint(RelationshipID)
  case missingHumanReadableName
  case missingEvidence
}

public struct GraphSelection: Hashable, Sendable {
  public enum Value: Hashable, Sendable {
    case entity(EntityID)
    case relationship(RelationshipID)
  }

  public let value: Value
  public init(_ value: Value) { self.value = value }
}
