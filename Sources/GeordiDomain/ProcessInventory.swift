import Foundation

public enum ProcessAccessibility: String, Hashable, Codable, Sendable {
  case accessible
  case limited
  case inaccessible
}

public struct ProcessValue: Hashable, Codable, Sendable {
  public let pid: Int32
  public let parentPID: Int32?
  public let name: String
  public let executablePath: String?
  public let residentMemoryBytes: UInt64?
  public let startedAt: Date?
  public let accessibility: ProcessAccessibility

  public init(
    pid: Int32,
    parentPID: Int32? = nil,
    name: String,
    executablePath: String? = nil,
    residentMemoryBytes: UInt64? = nil,
    startedAt: Date? = nil,
    accessibility: ProcessAccessibility
  ) {
    self.pid = pid
    self.parentPID = parentPID
    self.name = name
    self.executablePath = executablePath
    self.residentMemoryBytes = residentMemoryBytes
    self.startedAt = startedAt
    self.accessibility = accessibility
  }
}

public enum ProcessResolutionState: String, Hashable, Codable, Sendable {
  case matched
  case ambiguous
  case unmatched
  case inaccessible
}

public struct ProcessApplicationResolutionValue: Hashable, Codable, Sendable {
  public let processID: Int32
  public let state: ProcessResolutionState
  public let applicationPaths: [String]
  public let strategyID: String?
  public let confidence: Confidence?

  public init(
    processID: Int32,
    state: ProcessResolutionState,
    applicationPaths: [String] = [],
    strategyID: String? = nil,
    confidence: Confidence? = nil
  ) {
    self.processID = processID
    self.state = state
    self.applicationPaths = applicationPaths
    self.strategyID = strategyID
    self.confidence = confidence
  }
}
