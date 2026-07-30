import Foundation
import HALDomain
import HALManifestKit

public struct ExplorationContextConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let contexts: [ExplorationContext]

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(
        forResource: "exploration-contexts",
        withExtension: "json"
      ),
      let schemaURL = Bundle.module.url(
        forResource: "exploration-contexts.schema",
        withExtension: "json"
      )
    else {
      throw ExplorationContextError.resourceUnavailable
    }
    return try decode(Data(contentsOf: manifestURL), schema: Data(contentsOf: schemaURL))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw ExplorationContextError.unsupportedVersion(configuration.schemaVersion)
      }
      guard Set(configuration.contexts.map(\.id)).count == configuration.contexts.count else {
        throw ExplorationContextError.duplicateContextID
      }
      for context in configuration.contexts {
        guard Set(context.sections.map(\.id)).count == context.sections.count else {
          throw ExplorationContextError.duplicateSectionID(context.id)
        }
      }
      return configuration
    } catch let error as ExplorationContextError {
      throw error
    } catch {
      throw ExplorationContextError.invalid(String(describing: error))
    }
  }

  public func context(_ id: String) -> ExplorationContext? {
    contexts.first { $0.id == id }
  }
}

public enum ExplorationPresentationKind: String, Codable, Sendable {
  case applicationBrowser
  case groupedBrowser
  case centeredMap
  case purposeBuilt
}

public enum ExplorationDrillIn: String, Codable, Sendable {
  case applicationStory
  case boundedRelationships
  case none
}

public enum ExplorationGroupingKind: String, Codable, Sendable {
  case flat
  case detail
  case relationshipOwner
}

public struct ExplorationContext: Codable, Hashable, Sendable {
  public let id: String
  public let question: String
  public let title: String
  public let presentation: ExplorationPresentationKind
  public let supportedEntityTypes: [EntityType]
  public let supportedRelationshipTypes: [RelationshipType]
  public let sections: [ExplorationSectionDefinition]
  public let drillIn: ExplorationDrillIn
  public let initialItemBudget: Int
  public let emptyTitle: String
  public let emptyMessage: String
  public let unresolvedTitle: String?
}

public struct ExplorationSectionDefinition: Codable, Hashable, Sendable {
  public let id: String
  public let title: String
  public let explanation: String
  public let entityTypes: [EntityType]
  public let grouping: ExplorationGroupingKind
  public let detailLabel: String?
  public let detailValues: [String]?
  public let relationshipTypes: [RelationshipType]?
  public let unresolved: Bool?
}

public enum ExplorationContextError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateContextID
  case duplicateSectionID(String)
  case invalid(String)
}

public struct ExplorationPresentation: Equatable, Sendable {
  public let contextID: String
  public let sections: [ExplorationSection]
  public let unassignedEntityIDs: [EntityID]

  public init(
    contextID: String,
    sections: [ExplorationSection],
    unassignedEntityIDs: [EntityID]
  ) {
    self.contextID = contextID
    self.sections = sections
    self.unassignedEntityIDs = unassignedEntityIDs
  }
}

public struct ExplorationSection: Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let explanation: String
  public let groups: [ExplorationGroup]
}

public struct ExplorationGroup: Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let entityIDs: [EntityID]
  public let actionEntityID: EntityID?
}

public struct ExplorationPresenter: Sendable {
  public init() {}

  public func present(graph: SystemGraph, context: ExplorationContext) -> ExplorationPresentation {
    let supported = graph.entities
      .filter { context.supportedEntityTypes.contains($0.type) }
      .sorted(by: entityOrder)
    var assigned = Set<EntityID>()
    var sections: [ExplorationSection] = []

    for definition in context.sections {
      let candidates = supported.filter { entity in
        guard !assigned.contains(entity.id), definition.entityTypes.contains(entity.type) else {
          return false
        }
        if definition.unresolved == true {
          return owners(of: entity.id, graph: graph, definition: definition).isEmpty
        }
        guard let label = definition.detailLabel else { return true }
        let value = detail(label, in: entity)
        guard let values = definition.detailValues else { return value != nil }
        return value.map(values.contains) ?? false
      }

      let groups: [ExplorationGroup]
      switch definition.grouping {
      case .flat:
        groups =
          candidates.isEmpty
          ? []
          : [
            ExplorationGroup(
              id: stableGroupID(context.id, definition.id, "all"),
              title: definition.title,
              entityIDs: candidates.map(\.id),
              actionEntityID: nil
            )
          ]
      case .detail:
        let partitions = Dictionary(grouping: candidates) {
          detail(definition.detailLabel ?? "", in: $0) ?? context.unresolvedTitle ?? "Unresolved"
        }
        groups = partitions.keys.sorted(by: localizedStableOrder).compactMap { key in
          guard let members = partitions[key] else { return nil }
          return ExplorationGroup(
            id: stableGroupID(context.id, definition.id, key),
            title: key,
            entityIDs: members.sorted(by: entityOrder).map(\.id),
            actionEntityID: nil
          )
        }
      case .relationshipOwner:
        var partitions: [EntityID: [Entity]] = [:]
        for entity in candidates {
          let ownerIDs = owners(of: entity.id, graph: graph, definition: definition)
          for ownerID in ownerIDs {
            partitions[ownerID, default: []].append(entity)
          }
        }
        groups = partitions.keys.sorted { lhs, rhs in
          let left = graph.entity(lhs)?.name ?? lhs.rawValue
          let right = graph.entity(rhs)?.name ?? rhs.rawValue
          if left.lowercased() != right.lowercased() {
            return left.lowercased() < right.lowercased()
          }
          return lhs.rawValue < rhs.rawValue
        }.compactMap { ownerID in
          guard let members = partitions[ownerID] else { return nil }
          return ExplorationGroup(
            id: stableGroupID(context.id, definition.id, ownerID.rawValue),
            title: graph.entity(ownerID)?.name ?? ownerID.rawValue,
            entityIDs: members.sorted(by: entityOrder).map(\.id),
            actionEntityID: ownerID
          )
        }
      }

      let memberIDs = Set(groups.flatMap(\.entityIDs))
      assigned.formUnion(memberIDs)
      sections.append(
        ExplorationSection(
          id: definition.id,
          title: definition.title,
          explanation: definition.explanation,
          groups: groups
        )
      )
    }

    return ExplorationPresentation(
      contextID: context.id,
      sections: sections,
      unassignedEntityIDs: supported.filter { entity in
        !assigned.contains(entity.id)
          && context.sections.contains { section in section.entityTypes.contains(entity.type) }
      }.map(\.id)
    )
  }

  private func owners(
    of entityID: EntityID,
    graph: SystemGraph,
    definition: ExplorationSectionDefinition
  ) -> [EntityID] {
    let types = definition.relationshipTypes ?? [.persistsThrough]
    return graph.relationships
      .filter {
        types.contains($0.type)
          && ($0.source == entityID || $0.target == entityID)
          && $0.confidence != .ambiguous
      }
      .map { $0.source == entityID ? $0.target : $0.source }
      .filter { graph.entity($0)?.type != .process }
      .sorted { $0.rawValue < $1.rawValue }
  }

  private func detail(_ label: String, in entity: Entity) -> String? {
    entity.details.first { $0.label == label }?.value
  }

  private func entityOrder(_ lhs: Entity, _ rhs: Entity) -> Bool {
    if lhs.name.lowercased() != rhs.name.lowercased() {
      return lhs.name.lowercased() < rhs.name.lowercased()
    }
    return lhs.id.rawValue < rhs.id.rawValue
  }

  private func localizedStableOrder(_ lhs: String, _ rhs: String) -> Bool {
    if lhs.lowercased() != rhs.lowercased() { return lhs.lowercased() < rhs.lowercased() }
    return lhs < rhs
  }

  private func stableGroupID(_ context: String, _ section: String, _ key: String) -> String {
    let encoded = Data(key.utf8).base64EncodedString()
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "=", with: "")
    return "exploration-group:\(context):\(section):\(encoded)"
  }
}
