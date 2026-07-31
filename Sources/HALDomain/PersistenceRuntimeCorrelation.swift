import Foundation

public enum PersistenceRuntimeCorrelationState: String, Hashable, Codable, Sendable {
  case matched
  case ambiguous
  case unmatched
  case partial
  case unavailable
  case permissionDenied
}

public struct PersistenceRuntimeCorrelationValue: Hashable, Codable, Sendable {
  public let declarationPath: String
  public let processIDs: [Int32]
  public let state: PersistenceRuntimeCorrelationState
  public let strategyID: String?
  public let confidence: Confidence?

  public init(
    declarationPath: String,
    processIDs: [Int32] = [],
    state: PersistenceRuntimeCorrelationState,
    strategyID: String? = nil,
    confidence: Confidence? = nil
  ) {
    self.declarationPath = declarationPath
    self.processIDs = processIDs
    self.state = state
    self.strategyID = strategyID
    self.confidence = confidence
  }
}
