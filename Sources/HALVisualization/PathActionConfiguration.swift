import Foundation
import HALManifestKit

public struct TerminalAdapterConfiguration: Codable, Sendable {
  public static let currentVersion = 1
  public let schemaVersion: Int
  public let adapters: [TerminalAdapter]

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "terminal-adapters", withExtension: "json"),
      let schema = Bundle.module.url(forResource: "terminal-adapters.schema", withExtension: "json")
    else { throw TerminalAdapterConfigurationError.resourceUnavailable }
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let value = try JSONDecoder().decode(Self.self, from: data)
      guard value.schemaVersion == currentVersion else {
        throw TerminalAdapterConfigurationError.unsupportedVersion(value.schemaVersion)
      }
      guard Set(value.adapters.map(\.id)).count == value.adapters.count else {
        throw TerminalAdapterConfigurationError.duplicateID
      }
      guard Set(value.adapters.map(\.bundleIdentifier)).count == value.adapters.count else {
        throw TerminalAdapterConfigurationError.duplicateBundleIdentifier
      }
      return value
    } catch let error as TerminalAdapterConfigurationError {
      throw error
    } catch {
      throw TerminalAdapterConfigurationError.invalid(String(describing: error))
    }
  }
}

public struct TerminalAdapter: Codable, Identifiable, Hashable, Sendable {
  public enum Strategy: String, Codable, Sendable {
    case workspaceOpen = "workspace-open"
  }

  public let id: String
  public let displayName: String
  public let bundleIdentifier: String
  public let strategy: Strategy
}

public enum TerminalAdapterConfigurationError: Error, Equatable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateID
  case duplicateBundleIdentifier
  case invalid(String)
}
