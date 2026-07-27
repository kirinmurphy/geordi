import Foundation

public enum EnvironmentMode: String, Sendable {
  case synthetic
}

public struct LayoutConfiguration: Hashable, Sendable {
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

public struct AppConfiguration: Hashable, Sendable {
  public let environment: EnvironmentMode
  public let initialFixtureID: String
  public let reducedMotion: Bool
  public let showDebugEvidence: Bool
  public let layout: LayoutConfiguration

  public init(
    environment: EnvironmentMode,
    initialFixtureID: String,
    reducedMotion: Bool,
    showDebugEvidence: Bool,
    layout: LayoutConfiguration
  ) {
    self.environment = environment
    self.initialFixtureID = initialFixtureID
    self.reducedMotion = reducedMotion
    self.showDebugEvidence = showDebugEvidence
    self.layout = layout
  }

  public static let phaseZero = AppConfiguration(
    environment: .synthetic,
    initialFixtureID: "familiar-mac",
    reducedMotion: false,
    showDebugEvidence: true,
    layout: LayoutConfiguration(
      columnSpacing: 240,
      rowSpacing: 128,
      nodeWidth: 174,
      nodeHeight: 70,
      minimumScale: 0.45,
      maximumScale: 2.4
    )
  )
}

public enum ConfigurationError: Error, Equatable {
  case overlappingLayout
  case invalidScaleRange
}
