import Foundation
import HALDomain
import HALManifestKit

public struct FileFacetConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let categories: [FileFacetCategory]
  public let fallback: FileFacets

  public static func bundled() throws -> Self {
    try BundledManifestResource<Self>(
      manifestName: "file-facets",
      schemaName: "file-facets.schema",
      bundle: .module
    ).load { configuration in
      guard configuration.schemaVersion == currentVersion else {
        throw FileFacetConfigurationError.unsupportedVersion(configuration.schemaVersion)
      }
      guard Set(configuration.categories.map(\.label)).count == configuration.categories.count
      else {
        throw FileFacetConfigurationError.duplicateCategory
      }
    }
  }

  public static var required: Self {
    do { return try bundled() } catch {
      preconditionFailure("Required file-facet configuration failed validation: \(error)")
    }
  }

  public func facets(for category: String) -> FileFacets {
    categories.first { $0.label.caseInsensitiveCompare(category) == .orderedSame }?.facets
      ?? fallback
  }

  public func enriching(_ graph: SystemGraph) -> SystemGraph {
    SystemGraph(
      metadata: graph.metadata,
      entities: graph.entities.map { entity in
        guard entity.type == .file, entity.detail(.fileRole) == nil else { return entity }
        let category =
          entity.details.first {
            $0.label == "Category" || $0.label == "Classification"
          }?.value ?? ""
        let existingLabels = Set(entity.details.map(\.label))
        let addedDetails = facets(for: category).details.filter {
          !existingLabels.contains($0.label)
        }
        return Entity(
          id: entity.id,
          type: entity.type,
          name: entity.name,
          summary: entity.summary,
          details: entity.details + addedDetails,
          instances: entity.instances,
          presentation: entity.presentation
        )
      },
      relationships: graph.relationships
    )
  }
}

public struct FileFacetCategory: Codable, Hashable, Sendable {
  public let label: String
  public let facets: FileFacets
}

public struct FileFacets: Codable, Hashable, Sendable {
  public let role: String
  public let rebuildability: String
  public let ownership: String
  public let sensitivity: String
  public let kind: String

  public var details: [Detail] {
    [
      Detail(.fileRole, role),
      Detail(.fileRebuildability, rebuildability),
      Detail(.fileOwnership, ownership),
      Detail(.fileSensitivity, sensitivity),
      Detail(.fileKind, kind),
    ]
  }

  public func overriding(ownership: String? = nil, kind: String? = nil) -> Self {
    Self(
      role: role,
      rebuildability: rebuildability,
      ownership: ownership ?? self.ownership,
      sensitivity: sensitivity,
      kind: kind ?? self.kind
    )
  }
}

public enum FileFacetConfigurationError: Error, Equatable, Sendable {
  case unsupportedVersion(Int)
  case duplicateCategory
}
