import Darwin
import Foundation
import HALDomain

public struct RebuildableDataInspection: Hashable, Sendable {
  public let status: RebuildableDataStatus
  public let isDirectory: Bool?
  public let isSymbolicLink: Bool?

  public init(
    status: RebuildableDataStatus,
    isDirectory: Bool? = nil,
    isSymbolicLink: Bool? = nil
  ) {
    self.status = status
    self.isDirectory = isDirectory
    self.isSymbolicLink = isSymbolicLink
  }
}

public protocol RebuildableDataInspecting: Sendable {
  func inspectLocation(at url: URL) -> RebuildableDataInspection
}

public struct FileSystemRebuildableDataInspector: RebuildableDataInspecting {
  public init() {}

  public func inspectLocation(at url: URL) -> RebuildableDataInspection {
    var information = stat()
    guard lstat(url.path, &information) == 0 else {
      switch errno {
      case ENOENT, ENOTDIR:
        return RebuildableDataInspection(status: .absent)
      case EACCES, EPERM:
        return RebuildableDataInspection(status: .permissionDenied)
      default:
        return RebuildableDataInspection(status: .unreadable)
      }
    }
    let fileType = information.st_mode & S_IFMT
    return RebuildableDataInspection(
      status: .present,
      isDirectory: fileType == S_IFDIR,
      isSymbolicLink: fileType == S_IFLNK
    )
  }
}

public struct RebuildableDataCollector: Sendable {
  public static let id: CollectorID = "rebuildable-data"
  public static let version = 1

  private let configuration: RebuildableDataConfiguration
  private let userHome: URL
  private let inspector: any RebuildableDataInspecting
  private let clock: any HALClock

  public init(
    configuration: RebuildableDataConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    inspector: any RebuildableDataInspecting = FileSystemRebuildableDataInspector(),
    clock: any HALClock = SystemClock()
  ) {
    self.configuration = configuration
    self.userHome = userHome.standardizedFileURL
    self.inspector = inspector
    self.clock = clock
  }

  public func collect(scanID: ScanID) -> CollectorOutput<RebuildableDataValue> {
    let startedAt = clock.now()
    let classifications = Dictionary(
      uniqueKeysWithValues: configuration.classifications.map { ($0.id, $0) }
    )
    var observations: [CollectedObservation<RebuildableDataValue>] = []
    var issues: [CollectionIssue] = []
    for detector in configuration.detectors {
      guard let classification = classifications[detector.classificationID] else {
        issues.append(
          CollectionIssue(
            id: "rebuildable-data-classification-\(detector.id)",
            severity: .error,
            summary: "HAL could not resolve a rebuildable-data classification.",
            affectedScope: detector.id
          )
        )
        continue
      }
      do {
        for (location, url) in zip(
          detector.locations,
          try detector.resolvedLocations(userHome: userHome)
        ) {
          guard isInsideUserHome(url) else {
            issues.append(
              CollectionIssue(
                id: "rebuildable-data-escaped-root-\(detector.id)-\(location.id)",
                severity: .error,
                summary: "HAL refused a rebuildable-data location outside the user home.",
                affectedScope: location.id
              )
            )
            continue
          }
          let inspection = inspector.inspectLocation(at: url)
          observations.append(
            observation(
              scanID: scanID,
              observedAt: startedAt,
              detector: detector,
              location: location,
              url: url,
              classification: classification,
              inspection: inspection
            )
          )
          if inspection.status == .permissionDenied || inspection.status == .unreadable {
            issues.append(inspectionIssue(detector, location: location, inspection: inspection))
          } else if inspection.isSymbolicLink == true {
            issues.append(
              CollectionIssue(
                id: "rebuildable-data-symbolic-link-\(detector.id)-\(location.id)",
                severity: .warning,
                summary: "HAL will not treat a symbolic link as reclaimable data.",
                affectedScope: url.path
              )
            )
          }
        }
      } catch {
        issues.append(
          CollectionIssue(
            id: "rebuildable-data-path-\(detector.id)",
            severity: .error,
            summary: "HAL refused an unsafe rebuildable-data location.",
            affectedScope: detector.id
          )
        )
      }
    }
    observations.sort { $0.value.path < $1.value.path }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: issues.isEmpty ? .complete : .partial,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: configuration.detectors.flatMap { $0.locations.map(\.id) },
        issues: issues
      ),
      observations: observations
    )
  }

  private func observation(
    scanID: ScanID,
    observedAt: Date,
    detector: RebuildableDataDetector,
    location: RebuildableDataLocation,
    url: URL,
    classification: RebuildableDataClassification,
    inspection: RebuildableDataInspection
  ) -> CollectedObservation<RebuildableDataValue> {
    CollectedObservation(
      id: ObservationID("rebuildable-data:\(detector.id):\(location.id)"),
      scanID: scanID,
      collectorID: Self.id,
      schemaVersion: Self.version,
      observedAt: observedAt,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .canonicalPath, value: url.path)
      ),
      sensitivity: .privateMetadata,
      sourceReference: url.path,
      value: RebuildableDataValue(
        detectorID: detector.id,
        locationID: location.id,
        path: url.path,
        classificationID: classification.id,
        classificationLabel: classification.label,
        rebuildability: classification.rebuildability,
        evidenceRuleID: detector.evidenceRule.id,
        evidenceKind: detector.evidenceRule.kind.rawValue,
        evidenceConfidence: detector.evidenceRule.confidence,
        evidenceExplanation: detector.evidenceRule.explanation,
        excludedDescendantNames: detector.excludedDescendantNames,
        managerID: detector.manager?.id,
        managerLabel: detector.manager?.label,
        status: inspection.status,
        isDirectory: inspection.isDirectory,
        isSymbolicLink: inspection.isSymbolicLink
      )
    )
  }

  private func inspectionIssue(
    _ detector: RebuildableDataDetector,
    location: RebuildableDataLocation,
    inspection: RebuildableDataInspection
  ) -> CollectionIssue {
    CollectionIssue(
      id: "rebuildable-data-\(inspection.status.rawValue)-\(detector.id)-\(location.id)",
      severity: .warning,
      summary:
        inspection.status == .permissionDenied
        ? "HAL did not have permission to inspect a rebuildable-data location."
        : "HAL could not inspect a rebuildable-data location.",
      affectedScope: location.id
    )
  }

  private func isInsideUserHome(_ url: URL) -> Bool {
    let resolvedHome = userHome.resolvingSymlinksInPath().standardizedFileURL.path
    let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL.path
    return resolvedURL.hasPrefix(resolvedHome + "/")
  }
}
