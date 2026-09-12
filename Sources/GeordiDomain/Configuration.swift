import Foundation
import GeordiManifestKit

/// Product-facing code imports GeordiDomain, so expose the canonical brand here
/// without maintaining a second name constant.
public typealias AppBrand = ProductBrand

public enum EnvironmentMode: String, Codable, Sendable {
  case synthetic
  case liveReadOnly
}

public struct LayoutConfiguration: Codable, Hashable, Sendable {
  public let columnSpacing: Double
  public let rowSpacing: Double
  public let nodeWidth: Double
  public let nodeHeight: Double
  public let minimumScale: Double
  public let maximumScale: Double

  public init(
    columnSpacing: Double,
    rowSpacing: Double,
    nodeWidth: Double,
    nodeHeight: Double,
    minimumScale: Double,
    maximumScale: Double
  ) {
    self.columnSpacing = columnSpacing
    self.rowSpacing = rowSpacing
    self.nodeWidth = nodeWidth
    self.nodeHeight = nodeHeight
    self.minimumScale = minimumScale
    self.maximumScale = maximumScale
  }

  public func validate() throws {
    guard columnSpacing > nodeWidth, rowSpacing > nodeHeight else {
      throw ConfigurationError.overlappingLayout
    }
    guard minimumScale > 0, maximumScale >= minimumScale else {
      throw ConfigurationError.invalidScaleRange
    }
  }
}

public struct FreshnessConfiguration: Codable, Hashable, Sendable {
  public let agingAfterSeconds: Int
  public let staleAfterSeconds: Int

  public init(agingAfterSeconds: Int, staleAfterSeconds: Int) {
    self.agingAfterSeconds = agingAfterSeconds
    self.staleAfterSeconds = staleAfterSeconds
  }

  public func validate() throws {
    guard agingAfterSeconds > 0, staleAfterSeconds >= agingAfterSeconds else {
      throw ConfigurationError.invalidFreshnessRange
    }
  }
}

public struct AppConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let environment: EnvironmentMode
  public let initialFixtureID: String
  public let reducedMotion: Bool
  public let showDebugEvidence: Bool
  public let layout: LayoutConfiguration
  public let freshness: FreshnessConfiguration
  public let destinations: [DestinationConfiguration]

  public init(
    schemaVersion: Int = Self.currentVersion,
    environment: EnvironmentMode,
    initialFixtureID: String,
    reducedMotion: Bool,
    showDebugEvidence: Bool,
    layout: LayoutConfiguration,
    freshness: FreshnessConfiguration,
    destinations: [DestinationConfiguration]
  ) {
    self.schemaVersion = schemaVersion
    self.environment = environment
    self.initialFixtureID = initialFixtureID
    self.reducedMotion = reducedMotion
    self.showDebugEvidence = showDebugEvidence
    self.layout = layout
    self.freshness = freshness
    self.destinations = destinations
  }

  public static func bundled() throws -> Self {
    try BundledManifestResource<Self>(
      manifestName: "app-profile",
      schemaName: "app-profile.schema",
      bundle: .module
    ).load { profile in
      guard profile.schemaVersion == currentVersion else {
        throw ConfigurationError.unsupportedVersion(profile.schemaVersion)
      }
      try profile.layout.validate()
      try profile.freshness.validate()
      guard Set(profile.destinations.map(\.id)).count == profile.destinations.count else {
        throw ConfigurationError.duplicateDestination
      }
    }
  }

  public static var phaseZero: Self {
    do {
      return try bundled()
    } catch {
      preconditionFailure("Required application profile failed validation: \(error)")
    }
  }
}

public struct DestinationConfiguration: Codable, Hashable, Sendable {
  public let id: String
  public let breadcrumb: [String]
  public let entityTypes: Set<EntityType>
  public let explorationContextID: String?
  public let syntheticFocusEntityID: String?
  public let syntheticNeighborhoodDepth: Int?

  public init(
    id: String,
    breadcrumb: [String],
    entityTypes: Set<EntityType>,
    explorationContextID: String? = nil,
    syntheticFocusEntityID: String? = nil,
    syntheticNeighborhoodDepth: Int? = nil
  ) {
    self.id = id
    self.breadcrumb = breadcrumb
    self.entityTypes = entityTypes
    self.explorationContextID = explorationContextID
    self.syntheticFocusEntityID = syntheticFocusEntityID
    self.syntheticNeighborhoodDepth = syntheticNeighborhoodDepth
  }
}

extension AppConfiguration {
  public func destination(_ id: String) -> DestinationConfiguration? {
    destinations.first { $0.id == id }
  }
}

public enum ConfigurationError: Error, Equatable {
  case unsupportedVersion(Int)
  case overlappingLayout
  case invalidScaleRange
  case invalidFreshnessRange
  case duplicateDestination
}
