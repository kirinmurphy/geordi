import Foundation
import HALManifestKit

public struct ApplicationClassificationConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 2

  public let schemaVersion: Int
  public let allApplicationsLabel: String
  public let defaultCategoryID: String
  public let categories: [ApplicationClassificationCategory]

  public init(
    schemaVersion: Int = Self.currentVersion,
    allApplicationsLabel: String,
    defaultCategoryID: String,
    categories: [ApplicationClassificationCategory]
  ) {
    self.schemaVersion = schemaVersion
    self.allApplicationsLabel = allApplicationsLabel
    self.defaultCategoryID = defaultCategoryID
    self.categories = categories
  }

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(
        forResource: "application-classifications",
        withExtension: "json"
      ),
      let schemaURL = Bundle.module.url(
        forResource: "application-classifications.schema",
        withExtension: "json"
      )
    else {
      throw ApplicationClassificationConfigurationError.resourceUnavailable
    }
    return try decode(Data(contentsOf: manifestURL), schema: Data(contentsOf: schemaURL))
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schemaURL = Bundle.module.url(
        forResource: "application-classifications.schema",
        withExtension: "json"
      )
    else {
      throw ApplicationClassificationConfigurationError.resourceUnavailable
    }
    return try Data(contentsOf: schemaURL)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw ApplicationClassificationConfigurationError.unsupportedVersion(
          configuration.schemaVersion
        )
      }
      guard Set(configuration.categories.map(\.id)).count == configuration.categories.count else {
        throw ApplicationClassificationConfigurationError.duplicateCategoryID
      }
      guard configuration.categories.contains(where: { $0.id == configuration.defaultCategoryID })
      else {
        throw ApplicationClassificationConfigurationError.unknownDefaultCategory
      }
      guard configuration.categories.filter(\.isFallback).count == 1 else {
        throw ApplicationClassificationConfigurationError.invalidFallbackCount
      }
      for category in configuration.categories {
        for rule in category.pathPrefixes {
          try rule.validate(categoryID: category.id)
        }
      }
      return configuration
    } catch let error as ApplicationClassificationConfigurationError {
      throw error
    } catch {
      throw ApplicationClassificationConfigurationError.invalid(String(describing: error))
    }
  }

  public func category(
    forApplicationPath path: String,
    platformBinary: Bool? = nil,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> ApplicationClassificationCategory {
    let applicationURL = URL(filePath: path).standardizedFileURL
    let orderedCategories = categories.sorted {
      if $0.priority != $1.priority { return $0.priority > $1.priority }
      return $0.id < $1.id
    }
    for category in orderedCategories where !category.isFallback {
      if let expected = category.platformBinaryWhenKnown,
        let platformBinary,
        expected != platformBinary
      {
        continue
      }
      if category.pathPrefixes.contains(where: {
        $0.matches(applicationURL, userHome: userHome)
      }) {
        return category
      }
    }
    return categories.first(where: \.isFallback)!
  }
}

public struct ApplicationClassificationCategory: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let label: String
  public let summary: String
  public let priority: Int
  public let isFallback: Bool
  public let platformBinaryWhenKnown: Bool?
  public let pathPrefixes: [ApplicationClassificationPathPrefix]

  public init(
    id: String,
    label: String,
    summary: String,
    priority: Int,
    isFallback: Bool,
    platformBinaryWhenKnown: Bool? = nil,
    pathPrefixes: [ApplicationClassificationPathPrefix]
  ) {
    self.id = id
    self.label = label
    self.summary = summary
    self.priority = priority
    self.isFallback = isFallback
    self.platformBinaryWhenKnown = platformBinaryWhenKnown
    self.pathPrefixes = pathPrefixes
  }
}

public struct ApplicationClassificationPathPrefix: Codable, Hashable, Sendable {
  public enum Scope: String, Codable, Hashable, Sendable {
    case system
    case user
  }

  public let path: String
  public let scope: Scope

  public init(path: String, scope: Scope) {
    self.path = path
    self.scope = scope
  }

  fileprivate func validate(categoryID: String) throws {
    switch scope {
    case .system:
      guard path.hasPrefix("/"), !path.contains("$USER_HOME") else {
        throw ApplicationClassificationConfigurationError.invalidPath(categoryID)
      }
    case .user:
      guard
        path.hasPrefix("$USER_HOME/"),
        !path.split(separator: "/").contains("..")
      else {
        throw ApplicationClassificationConfigurationError.invalidPath(categoryID)
      }
    }
  }

  fileprivate func matches(_ applicationURL: URL, userHome: URL) -> Bool {
    let prefixURL: URL
    switch scope {
    case .system:
      prefixURL = URL(filePath: path).standardizedFileURL
    case .user:
      let relativePath = String(path.dropFirst("$USER_HOME/".count))
      prefixURL = userHome.appending(path: relativePath).standardizedFileURL
    }
    let applicationPath = applicationURL.path
    let prefixPath = prefixURL.path
    return applicationPath == prefixPath || applicationPath.hasPrefix(prefixPath + "/")
  }
}

public enum ApplicationClassificationConfigurationError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateCategoryID
  case unknownDefaultCategory
  case invalidFallbackCount
  case invalidPath(String)
  case invalid(String)
}
