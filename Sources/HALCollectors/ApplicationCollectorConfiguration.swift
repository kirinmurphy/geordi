import Foundation
import HALManifestKit

public struct ApplicationCollectorConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let roots: [ApplicationSearchRootConfiguration]

  public init(
    schemaVersion: Int = Self.currentVersion,
    roots: [ApplicationSearchRootConfiguration]
  ) {
    self.schemaVersion = schemaVersion
    self.roots = roots
  }

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(
        forResource: "application-search-roots",
        withExtension: "json"
      ),
      let schemaURL = Bundle.module.url(
        forResource: "application-search-roots.schema",
        withExtension: "json"
      )
    else {
      throw ApplicationCollectorConfigurationError.resourceUnavailable
    }
    return try decode(
      Data(contentsOf: manifestURL),
      schema: Data(contentsOf: schemaURL)
    )
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schemaURL = Bundle.module.url(
        forResource: "application-search-roots.schema",
        withExtension: "json"
      )
    else {
      throw ApplicationCollectorConfigurationError.resourceUnavailable
    }
    return try Data(contentsOf: schemaURL)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw ApplicationCollectorConfigurationError.unsupportedVersion(
          configuration.schemaVersion
        )
      }
      guard Set(configuration.roots.map(\.id)).count == configuration.roots.count else {
        throw ApplicationCollectorConfigurationError.duplicateRootID
      }
      return configuration
    } catch let error as ApplicationCollectorConfigurationError {
      throw error
    } catch {
      throw ApplicationCollectorConfigurationError.invalid(String(describing: error))
    }
  }

  public func searchRoots(
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser
  ) throws -> [ApplicationSearchRoot] {
    try roots.map { root in
      ApplicationSearchRoot(
        url: try root.resolvedURL(userHome: userHome),
        required: root.required
      )
    }
  }
}

public struct ApplicationSearchRootConfiguration: Codable, Hashable, Sendable {
  public enum Scope: String, Codable, Hashable, Sendable {
    case system
    case user
  }

  public let id: String
  public let path: String
  public let required: Bool
  public let scope: Scope

  public init(id: String, path: String, required: Bool, scope: Scope) {
    self.id = id
    self.path = path
    self.required = required
    self.scope = scope
  }

  fileprivate func resolvedURL(userHome: URL) throws -> URL {
    switch scope {
    case .system:
      guard path.hasPrefix("/"), !path.contains("$USER_HOME") else {
        throw ApplicationCollectorConfigurationError.invalidPath(id)
      }
      return URL(filePath: path).standardizedFileURL
    case .user:
      let prefix = "$USER_HOME/"
      guard path.hasPrefix(prefix) else {
        throw ApplicationCollectorConfigurationError.invalidPath(id)
      }
      let relativePath = String(path.dropFirst(prefix.count))
      guard
        !relativePath.isEmpty,
        !relativePath.split(separator: "/").contains("..")
      else {
        throw ApplicationCollectorConfigurationError.invalidPath(id)
      }
      return userHome.appending(path: relativePath).standardizedFileURL
    }
  }
}

public enum ApplicationCollectorConfigurationError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateRootID
  case invalidPath(String)
  case invalid(String)
}
