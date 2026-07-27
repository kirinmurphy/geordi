import Foundation

public enum RelationshipType: String, CaseIterable, Codable, Sendable {
  case owns
  case launches
  case readsWrites = "reads and writes"
  case persistsThrough = "persists through"
  case consumes
  case contributesTo = "contributes to"
  case occurredNear = "occurred near"
  case mayBelongTo = "may belong to"
  case shares
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

public enum EvidenceKind: String, Codable, Sendable {
  case observed
  case inferred
}

public struct Evidence: Identifiable, Hashable, Codable, Sendable {
  public let id: String
  public let kind: EvidenceKind
  public let summary: String
  public let source: String

  public init(id: String, kind: EvidenceKind, summary: String, source: String) {
    self.id = id
    self.kind = kind
    self.summary = summary
    self.source = source
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
