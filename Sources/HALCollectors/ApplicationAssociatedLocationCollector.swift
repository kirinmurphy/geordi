import Darwin
import Foundation
import HALDomain

public protocol AssociatedLocationInspecting: Sendable {
  func inspectLocation(at url: URL) -> AssociatedLocationInspection
}

public struct AssociatedLocationInspection: Hashable, Sendable {
  public let status: AssociatedLocationStatus
  public let isDirectory: Bool?

  public init(status: AssociatedLocationStatus, isDirectory: Bool? = nil) {
    self.status = status
    self.isDirectory = isDirectory
  }
}

public struct FileSystemAssociatedLocationInspector: AssociatedLocationInspecting {
  public init() {}

  public func inspectLocation(at url: URL) -> AssociatedLocationInspection {
    var information = stat()
    guard lstat(url.path, &information) == 0 else {
      switch errno {
      case ENOENT, ENOTDIR:
        return AssociatedLocationInspection(status: .absent)
      case EACCES, EPERM:
        return AssociatedLocationInspection(status: .permissionDenied)
      default:
        return AssociatedLocationInspection(status: .unreadable)
      }
    }
    let fileType = information.st_mode & S_IFMT
    return AssociatedLocationInspection(
      status: .present,
      isDirectory: fileType == S_IFDIR
    )
  }
}

public struct ApplicationAssociatedLocationCollector: Sendable {
  public static let id: CollectorID = "application-associated-locations"
  public static let version = 1

  private let configuration: ApplicationAssociatedLocationConfiguration
  private let userHome: URL
  private let inspector: any AssociatedLocationInspecting
  private let clock: any HALClock

  public init(
    configuration: ApplicationAssociatedLocationConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    inspector: any AssociatedLocationInspecting = FileSystemAssociatedLocationInspector(),
    clock: any HALClock = SystemClock()
  ) {
    self.configuration = configuration
    self.userHome = userHome.standardizedFileURL
    self.inspector = inspector
    self.clock = clock
  }

  public func collect(
    scanID: ScanID,
    applications: [CollectedObservation<ApplicationBundleValue>]
  ) -> CollectorOutput<ApplicationAssociatedLocationValue> {
    let startedAt = clock.now()
    var observations: [CollectedObservation<ApplicationAssociatedLocationValue>] = []
    var issues: [CollectionIssue] = []

    for application in applications {
      for location in configuration.locations {
        do {
          guard
            let url = try location.resolvedURL(
              application: application.value,
              userHome: userHome
            )
          else {
            continue
          }
          let inspection = inspector.inspectLocation(at: url)
          let value = ApplicationAssociatedLocationValue(
            applicationPath: application.value.path,
            locationID: location.id,
            locationPath: url.path,
            categoryLabel: location.categoryLabel,
            match: location.match,
            status: inspection.status,
            isDirectory: inspection.isDirectory
          )
          observations.append(
            CollectedObservation(
              id: ObservationID(
                "associated-location:\(application.value.path):\(location.id)"
              ),
              scanID: scanID,
              collectorID: Self.id,
              schemaVersion: Self.version,
              observedAt: startedAt,
              subject: application.subject,
              sensitivity: .privateMetadata,
              sourceReference: url.path,
              value: value
            )
          )
          if inspection.status == .permissionDenied || inspection.status == .unreadable {
            issues.append(
              CollectionIssue(
                id:
                  "associated-location-\(inspection.status.rawValue)-\(location.id)-\(application.id.rawValue)",
                severity: .warning,
                summary:
                  inspection.status == .permissionDenied
                  ? "HAL did not have permission to inspect a conventional application location."
                  : "HAL could not inspect a conventional application location.",
                affectedScope: url.path
              )
            )
          }
        } catch {
          issues.append(
            CollectionIssue(
              id: "associated-location-invalid-\(location.id)-\(application.id.rawValue)",
              severity: .error,
              summary: "HAL refused an unsafe associated-location candidate.",
              affectedScope: location.id
            )
          )
        }
      }
    }
    observations.sort {
      if $0.value.applicationPath != $1.value.applicationPath {
        return $0.value.applicationPath < $1.value.applicationPath
      }
      return $0.value.locationID < $1.value.locationID
    }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: issues.isEmpty ? .complete : .partial,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: configuration.locations.map(\.id),
        issues: issues
      ),
      observations: observations
    )
  }
}
