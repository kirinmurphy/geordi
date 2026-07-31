import Foundation

public enum RelationshipType: String, CaseIterable, Codable, Sendable {
  case owns
  case provides
  case launches
  case readsWrites = "reads and writes"
  case persistsThrough = "persists through"
  case consumes
  case contributesTo = "contributes to"
  case occurredNear = "occurred near"
  case mayBelongTo = "may belong to"
  case shares
  case observedRunning = "observed running"
}

public enum Confidence: String, CaseIterable, Codable, Comparable, Sendable {
  case possible
  case probable
  case high
  case confirmed
  case ambiguous

  public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
    order(lhs) < order(rhs)
  }

  private static func order(_ value: Confidence) -> Int {
    switch value {
    case .ambiguous: 0
    case .possible: 1
    case .probable: 2
    case .high: 3
    case .confirmed: 4
    }
  }

  public var plainLanguage: String {
    switch self {
    case .confirmed: "Observed fact"
    case .high: "Strong inference"
    case .probable: "Probable inference"
    case .possible: "Possible inference"
    case .ambiguous: "Unresolved"
    }
  }
}

public enum EvidenceKind: String, CaseIterable, Codable, Sendable {
  case observed
  case derived
  case inferred
}

public struct Evidence: Identifiable, Hashable, Codable, Sendable {
  public let id: String
  public let kind: EvidenceKind
  public let summary: String
  public let source: String
  public let observationID: ObservationID?
  public let observedAt: Date?
  public let ruleID: String?
  public let ruleVersion: Int?

  public init(
    id: String,
    kind: EvidenceKind,
    summary: String,
    source: String,
    observationID: ObservationID? = nil,
    observedAt: Date? = nil,
    ruleID: String? = nil,
    ruleVersion: Int? = nil
  ) {
    self.id = id
    self.kind = kind
    self.summary = summary
    self.source = source
    self.observationID = observationID
    self.observedAt = observedAt
    self.ruleID = ruleID
    self.ruleVersion = ruleVersion
  }
}

public struct FindingID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
}

public enum FindingState: String, Codable, Sendable {
  case active
  case dismissed
  case deferred
  case resolved
}

public struct Finding: Identifiable, Hashable, Codable, Sendable {
  public let id: FindingID
  public let ruleID: String
  public let ruleVersion: Int
  public let detectedAt: Date
  public let summary: String
  public let relatedEntities: [EntityID]
  public let confidence: Confidence
  public let evidence: [Evidence]
  public let state: FindingState

  public init(
    id: FindingID,
    ruleID: String,
    ruleVersion: Int,
    detectedAt: Date,
    summary: String,
    relatedEntities: [EntityID],
    confidence: Confidence,
    evidence: [Evidence],
    state: FindingState = .active
  ) {
    self.id = id
    self.ruleID = ruleID
    self.ruleVersion = ruleVersion
    self.detectedAt = detectedAt
    self.summary = summary
    self.relatedEntities = relatedEntities
    self.confidence = confidence
    self.evidence = evidence
    self.state = state
  }
}

public struct RelationshipID: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }
}

public struct Relationship: Identifiable, Hashable, Codable, Sendable {
  public let id: RelationshipID
  public let source: EntityID
  public let target: EntityID
  public let type: RelationshipType
  public let confidence: Confidence
  public let explanation: String
  public let evidence: [Evidence]

  public init(
    id: RelationshipID,
    source: EntityID,
    target: EntityID,
    type: RelationshipType,
    confidence: Confidence,
    explanation: String,
    evidence: [Evidence]
  ) {
    self.id = id
    self.source = source
    self.target = target
    self.type = type
    self.confidence = confidence
    self.explanation = explanation
    self.evidence = evidence
  }
}
