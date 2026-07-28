import Foundation

public enum EntityType: String, CaseIterable, Codable, Sendable {
  case application
  case process
  case file
  case persistence
  case resource
  case incident
  case event
  case packageManager
  case shellFramework
  case package

  public var label: String {
    switch self {
    case .application: "Applications"
    case .process: "Processes"
    case .file: "Files"
    case .persistence: "Persistence"
    case .resource: "Resources"
    case .incident: "Incidents"
    case .event: "Events"
    case .packageManager: "Package managers"
    case .shellFramework: "Shell frameworks"
    case .package: "Packages"
    }
  }
}

public struct EntityID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
}

public struct Entity: Identifiable, Hashable, Codable, Sendable {
  public let id: EntityID
  public let type: EntityType
  public let name: String
  public let summary: String
  public let details: [Detail]
  public let presentation: EntityPresentation?

  public init(
    id: EntityID,
    type: EntityType,
    name: String,
    summary: String,
    details: [Detail] = [],
    presentation: EntityPresentation? = nil
  ) {
    self.id = id
    self.type = type
    self.name = name
    self.summary = summary
    self.details = details
    self.presentation = presentation
  }
}

public enum EntityPresentationTint: String, CaseIterable, Codable, Sendable {
  case accent
  case blue
  case cyan
  case green
  case mint
  case orange
  case purple
  case red
}

public struct EntityPresentation: Hashable, Codable, Sendable {
  public let symbol: String
  public let tint: EntityPresentationTint
  public let subtitle: String?
  public let trailingDetailLabel: String?

  public init(
    symbol: String,
    tint: EntityPresentationTint = .accent,
    subtitle: String? = nil,
    trailingDetailLabel: String? = nil
  ) {
    self.symbol = symbol
    self.tint = tint
    self.subtitle = subtitle
    self.trailingDetailLabel = trailingDetailLabel
  }
}

public struct Detail: Identifiable, Hashable, Codable, Sendable {
  public var id: String { label }
  public let label: String
  public let value: String

  public init(_ label: String, _ value: String) {
    self.label = label
    self.value = value
  }
}
