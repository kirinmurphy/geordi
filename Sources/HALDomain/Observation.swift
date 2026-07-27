import Foundation

public struct ScanID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
}

public struct ObservationID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
}

public struct CollectorID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
}

public enum DataSensitivity: String, Codable, Sendable {
  case ordinary
  case privateMetadata
  case sensitive
  case redacted
}

public enum IdentityKind: String, Codable, Sendable {
  case bundleIdentifier
  case signingIdentifier
  case teamIdentifier
  case canonicalPath
  case packageIdentifier
  case executable
  case processInstance
  case collectorLocal
}

public struct IdentityClaim: Hashable, Codable, Sendable {
  public let kind: IdentityKind
  public let value: String
  public let namespace: String?

  public init(kind: IdentityKind, value: String, namespace: String? = nil) {
    self.kind = kind
    self.value = value
    self.namespace = namespace
  }
}

public struct SubjectIdentity: Hashable, Codable, Sendable {
  public let primary: IdentityClaim
  public let aliases: [IdentityClaim]

  public init(primary: IdentityClaim, aliases: [IdentityClaim] = []) {
    self.primary = primary
    self.aliases = aliases
  }
}

public struct CollectedObservation<Value: Hashable & Codable & Sendable>:
  Identifiable, Hashable, Codable, Sendable
{
  public let id: ObservationID
  public let scanID: ScanID
  public let collectorID: CollectorID
  public let schemaVersion: Int
  public let observedAt: Date
  public let subject: SubjectIdentity
  public let sensitivity: DataSensitivity
  public let sourceReference: String?
  public let value: Value

  public init(
    id: ObservationID,
    scanID: ScanID,
    collectorID: CollectorID,
    schemaVersion: Int,
    observedAt: Date,
    subject: SubjectIdentity,
    sensitivity: DataSensitivity = .ordinary,
    sourceReference: String? = nil,
    value: Value
  ) {
    self.id = id
    self.scanID = scanID
    self.collectorID = collectorID
    self.schemaVersion = schemaVersion
    self.observedAt = observedAt
    self.subject = subject
    self.sensitivity = sensitivity
    self.sourceReference = sourceReference
    self.value = value
  }
}

public protocol HALClock: Sendable {
  func now() -> Date
}

public struct SystemClock: HALClock {
  public init() {}

  public func now() -> Date {
    Date()
  }
}

public struct FixedClock: HALClock {
  public let date: Date

  public init(_ date: Date) {
    self.date = date
  }

  public func now() -> Date {
    date
  }
}
