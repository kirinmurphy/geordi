import Foundation

public struct CommandLineSoftwareValue: Hashable, Codable, Sendable {
  public let name: String
  public let executablePath: String
  public let resolvedExecutablePath: String
  public let sourceID: String
  public let sourceLabel: String
  public let packageManagerID: String?
  public let packageName: String?

  public init(
    name: String,
    executablePath: String,
    resolvedExecutablePath: String,
    sourceID: String,
    sourceLabel: String,
    packageManagerID: String? = nil,
    packageName: String? = nil
  ) {
    self.name = name
    self.executablePath = executablePath
    self.resolvedExecutablePath = resolvedExecutablePath
    self.sourceID = sourceID
    self.sourceLabel = sourceLabel
    self.packageManagerID = packageManagerID
    self.packageName = packageName
  }
}
