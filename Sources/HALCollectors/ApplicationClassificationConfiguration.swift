import Foundation
import HALDomain
import HALManifestKit

public struct ApplicationClassificationConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 7

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
      guard
        configuration.categories.contains(where: {
          $0.id == configuration.defaultCategoryID && $0.kind == .scope
        })
      else {
        throw ApplicationClassificationConfigurationError.unknownDefaultCategory
      }
      guard
        configuration.categories.filter({ $0.kind == .scope && $0.isFallback }).count == 1,
        configuration.categories.allSatisfy({ $0.kind == .scope || !$0.isFallback })
      else {
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
    details: [Detail] = [],
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> ApplicationClassificationCategory {
    let applicationURL = URL(filePath: path).standardizedFileURL
    let orderedCategories = categories.sorted {
      if $0.priority != $1.priority { return $0.priority > $1.priority }
      return $0.id < $1.id
    }
    for category in orderedCategories where category.kind == .scope && !category.isFallback {
      if let expected = category.platformBinaryWhenKnown {
        guard let platformBinary, expected == platformBinary else {
          continue
        }
      }
      let pathMatches =
        category.pathPrefixes.contains(where: {
          $0.matches(applicationURL, userHome: userHome)
        }) || category.pathPrefixes.isEmpty
      let detailsMatch = category.detailRules.allSatisfy { $0.matches(details) }
      let matches =
        category.matchMode == .all
        ? pathMatches && detailsMatch
        : (category.pathPrefixes.isEmpty ? false : pathMatches)
          || (category.detailRules.isEmpty ? false : detailsMatch)
      if matches {
        return category
      }
    }
    return categories.first { $0.kind == .scope && $0.isFallback }!
  }

  public func source(
    forApplicationPath path: String,
    platformBinary: Bool? = nil,
    details: [Detail] = [],
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> ApplicationClassificationCategory? {
    let applicationURL = URL(filePath: path).standardizedFileURL
    return
      categories
      .filter { $0.kind == .source }
      .sorted {
        if $0.priority != $1.priority { return $0.priority > $1.priority }
        return $0.id < $1.id
      }
      .first { category in
        if let expected = category.platformBinaryWhenKnown,
          platformBinary != expected
        {
          return false
        }
        let pathMatches =
          category.pathPrefixes.isEmpty
          || category.pathPrefixes.contains {
            $0.matches(applicationURL, userHome: userHome)
          }
        return pathMatches && category.detailRules.allSatisfy { $0.matches(details) }
      }
  }
}

public struct ApplicationClassificationCategory: Codable, Hashable, Sendable, Identifiable {
  public enum Kind: String, Codable, Hashable, Sendable {
    case scope
    case source
  }
  public enum MatchMode: String, Codable, Hashable, Sendable {
    case all
    case any
  }

  public let id: String
  public let kind: Kind
  public let label: String
  public let summary: String
  public let priority: Int
  public let isFallback: Bool
  public let platformBinaryWhenKnown: Bool?
  public let pathPrefixes: [ApplicationClassificationPathPrefix]
  public let detailRules: [ApplicationClassificationDetailRule]
  public let showsInSoftwareSources: Bool
  public let matchMode: MatchMode

  public init(
    id: String,
    kind: Kind = .scope,
    label: String,
    summary: String,
    priority: Int,
    isFallback: Bool,
    platformBinaryWhenKnown: Bool? = nil,
    pathPrefixes: [ApplicationClassificationPathPrefix],
    detailRules: [ApplicationClassificationDetailRule] = [],
    showsInSoftwareSources: Bool = false,
    matchMode: MatchMode = .all
  ) {
    self.id = id
    self.kind = kind
    self.label = label
    self.summary = summary
    self.priority = priority
    self.isFallback = isFallback
    self.platformBinaryWhenKnown = platformBinaryWhenKnown
    self.pathPrefixes = pathPrefixes
    self.detailRules = detailRules
    self.showsInSoftwareSources = showsInSoftwareSources
    self.matchMode = matchMode
  }
}

public struct ApplicationClassificationDetailRule: Codable, Hashable, Sendable {
  public let label: String
  public let equals: String?
  public let startsWith: String?
  public let oneOfValues: [String]?
  public let excludes: [String]

  public init(
    label: String,
    equals: String? = nil,
    startsWith: String? = nil,
    oneOfValues: [String]? = nil,
    excludes: [String] = []
  ) {
    self.label = label
    self.equals = equals
    self.startsWith = startsWith
    self.oneOfValues = oneOfValues
    self.excludes = excludes
  }

  fileprivate func matches(_ details: [Detail]) -> Bool {
    guard let value = details.first(where: { $0.label == label })?.value else {
      return false
    }
    if let equals, value != equals { return false }
    if let startsWith, !value.hasPrefix(startsWith) { return false }
    if let oneOfValues, !oneOfValues.contains(value) { return false }
    return !excludes.contains(value)
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
