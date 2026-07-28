import Foundation

public enum PersistenceDeclarationKind: String, Hashable, Codable, Sendable {
  case launchAgent
  case launchDaemon
}

public struct PersistenceDeclarationValue: Hashable, Codable, Sendable {
  public let declarationPath: String
  public let kind: PersistenceDeclarationKind
  public let label: String
  public let programPath: String?
  public let runAtLoad: Bool
  public let keepAlive: Bool

  public init(
    declarationPath: String,
    kind: PersistenceDeclarationKind,
    label: String,
    programPath: String? = nil,
    runAtLoad: Bool,
    keepAlive: Bool
  ) {
    self.declarationPath = declarationPath
    self.kind = kind
    self.label = label
    self.programPath = programPath
    self.runAtLoad = runAtLoad
    self.keepAlive = keepAlive
  }
}

public struct PersistenceApplicationResolutionValue: Hashable, Codable, Sendable {
  public let declarationPath: String
  public let applicationPaths: [String]
  public let state: ProcessResolutionState
  public let confidence: Confidence?

  public init(
    declarationPath: String,
    applicationPaths: [String] = [],
    state: ProcessResolutionState,
    confidence: Confidence? = nil
  ) {
    self.declarationPath = declarationPath
    self.applicationPaths = applicationPaths
    self.state = state
    self.confidence = confidence
  }
}
