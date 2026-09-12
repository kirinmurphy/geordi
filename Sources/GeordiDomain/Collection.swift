import Foundation

public enum CollectionEnvironment: String, Codable, Sendable {
  case synthetic
  case liveReadOnly
}

public enum CollectorAvailability: String, Codable, Sendable {
  case available
  case permissionDenied
  case unsupported
  case unavailable
}

public enum CollectorRunState: String, Codable, Sendable {
  case complete
  case partial
  case failed
  case skipped
}

public struct CollectionIssue: Identifiable, Hashable, Codable, Sendable {
  public enum Severity: String, Codable, Sendable {
    case information
    case warning
    case error
  }

  public let id: String
  public let severity: Severity
  public let summary: String
  public let affectedScope: String?

  public init(
    id: String,
    severity: Severity,
    summary: String,
    affectedScope: String? = nil
  ) {
    self.id = id
    self.severity = severity
    self.summary = summary
    self.affectedScope = affectedScope
  }
}

public struct CollectorRun: Hashable, Codable, Sendable {
  public let collectorID: CollectorID
  public let collectorVersion: Int
  public let availability: CollectorAvailability
  public let state: CollectorRunState
  public let startedAt: Date
  public let completedAt: Date?
  public let scope: [String]
  public let issues: [CollectionIssue]

  public init(
    collectorID: CollectorID,
    collectorVersion: Int,
    availability: CollectorAvailability,
    state: CollectorRunState,
    startedAt: Date,
    completedAt: Date? = nil,
    scope: [String] = [],
    issues: [CollectionIssue] = []
  ) {
    self.collectorID = collectorID
    self.collectorVersion = collectorVersion
    self.availability = availability
    self.state = state
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.scope = scope
    self.issues = issues
  }
}

public struct CollectorOutput<Value: Hashable & Codable & Sendable>:
  Hashable, Codable, Sendable
{
  public let run: CollectorRun
  public let observations: [CollectedObservation<Value>]

  public init(
    run: CollectorRun,
    observations: [CollectedObservation<Value>]
  ) {
    self.run = run
    self.observations = observations
  }
}

public struct ScanContext: Hashable, Codable, Sendable {
  public let id: ScanID
  public let environment: CollectionEnvironment
  public let startedAt: Date
  public let completedAt: Date?
  public let collectorRuns: [CollectorRun]

  public init(
    id: ScanID,
    environment: CollectionEnvironment,
    startedAt: Date,
    completedAt: Date? = nil,
    collectorRuns: [CollectorRun] = []
  ) {
    self.id = id
    self.environment = environment
    self.startedAt = startedAt
    self.completedAt = completedAt
    self.collectorRuns = collectorRuns
  }

  public var isPartial: Bool {
    completedAt == nil
      || collectorRuns.contains {
        $0.state != .complete || $0.availability != .available
      }
  }
}

public enum FreshnessState: String, Codable, Sendable {
  case fresh
  case aging
  case stale
  case partial
  case unavailable
  case permissionDenied
  case neverCollected
}

public struct FreshnessPolicy: Hashable, Codable, Sendable {
  public let agingAfter: TimeInterval
  public let staleAfter: TimeInterval

  public init(agingAfter: TimeInterval, staleAfter: TimeInterval) {
    precondition(agingAfter >= 0)
    precondition(staleAfter >= agingAfter)
    self.agingAfter = agingAfter
    self.staleAfter = staleAfter
  }

  public func state(for scan: ScanContext?, at currentDate: Date) -> FreshnessState {
    guard let scan else { return .neverCollected }
    if scan.collectorRuns.contains(where: { $0.availability == .permissionDenied }) {
      return .permissionDenied
    }
    if scan.collectorRuns.allSatisfy({
      $0.availability == .unsupported || $0.availability == .unavailable
    }), !scan.collectorRuns.isEmpty {
      return .unavailable
    }
    guard let completedAt = scan.completedAt else { return .partial }
    if scan.isPartial { return .partial }

    let age = max(0, currentDate.timeIntervalSince(completedAt))
    if age >= staleAfter { return .stale }
    if age >= agingAfter { return .aging }
    return .fresh
  }
}

public struct GraphSnapshot: Hashable, Codable, Sendable {
  public let graph: SystemGraph
  public let scan: ScanContext

  public init(graph: SystemGraph, scan: ScanContext) {
    self.graph = graph
    self.scan = scan
  }
}

public protocol GraphSnapshotProvider: Sendable {
  func snapshot() -> GraphSnapshot
}
