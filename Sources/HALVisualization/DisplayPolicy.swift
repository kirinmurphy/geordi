import Foundation
import HALDomain
import HALManifestKit

public struct DisplayPolicy: Codable, Hashable, Sendable {
  public static let currentVersion = 2

  public let schemaVersion: Int
  public let contexts: [DisplayContextPolicy]

  public init(schemaVersion: Int = Self.currentVersion, contexts: [DisplayContextPolicy]) {
    self.schemaVersion = schemaVersion
    self.contexts = contexts
  }

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(forResource: "display-policy", withExtension: "json"),
      let schemaURL = Bundle.module.url(
        forResource: "display-policy.schema",
        withExtension: "json"
      )
    else {
      throw DisplayPolicyError.resourceUnavailable
    }
    return try decode(Data(contentsOf: manifestURL), schema: Data(contentsOf: schemaURL))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let policy = try JSONDecoder().decode(Self.self, from: data)
      guard policy.schemaVersion == currentVersion else {
        throw DisplayPolicyError.unsupportedVersion(policy.schemaVersion)
      }
      guard Set(policy.contexts.map(\.id)).count == policy.contexts.count else {
        throw DisplayPolicyError.duplicateContextID
      }
      for context in policy.contexts {
        guard Set(context.relationships.map(\.type)).count == context.relationships.count else {
          throw DisplayPolicyError.duplicateRelationshipType(context.id)
        }
      }
      return policy
    } catch let error as DisplayPolicyError {
      throw error
    } catch {
      throw DisplayPolicyError.invalid(String(describing: error))
    }
  }

  public func context(_ id: String) -> DisplayContextPolicy? {
    contexts.first { $0.id == id }
  }
}

public struct DisplayContextPolicy: Codable, Hashable, Sendable {
  public let id: String
  public let nodeBudget: Int
  public let relationships: [RelationshipDisplayRule]

  public init(id: String, nodeBudget: Int, relationships: [RelationshipDisplayRule]) {
    self.id = id
    self.nodeBudget = nodeBudget
    self.relationships = relationships
  }
}

public struct RelationshipDisplayRule: Codable, Hashable, Sendable {
  public let type: RelationshipType
  public let priority: Int
  public let minimumConfidence: Confidence
  public let groupAfter: Int?
  public let groupLabel: String?
  public let traversalDepth: Int?

  public init(
    type: RelationshipType,
    priority: Int,
    minimumConfidence: Confidence,
    groupAfter: Int? = nil,
    groupLabel: String? = nil,
    traversalDepth: Int = 1
  ) {
    self.type = type
    self.priority = priority
    self.minimumConfidence = minimumConfidence
    self.groupAfter = groupAfter
    self.groupLabel = groupLabel
    self.traversalDepth = traversalDepth
  }
}

public enum DisplayPolicyError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateContextID
  case duplicateRelationshipType(String)
  case invalid(String)
}

public struct DisplayPolicyPresenter: Sendable {
  public init() {}

  public func present(
    _ graph: SystemGraph,
    centeredOn center: EntityID,
    policy: DisplayContextPolicy
  ) -> SystemGraph {
    guard let centerEntity = graph.entity(center) else { return graph }
    let rules = Dictionary(uniqueKeysWithValues: policy.relationships.map { ($0.type, $0) })
    let eligible = graph.relationships(connectedTo: center).compactMap {
      relationship -> (Relationship, RelationshipDisplayRule)? in
      guard
        let rule = rules[relationship.type],
        meetsFloor(relationship.confidence, floor: rule.minimumConfidence)
      else {
        return nil
      }
      return (relationship, rule)
    }
    .sorted {
      if $0.1.priority != $1.1.priority { return $0.1.priority > $1.1.priority }
      if $0.0.confidence != $1.0.confidence { return $0.0.confidence > $1.0.confidence }
      return $0.0.id.rawValue < $1.0.id.rawValue
    }

    var entities = [centerEntity]
    var relationships: [Relationship] = []
    var remaining = max(0, policy.nodeBudget - 1)
    let grouped = Dictionary(grouping: eligible, by: { $0.0.type })
    for rule in policy.relationships.sorted(by: { $0.priority > $1.priority }) {
      guard remaining > 0, let candidates = grouped[rule.type], !candidates.isEmpty else {
        continue
      }
      if let threshold = rule.groupAfter, candidates.count >= threshold {
        let members = candidates.compactMap { counterpart(for: $0.0, center: center, graph: graph) }
        guard !members.isEmpty else { continue }
        let groupID = EntityID("display-group:\(center.rawValue):\(rule.type.rawValue)")
        let label = rule.groupLabel ?? rule.type.rawValue
        entities.append(
          Entity(
            id: groupID,
            type: members[0].type,
            name: "\(members.count) \(label)",
            summary:
              "A presentation group; the individual observations remain available in technical details.",
            details: [Detail("Includes", members.map(\.name).sorted().joined(separator: ", "))]
          )
        )
        let first = candidates[0].0
        relationships.append(
          Relationship(
            id: RelationshipID("display-group:\(first.id.rawValue)"),
            source: first.source == center ? center : groupID,
            target: first.source == center ? groupID : center,
            type: first.type,
            confidence: candidates.map(\.0.confidence).min() ?? first.confidence,
            explanation:
              "\(members.count) similar relationships are grouped to keep this map readable.",
            evidence: candidates.flatMap(\.0.evidence)
          )
        )
        remaining -= 1
      } else {
        for candidate in candidates.prefix(remaining) {
          guard let entity = counterpart(for: candidate.0, center: center, graph: graph) else {
            continue
          }
          entities.append(entity)
          relationships.append(candidate.0)
          remaining -= 1
        }
      }
    }

    // Some provenance is a chain rather than a direct edge (for example
    // Homebrew → cask → application). A policy can retain that real chain
    // without fabricating a flattened relationship.
    var includedEntityIDs = Set(entities.map(\.id))
    var includedRelationshipIDs = Set(relationships.map(\.id))
    for rule in policy.relationships.sorted(by: { $0.priority > $1.priority })
    where (rule.traversalDepth ?? 1) > 1 && remaining > 0 {
      var frontier: Set<EntityID> = [center]
      var visited: Set<EntityID> = [center]
      for _ in 1...(rule.traversalDepth ?? 1) where remaining > 0 {
        let candidates = graph.relationships
          .filter {
            $0.type == rule.type
              && meetsFloor($0.confidence, floor: rule.minimumConfidence)
              && (frontier.contains($0.source) || frontier.contains($0.target))
          }
          .sorted { $0.id.rawValue < $1.id.rawValue }
        var nextFrontier = Set<EntityID>()
        for relationship in candidates where remaining > 0 {
          let counterpartID =
            frontier.contains(relationship.source) ? relationship.target : relationship.source
          guard !visited.contains(counterpartID) else { continue }
          visited.insert(counterpartID)
          nextFrontier.insert(counterpartID)
          guard !includedEntityIDs.contains(counterpartID), let entity = graph.entity(counterpartID)
          else { continue }
          entities.append(entity)
          includedEntityIDs.insert(counterpartID)
          if includedRelationshipIDs.insert(relationship.id).inserted {
            relationships.append(relationship)
          }
          remaining -= 1
        }
        frontier = nextFrontier
        if frontier.isEmpty { break }
      }
    }
    return SystemGraph(
      metadata: graph.metadata,
      entities: uniqueEntities(entities),
      relationships: relationships
    )
  }

  private func counterpart(
    for relationship: Relationship,
    center: EntityID,
    graph: SystemGraph
  ) -> Entity? {
    graph.entity(relationship.source == center ? relationship.target : relationship.source)
  }

  private func meetsFloor(_ confidence: Confidence, floor: Confidence) -> Bool {
    confidence != .ambiguous && confidence >= floor
  }

  private func uniqueEntities(_ entities: [Entity]) -> [Entity] {
    var seen = Set<EntityID>()
    return entities.filter { seen.insert($0.id).inserted }
  }
}
