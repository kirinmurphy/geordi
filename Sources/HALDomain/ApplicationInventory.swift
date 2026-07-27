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
