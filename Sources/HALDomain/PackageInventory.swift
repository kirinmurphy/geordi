import Foundation

public struct HomebrewPackageValue: Hashable, Codable, Sendable {
  public let name: String
  public let versions: [String]

  public init(name: String, versions: [String]) {
    self.name = name
    self.versions = versions
  }
}

public struct HomebrewInventoryValue: Hashable, Codable, Sendable {
  public let prefix: String
  public let cellarPath: String
  public let packages: [HomebrewPackageValue]

  public init(prefix: String, cellarPath: String, packages: [HomebrewPackageValue]) {
    self.prefix = prefix
    self.cellarPath = cellarPath
    self.packages = packages
  }
}
