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

  public init(
    id: EntityID,
    type: EntityType,
    name: String,
    summary: String,
    details: [Detail] = []
  ) {
    self.id = id
    self.type = type
    self.name = name
    self.summary = summary
    self.details = details
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
