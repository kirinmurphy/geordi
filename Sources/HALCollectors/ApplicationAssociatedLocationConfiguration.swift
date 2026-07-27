import Foundation
import HALDomain
import HALManifestKit

public struct ApplicationAssociatedLocationConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let locations: [AssociatedLocationConfiguration]

  public init(
    schemaVersion: Int = Self.currentVersion,
    locations: [AssociatedLocationConfiguration]
  ) {
    self.schemaVersion = schemaVersion
    self.locations = locations
  }

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(
        forResource: "application-associated-locations",
        withExtension: "json"
      ),
      let schemaURL = Bundle.module.url(
        forResource: "application-associated-locations.schema",
        withExtension: "json"
      )
    else {
      throw ApplicationAssociatedLocationConfigurationError.resourceUnavailable
    }
    return try decode(
      Data(contentsOf: manifestURL),
      schema: Data(contentsOf: schemaURL)
    )
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schemaURL = Bundle.module.url(
        forResource: "application-associated-locations.schema",
        withExtension: "json"
      )
    else {
      throw ApplicationAssociatedLocationConfigurationError.resourceUnavailable
    }
    return try Data(contentsOf: schemaURL)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw ApplicationAssociatedLocationConfigurationError.unsupportedVersion(
          configuration.schemaVersion
        )
      }
      guard Set(configuration.locations.map(\.id)).count == configuration.locations.count else {
        throw ApplicationAssociatedLocationConfigurationError.duplicateLocationID
      }
      for location in configuration.locations {
        try location.validate()
      }
      return configuration
    } catch let error as ApplicationAssociatedLocationConfigurationError {
      throw error
    } catch {
      throw ApplicationAssociatedLocationConfigurationError.invalid(String(describing: error))
    }
  }
}

public struct AssociatedLocationConfiguration: Codable, Hashable, Sendable {
  public let id: String
  public let categoryLabel: String
  public let pathTemplate: String
  public let match: AssociatedLocationMatch

  public init(
    id: String,
    categoryLabel: String,
    pathTemplate: String,
    match: AssociatedLocationMatch
  ) {
    self.id = id
    self.categoryLabel = categoryLabel
    self.pathTemplate = pathTemplate
    self.match = match
  }

  fileprivate func validate() throws {
    guard pathTemplate.hasPrefix("$USER_HOME/"), !pathTemplate.contains("..") else {
      throw ApplicationAssociatedLocationConfigurationError.invalidPath(id)
    }
    let requiredToken =
      switch match {
      case .bundleIdentifier: "$BUNDLE_ID"
      case .applicationName: "$APP_NAME"
      }
    guard pathTemplate.contains(requiredToken) else {
      throw ApplicationAssociatedLocationConfigurationError.missingMatchToken(id)
    }
    let tokenStripped =
      pathTemplate
      .replacingOccurrences(of: "$USER_HOME", with: "")
      .replacingOccurrences(of: "$BUNDLE_ID", with: "")
      .replacingOccurrences(of: "$APP_NAME", with: "")
    guard !tokenStripped.contains("$") else {
      throw ApplicationAssociatedLocationConfigurationError.invalidPath(id)
    }
  }

  func resolvedURL(
    application: ApplicationBundleValue,
    userHome: URL
  ) throws -> URL? {
    let component: String?
    switch match {
    case .bundleIdentifier:
      component = application.bundleIdentifier
    case .applicationName:
      component = application.name
    }
    guard let component else { return nil }
    guard
      !component.isEmpty,
      component != ".",
      component != "..",
      !component.contains("/"),
      !component.contains("\0")
    else {
      throw ApplicationAssociatedLocationConfigurationError.unsafeMatchValue(id)
    }
    let prefix = "$USER_HOME/"
    let relative = String(pathTemplate.dropFirst(prefix.count))
      .replacingOccurrences(
        of: match == .bundleIdentifier ? "$BUNDLE_ID" : "$APP_NAME",
        with: component
      )
    let resolved = userHome.appending(path: relative).standardizedFileURL
    guard resolved.path.hasPrefix(userHome.standardizedFileURL.path + "/") else {
      throw ApplicationAssociatedLocationConfigurationError.invalidPath(id)
    }
    return resolved
  }
}

public enum ApplicationAssociatedLocationConfigurationError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateLocationID
  case invalidPath(String)
  case missingMatchToken(String)
  case unsafeMatchValue(String)
  case invalid(String)
}
