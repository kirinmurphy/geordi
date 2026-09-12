import Foundation
import GeordiDomain
import GeordiManifestKit

public struct ReferenceCatalogConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let items: [ReferenceDefinition]

  public static func bundled() throws -> Self {
    try BundledManifestResource<Self>(
      manifestName: "reference-catalog",
      schemaName: "reference-catalog.schema",
      bundle: .module
    ).load { catalog in
      guard catalog.schemaVersion == currentVersion else {
        throw ReferenceCatalogError.unsupportedVersion(catalog.schemaVersion)
      }
      guard Set(catalog.items.map(\.id)).count == catalog.items.count else {
        throw ReferenceCatalogError.duplicateItemID
      }
      let mappedTypes = catalog.items.flatMap(\.entityTypes)
      guard Set(mappedTypes).count == mappedTypes.count else {
        throw ReferenceCatalogError.duplicateEntityTypeMapping
      }
    }
  }

  public func item(for entityType: EntityType) -> ReferenceDefinition? {
    items.first { $0.entityTypes.contains(entityType) }
  }
}

public struct ReferenceDefinition: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let title: String
  public let detail: String
  public let explanation: String
  public let question: String
  public let examples: String
  public let symbol: String
  public let tint: EntityPresentationTint
  public let entityTypes: [EntityType]
}

public enum ReferenceCatalogError: Error, Equatable, Sendable {
  case unsupportedVersion(Int)
  case duplicateItemID
  case duplicateEntityTypeMapping
}
