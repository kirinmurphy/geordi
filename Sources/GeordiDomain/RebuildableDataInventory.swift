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

/// The measured footprint of one rebuildable-data root, computed by a
/// bounded walk of that root only.
public struct RebuildableDataSizeMeasurement: Codable, Hashable, Sendable {
  /// Allocated on-disk bytes (st_blocks × 512), counted once per file ID.
  public let allocatedBytes: Int64
  public let entryCount: Int
  /// True when the walk hit its entry/depth/time budget or could not read
  /// part of the tree — `allocatedBytes` is then a lower bound.
  public let isTruncated: Bool

  /// Human label for the UI; the "≥" prefix marks a lower bound.
  public var displayLabel: String {
    let formatted = ByteCountFormatter.string(fromByteCount: allocatedBytes, countStyle: .file)
    return isTruncated ? "≥ \(formatted)" : formatted
  }

  public init(allocatedBytes: Int64, entryCount: Int, isTruncated: Bool) {
    self.allocatedBytes = allocatedBytes
    self.entryCount = entryCount
    self.isTruncated = isTruncated
  }
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
  public let managerID: String?
  public let managerLabel: String?
  public let status: RebuildableDataStatus
  public let isDirectory: Bool?
  public let isSymbolicLink: Bool?
  /// Present only when the read-only bounded size walk ran on a present,
  /// non-symlink directory root.
  public let measuredSize: RebuildableDataSizeMeasurement?

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
    managerID: String? = nil,
    managerLabel: String? = nil,
    status: RebuildableDataStatus,
    isDirectory: Bool? = nil,
    isSymbolicLink: Bool? = nil,
    measuredSize: RebuildableDataSizeMeasurement? = nil
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
    self.managerID = managerID
    self.managerLabel = managerLabel
    self.status = status
    self.isDirectory = isDirectory
    self.isSymbolicLink = isSymbolicLink
    self.measuredSize = measuredSize
  }
}
