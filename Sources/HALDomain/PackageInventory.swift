import Foundation

public struct HomebrewPackageValue: Hashable, Codable, Sendable {
  public let name: String
  public let versions: [String]

  public init(name: String, versions: [String]) {
    self.name = name
    self.versions = versions
  }
}

public struct HomebrewCaskArtifactValue: Hashable, Codable, Sendable {
  public let applicationName: String
  public let bundleIdentifier: String?

  public init(applicationName: String, bundleIdentifier: String? = nil) {
    self.applicationName = applicationName
    self.bundleIdentifier = bundleIdentifier
  }
}

public struct HomebrewCaskValue: Hashable, Codable, Sendable {
  public let token: String
  public let versions: [String]
  public let artifacts: [HomebrewCaskArtifactValue]

  public init(
    token: String,
    versions: [String],
    artifacts: [HomebrewCaskArtifactValue]
  ) {
    self.token = token
    self.versions = versions
    self.artifacts = artifacts
  }
}

public struct HomebrewInventoryValue: Hashable, Codable, Sendable {
  public let prefix: String
  public let cellarPath: String
  public let caskroomPath: String
  public let packages: [HomebrewPackageValue]
  public let casks: [HomebrewCaskValue]

  public init(
    prefix: String,
    cellarPath: String,
    caskroomPath: String = "",
    packages: [HomebrewPackageValue],
    casks: [HomebrewCaskValue] = []
  ) {
    self.prefix = prefix
    self.cellarPath = cellarPath
    self.caskroomPath = caskroomPath
    self.packages = packages
    self.casks = casks
  }
}
