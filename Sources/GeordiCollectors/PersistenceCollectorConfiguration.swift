import Foundation
import GeordiDomain
import GeordiManifestKit

public struct PersistenceCollectorConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let roots: [PersistenceRootConfiguration]

  public init(
    schemaVersion: Int = Self.currentVersion,
    roots: [PersistenceRootConfiguration]
  ) {
    self.schemaVersion = schemaVersion
    self.roots = roots
  }

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(
        forResource: "persistence-roots",
        withExtension: "json"
      ),
      let schemaURL = Bundle.module.url(
        forResource: "persistence-roots.schema",
        withExtension: "json"
      )
    else {
      throw PersistenceCollectorConfigurationError.resourceUnavailable
    }
    return try decode(
      Data(contentsOf: manifestURL),
      schema: Data(contentsOf: schemaURL)
    )
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schemaURL = Bundle.module.url(
        forResource: "persistence-roots.schema",
        withExtension: "json"
      )
    else {
      throw PersistenceCollectorConfigurationError.resourceUnavailable
    }
    return try Data(contentsOf: schemaURL)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw PersistenceCollectorConfigurationError.unsupportedVersion(
          configuration.schemaVersion
        )
      }
      guard Set(configuration.roots.map(\.id)).count == configuration.roots.count else {
        throw PersistenceCollectorConfigurationError.duplicateRootID
      }
      return configuration
    } catch let error as PersistenceCollectorConfigurationError {
      throw error
    } catch {
      throw PersistenceCollectorConfigurationError.invalid(String(describing: error))
    }
  }

  public func resolvedRoots(
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser
  ) throws -> [PersistenceSearchRoot] {
    try roots.map { try $0.resolved(userHome: userHome) }
  }
}

public struct PersistenceRootConfiguration: Codable, Hashable, Sendable {
  public let id: String
  public let path: String
  public let kind: PersistenceDeclarationKind
  public let scope: PersistenceDeclarationScope

  public init(
    id: String,
    path: String,
    kind: PersistenceDeclarationKind,
    scope: PersistenceDeclarationScope
  ) {
    self.id = id
    self.path = path
    self.kind = kind
    self.scope = scope
  }

  fileprivate func resolved(userHome: URL) throws -> PersistenceSearchRoot {
    let url: URL
    switch scope {
    case .system:
      guard path.hasPrefix("/"), !path.contains("$USER_HOME"), !path.contains("..") else {
        throw PersistenceCollectorConfigurationError.invalidPath(id)
      }
      url = URL(fileURLWithPath: path).standardizedFileURL
    case .user:
      let prefix = "$USER_HOME/"
      guard path.hasPrefix(prefix), !path.contains("..") else {
        throw PersistenceCollectorConfigurationError.invalidPath(id)
      }
      url = userHome.appending(path: String(path.dropFirst(prefix.count))).standardizedFileURL
      guard url.path.hasPrefix(userHome.standardizedFileURL.path + "/") else {
        throw PersistenceCollectorConfigurationError.invalidPath(id)
      }
    }
    return PersistenceSearchRoot(id: id, url: url, kind: kind, scope: scope)
  }
}

public struct PersistenceSearchRoot: Hashable, Sendable {
  public let id: String
  public let url: URL
  public let kind: PersistenceDeclarationKind
  public let scope: PersistenceDeclarationScope

  public init(
    id: String,
    url: URL,
    kind: PersistenceDeclarationKind,
    scope: PersistenceDeclarationScope = .user
  ) {
    self.id = id
    self.url = url
    self.kind = kind
    self.scope = scope
  }
}

public enum PersistenceCollectorConfigurationError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateRootID
  case invalidPath(String)
  case invalid(String)
}
