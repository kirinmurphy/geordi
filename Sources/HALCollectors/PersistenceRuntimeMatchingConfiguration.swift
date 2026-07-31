import Foundation
import HALDomain
import HALManifestKit

public struct PersistenceRuntimeMatchingConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let maximumMatchesPerDeclaration: Int
  public let strategies: [PersistenceRuntimeMatchingStrategy]
  public let outcomes: [PersistenceRuntimeOutcome]

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(
        forResource: "persistence-runtime-matching",
        withExtension: "json"
      ),
      let schemaURL = Bundle.module.url(
        forResource: "persistence-runtime-matching.schema",
        withExtension: "json"
      )
    else { throw PersistenceRuntimeMatchingError.resourceUnavailable }
    return try decode(Data(contentsOf: manifestURL), schema: Data(contentsOf: schemaURL))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let value = try JSONDecoder().decode(Self.self, from: data)
      guard value.schemaVersion == currentVersion else {
        throw PersistenceRuntimeMatchingError.unsupportedVersion(value.schemaVersion)
      }
      guard Set(value.strategies.map(\.id)).count == value.strategies.count else {
        throw PersistenceRuntimeMatchingError.duplicateStrategyID
      }
      return value
    } catch let error as PersistenceRuntimeMatchingError {
      throw error
    } catch {
      throw PersistenceRuntimeMatchingError.invalid(String(describing: error))
    }
  }
}

public struct PersistenceRuntimeMatchingStrategy: Codable, Hashable, Sendable {
  public let id: String
  public let priority: Int
  public let declarationIdentityField: String
  public let processIdentityField: String
  public let comparison: String
  public let applicableKinds: [PersistenceDeclarationKind]
  public let relationshipType: RelationshipType
  public let confidence: Confidence
  public let explanation: String
}

public struct PersistenceRuntimeOutcome: Codable, Hashable, Sendable {
  public let state: PersistenceRuntimeCorrelationState
  public let label: String
  public let explanation: String
}

public enum PersistenceRuntimeMatchingError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateStrategyID
  case invalid(String)
}
