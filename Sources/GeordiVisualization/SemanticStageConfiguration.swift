import Foundation
import GeordiDomain
import GeordiManifestKit

public struct SemanticStageConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let stages: [SemanticStageDefinition]

  public init(
    schemaVersion: Int = Self.currentVersion,
    stages: [SemanticStageDefinition]
  ) {
    self.schemaVersion = schemaVersion
    self.stages = stages
  }

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "semantic-stages", withExtension: "json"),
      let schema = Bundle.module.url(forResource: "semantic-stages.schema", withExtension: "json")
    else {
      throw SemanticStageConfigurationError.resourceUnavailable
    }
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schema = Bundle.module.url(forResource: "semantic-stages.schema", withExtension: "json")
    else {
      throw SemanticStageConfigurationError.resourceUnavailable
    }
    return try Data(contentsOf: schema)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw SemanticStageConfigurationError.unsupportedVersion(configuration.schemaVersion)
      }
      guard Set(configuration.stages.map(\.id)).count == configuration.stages.count else {
        throw SemanticStageConfigurationError.duplicateStageID
      }
      let assignedTypes = configuration.stages.flatMap(\.types)
      guard Set(assignedTypes).count == assignedTypes.count else {
        throw SemanticStageConfigurationError.duplicateEntityType
      }
      guard Set(assignedTypes) == Set(EntityType.allCases) else {
        throw SemanticStageConfigurationError.missingEntityType
      }
      return configuration
    } catch let error as SemanticStageConfigurationError {
      throw error
    } catch {
      throw SemanticStageConfigurationError.invalid(String(describing: error))
    }
  }
}

public struct SemanticStageDefinition: Codable, Hashable, Sendable, Identifiable {
  public enum Tint: String, Codable, Hashable, Sendable {
    case indigo
    case blue
    case purple
    case cyan
    case green
    case orange
  }

  public let id: String
  public let title: String
  public let tint: Tint
  public let types: [EntityType]

  public init(id: String, title: String, tint: Tint, types: [EntityType]) {
    self.id = id
    self.title = title
    self.tint = tint
    self.types = types
  }
}

public enum SemanticStageConfigurationError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateStageID
  case duplicateEntityType
  case missingEntityType
  case invalid(String)
}
