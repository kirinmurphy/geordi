import Foundation

public struct RuntimeValue: Hashable, Codable, Sendable {
  public let runtimeID: String
  public let label: String
  public let kind: String
  public let packageIdentities: [RuntimePackageIdentityValue]
  public let executablePath: String
  public let resolvedExecutablePath: String
  public let version: String?

  public init(
    runtimeID: String,
    label: String,
    kind: String,
    packageIdentities: [RuntimePackageIdentityValue],
    executablePath: String,
    resolvedExecutablePath: String,
    version: String?
  ) {
    self.runtimeID = runtimeID
    self.label = label
    self.kind = kind
    self.packageIdentities = packageIdentities
    self.executablePath = executablePath
    self.resolvedExecutablePath = resolvedExecutablePath
    self.version = version
  }
}

public struct RuntimePackageIdentityValue: Hashable, Codable, Sendable {
  public let managerID: String
  public let packageName: String

  public init(managerID: String, packageName: String) {
    self.managerID = managerID
    self.packageName = packageName
  }
}
