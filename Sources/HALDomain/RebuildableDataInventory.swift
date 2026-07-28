import Foundation

public enum Rebuildability: String, Codable, Hashable, Sendable {
  case rebuildable
  case redownloadable
  case unknown
}

public enum RebuildableDataStatus: String, Codable, Hashable, Sendable {
  case present
  case absent
  case permissionDenied
  case unreadable
}

public struct RebuildableDataValue: Codable, Hashable, Sendable {
  public let detectorID: String
  public let locationID: String
  public let path: String
  public let classificationID: String
  public let classificationLabel: String
  public let rebuildability: Rebuildability
  public let evidenceRuleID: String
  public let evidenceKind: String
  public let evidenceConfidence: Confidence
  public let evidenceExplanation: String
  public let excludedDescendantNames: [String]
  public let status: RebuildableDataStatus
  public let isDirectory: Bool?
  public let isSymbolicLink: Bool?

  public init(
    detectorID: String,
    locationID: String,
    path: String,
    classificationID: String,
    classificationLabel: String,
    rebuildability: Rebuildability,
    evidenceRuleID: String,
    evidenceKind: String,
    evidenceConfidence: Confidence,
    evidenceExplanation: String,
    excludedDescendantNames: [String],
    status: RebuildableDataStatus,
    isDirectory: Bool? = nil,
    isSymbolicLink: Bool? = nil
  ) {
    self.detectorID = detectorID
    self.locationID = locationID
    self.path = path
    self.classificationID = classificationID
    self.classificationLabel = classificationLabel
    self.rebuildability = rebuildability
    self.evidenceRuleID = evidenceRuleID
    self.evidenceKind = evidenceKind
    self.evidenceConfidence = evidenceConfidence
    self.evidenceExplanation = evidenceExplanation
    self.excludedDescendantNames = excludedDescendantNames
    self.status = status
    self.isDirectory = isDirectory
    self.isSymbolicLink = isSymbolicLink
  }
}
