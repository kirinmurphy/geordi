import Foundation

public enum ShellFrameworkInstallationStatus: String, Hashable, Codable, Sendable {
  case observed
  case absent
  case unreadable
  case ambiguous
}

public enum ShellFrameworkConfigurationStatus: String, Hashable, Codable, Sendable {
  case active
  case inactive
  case unreadable
  case absent
}

public struct ShellFrameworkValue: Hashable, Codable, Sendable {
  public let frameworkID: String
  public let label: String
  public let rootPath: String
  public let installationStatus: ShellFrameworkInstallationStatus
  public let configurationPath: String
  public let configurationStatus: ShellFrameworkConfigurationStatus
  public let repositoryHost: String?

  public init(
    frameworkID: String,
    label: String,
    rootPath: String,
    installationStatus: ShellFrameworkInstallationStatus,
    configurationPath: String,
    configurationStatus: ShellFrameworkConfigurationStatus,
    repositoryHost: String? = nil
  ) {
    self.frameworkID = frameworkID
    self.label = label
    self.rootPath = rootPath
    self.installationStatus = installationStatus
    self.configurationPath = configurationPath
    self.configurationStatus = configurationStatus
    self.repositoryHost = repositoryHost
  }
}
