import Foundation

public struct ManagedPackageValue: Hashable, Codable, Sendable {
  public let name: String
  public let version: String?
  public let path: String

  public init(name: String, version: String?, path: String) {
    self.name = name
    self.version = version
    self.path = path
  }
}

public struct PackageEcosystemInventoryValue: Hashable, Codable, Sendable {
  public let managerID: String
  public let managerLabel: String
  public let packages: [ManagedPackageValue]

  public init(managerID: String, managerLabel: String, packages: [ManagedPackageValue]) {
    self.managerID = managerID
    self.managerLabel = managerLabel
    self.packages = packages
  }
}
