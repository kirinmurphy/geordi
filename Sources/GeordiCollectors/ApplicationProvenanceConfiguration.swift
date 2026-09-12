import Foundation
import GeordiDomain
import GeordiManifestKit

public struct ApplicationProvenanceConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 3

  public let schemaVersion: Int
  public let adapters: [ApplicationProvenanceAdapterConfiguration]

  public init(
    schemaVersion: Int = Self.currentVersion,
    adapters: [ApplicationProvenanceAdapterConfiguration]
  ) {
    self.schemaVersion = schemaVersion
    self.adapters = adapters
  }

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(
        forResource: "application-provenance-adapters",
        withExtension: "json"
      ),
      let schemaURL = Bundle.module.url(
        forResource: "application-provenance-adapters.schema",
        withExtension: "json"
      )
    else {
      throw ApplicationProvenanceConfigurationError.resourceUnavailable
    }
    return try decode(
      Data(contentsOf: manifestURL),
      schema: Data(contentsOf: schemaURL)
    )
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schemaURL = Bundle.module.url(
        forResource: "application-provenance-adapters.schema",
        withExtension: "json"
      )
    else {
      throw ApplicationProvenanceConfigurationError.resourceUnavailable
    }
    return try Data(contentsOf: schemaURL)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw ApplicationProvenanceConfigurationError.unsupportedVersion(
          configuration.schemaVersion
        )
      }
      guard Set(configuration.adapters.map(\.id)).count == configuration.adapters.count else {
        throw ApplicationProvenanceConfigurationError.duplicateAdapterID
      }
      return configuration
    } catch let error as ApplicationProvenanceConfigurationError {
      throw error
    } catch {
      throw ApplicationProvenanceConfigurationError.invalid(String(describing: error))
    }
  }
}

public struct ApplicationProvenanceAdapterConfiguration: Codable, Hashable, Sendable {
  public let id: String
  public let kind: ApplicationProvenanceKind
  public let displayLabel: String

  public init(
    id: String,
    kind: ApplicationProvenanceKind,
    displayLabel: String
  ) {
    self.id = id
    self.kind = kind
    self.displayLabel = displayLabel
  }
}

public enum ApplicationProvenanceConfigurationError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateAdapterID
  case invalid(String)
}
