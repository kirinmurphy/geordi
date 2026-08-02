import Foundation
import HALDomain
import HALManifestKit

public enum FilesystemObservationState: String, Codable, CaseIterable, Sendable {
  case notEnumerated = "not-enumerated"
  case unavailable
  case unreadable
  case empty
  case observed
}

public struct FilesystemLocationCatalog: Codable, Sendable {
  public static let currentVersion = 2
  public let schemaVersion: Int
  public let locations: [FilesystemLocationDefinition]

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "filesystem-locations", withExtension: "json"),
      let schema = Bundle.module.url(
        forResource: "filesystem-locations.schema", withExtension: "json")
    else { throw FilesystemLocationError.resourceUnavailable }
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let catalog = try JSONDecoder().decode(Self.self, from: data)
      guard catalog.schemaVersion == currentVersion else {
        throw FilesystemLocationError.unsupportedVersion(catalog.schemaVersion)
      }
      guard Set(catalog.locations.map(\.id)).count == catalog.locations.count else {
        throw FilesystemLocationError.duplicateID
      }
      for location in catalog.locations {
        guard
          location.pathTemplate.hasPrefix("/") || location.pathTemplate.hasPrefix("{home}"),
          !URL(fileURLWithPath: location.pathTemplate).pathComponents.contains("..")
        else { throw FilesystemLocationError.unsafePath(location.pathTemplate) }
      }
      return catalog
    } catch let error as FilesystemLocationError {
      throw error
    } catch {
      throw FilesystemLocationError.invalid(String(describing: error))
    }
  }
}

public struct FilesystemLocationDefinition: Codable, Identifiable, Hashable, Sendable {
  public let id: String
  public let pathTemplate: String
  public let displayLabel: String
  public let purpose: String
  public let system: String
  public let sensitivity: String
  public let symbol: String
  public let enumerationAllowed: Bool
  public let maximumDepth: Int
  public let entryBudget: Int
}

public struct FilesystemNode: Identifiable, Hashable, Sendable {
  public let id: String
  public let path: String
  public let label: String
  public let purpose: String
  public let system: String
  public let symbol: String
  public let state: FilesystemObservationState
  public let depth: Int
  public let parentID: String?
  public let entityIDs: [EntityID]
}

public struct FilesystemProjector: Sendable {
  public init() {}

  public func project(
    graph: SystemGraph,
    catalog: FilesystemLocationCatalog,
    homeDirectory: String,
    includeReferenceLocations: Bool = false
  ) -> [FilesystemNode] {
    let observed = graph.entities.compactMap { entity -> (EntityID, String)? in
      guard let path = entity.details.first(where: { $0.value.hasPrefix("/") })?.value else {
        return nil
      }
      return (entity.id, URL(fileURLWithPath: path).standardizedFileURL.path)
    }
    let definitions = catalog.locations.map {
      definition -> (FilesystemLocationDefinition, String) in
      (definition, definition.pathTemplate.replacingOccurrences(of: "{home}", with: homeDirectory))
    }
    return definitions.compactMap { definition, path in
      let associated = observed.filter { _, observedPath in
        observedPath == path || observedPath.hasPrefix(path == "/" ? "/" : path + "/")
      }.map(\.0).sorted { $0.rawValue < $1.rawValue }
      let associatedEntities = associated.compactMap(graph.entity)
      let state: FilesystemObservationState =
        if associatedEntities.contains(where: {
          $0.details.contains { $0.value.localizedCaseInsensitiveContains("unreadable") }
        }) {
          .unreadable
        } else if associatedEntities.contains(where: {
          $0.details.contains { $0.value.localizedCaseInsensitiveContains("unavailable") }
        }) {
          .unavailable
        } else if associated.isEmpty {
          .notEnumerated
        } else {
          .observed
        }
      let parent =
        definitions
        .filter { _, candidate in
          candidate != path && path.hasPrefix(candidate == "/" ? "/" : candidate + "/")
        }
        .max { $0.1.count < $1.1.count }
      guard includeReferenceLocations || !associated.isEmpty || definition.pathTemplate == "/"
      else {
        return nil
      }
      return FilesystemNode(
        id: definition.id,
        path: path,
        label: definition.displayLabel.replacingOccurrences(
          of: "{user}", with: URL(fileURLWithPath: homeDirectory).lastPathComponent),
        purpose: definition.purpose,
        system: definition.system,
        symbol: definition.symbol,
        state: state,
        depth: max(0, path.split(separator: "/").count),
        parentID: parent?.0.id,
        entityIDs: associated
      )
    }.sorted { lhs, rhs in
      if lhs.depth != rhs.depth { return lhs.depth < rhs.depth }
      return lhs.path < rhs.path
    }
  }
}

public enum FilesystemLocationError: Error, Equatable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateID
  case unsafePath(String)
  case invalid(String)
}
