import Foundation

public struct ApplicationBundleValue: Hashable, Codable, Sendable {
  public let path: String
  public let name: String
  public let bundleIdentifier: String?
  public let version: String?
  public let buildVersion: String?
  public let executableName: String?

  public init(
    path: String,
    name: String,
    bundleIdentifier: String? = nil,
    version: String? = nil,
    buildVersion: String? = nil,
    executableName: String? = nil
  ) {
    self.path = path
    self.name = name
    self.bundleIdentifier = bundleIdentifier
    self.version = version
    self.buildVersion = buildVersion
    self.executableName = executableName
  }
}

public enum CodeSignatureStatus: String, Hashable, Codable, Sendable {
  case valid
  case unsigned
  case invalid
  case unavailable
}

public struct ApplicationSignatureValue: Hashable, Codable, Sendable {
  public let applicationPath: String
  public let status: CodeSignatureStatus
  public let signingIdentifier: String?
  public let teamIdentifier: String?
  public let authorities: [String]
  public let platformBinary: Bool?
  public let statusCode: Int32?

  public init(
    applicationPath: String,
    status: CodeSignatureStatus,
    signingIdentifier: String? = nil,
    teamIdentifier: String? = nil,
    authorities: [String] = [],
    platformBinary: Bool? = nil,
    statusCode: Int32? = nil
  ) {
    self.applicationPath = applicationPath
    self.status = status
    self.signingIdentifier = signingIdentifier
    self.teamIdentifier = teamIdentifier
    self.authorities = authorities
    self.platformBinary = platformBinary
    self.statusCode = statusCode
  }
}

public enum ApplicationProvenanceKind: String, Hashable, Codable, Sendable {
  case appStoreReceipt
  case downloadOrigin
}

public enum ApplicationProvenanceStatus: String, Hashable, Codable, Sendable {
  case present
  case absent
  case unreadable
}

public struct ApplicationProvenanceFact: Hashable, Codable, Sendable {
  public let kind: ApplicationProvenanceKind
  public let displayLabel: String
  public let status: ApplicationProvenanceStatus
  public let source: String
  public let detail: String?

  public init(
    kind: ApplicationProvenanceKind,
    displayLabel: String,
    status: ApplicationProvenanceStatus,
    source: String,
    detail: String? = nil
  ) {
    self.kind = kind
    self.displayLabel = displayLabel
    self.status = status
    self.source = source
    self.detail = detail
  }
}

public struct ApplicationProvenanceValue: Hashable, Codable, Sendable {
  public let applicationPath: String
  public let facts: [ApplicationProvenanceFact]

  public init(applicationPath: String, facts: [ApplicationProvenanceFact]) {
    self.applicationPath = applicationPath
    self.facts = facts
  }
}

public enum AssociatedLocationStatus: String, Hashable, Codable, Sendable {
  case present
  case absent
  case permissionDenied
  case unreadable
}

public enum AssociatedLocationMatch: String, Hashable, Codable, Sendable {
  case bundleIdentifier
  case applicationName
}

public struct ApplicationAssociatedLocationValue: Hashable, Codable, Sendable {
  public let applicationPath: String
  public let locationID: String
  public let locationPath: String
  public let categoryLabel: String
  public let match: AssociatedLocationMatch
  public let status: AssociatedLocationStatus
  public let isDirectory: Bool?

  public init(
    applicationPath: String,
    locationID: String,
    locationPath: String,
    categoryLabel: String,
    match: AssociatedLocationMatch,
    status: AssociatedLocationStatus,
    isDirectory: Bool? = nil
  ) {
    self.applicationPath = applicationPath
    self.locationID = locationID
    self.locationPath = locationPath
    self.categoryLabel = categoryLabel
    self.match = match
    self.status = status
    self.isDirectory = isDirectory
  }
}
