import Foundation
import HALDomain
import HALManifestKit

public struct ProcessCollectorConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let strategies: [ProcessResolutionStrategy]

  public init(
    schemaVersion: Int = Self.currentVersion,
    strategies: [ProcessResolutionStrategy]
  ) {
    self.schemaVersion = schemaVersion
    self.strategies = strategies
  }

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(
        forResource: "process-resolution-strategies",
        withExtension: "json"
      ),
      let schemaURL = Bundle.module.url(
        forResource: "process-resolution-strategies.schema",
        withExtension: "json"
      )
    else {
      throw ProcessCollectorConfigurationError.resourceUnavailable
    }
    return try decode(
      Data(contentsOf: manifestURL),
      schema: Data(contentsOf: schemaURL)
    )
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schemaURL = Bundle.module.url(
        forResource: "process-resolution-strategies.schema",
        withExtension: "json"
      )
    else {
      throw ProcessCollectorConfigurationError.resourceUnavailable
    }
    return try Data(contentsOf: schemaURL)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw ProcessCollectorConfigurationError.unsupportedVersion(
          configuration.schemaVersion
        )
      }
      guard Set(configuration.strategies.map(\.id)).count == configuration.strategies.count else {
        throw ProcessCollectorConfigurationError.duplicateStrategyID
      }
      return configuration
    } catch let error as ProcessCollectorConfigurationError {
      throw error
    } catch {
      throw ProcessCollectorConfigurationError.invalid(String(describing: error))
    }
  }
}

public struct ProcessResolutionStrategy: Codable, Hashable, Sendable {
  public enum Kind: String, Codable, Hashable, Sendable {
    case exactMainExecutable
    case containedInApplicationBundle
  }

  public let id: String
  public let kind: Kind
  public let confidence: Confidence
  public let priority: Int

  public init(id: String, kind: Kind, confidence: Confidence, priority: Int) {
    self.id = id
    self.kind = kind
    self.confidence = confidence
    self.priority = priority
  }
}

public enum ProcessCollectorConfigurationError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateStrategyID
  case invalid(String)
}
