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
