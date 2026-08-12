import Darwin
import Foundation
import HALDomain

public protocol AssociatedLocationInspecting: Sendable {
  func inspectLocation(at url: URL) -> AssociatedLocationInspection
}

public protocol AssociatedLocationEnumerating: Sendable {
  func immediateChildren(at root: URL, limit: Int) throws -> AssociatedLocationEnumeration
}

public struct AssociatedLocationEnumeration: Hashable, Sendable {
  public let children: [URL]
  public let wasTruncated: Bool

  public init(children: [URL], wasTruncated: Bool) {
    self.children = children
    self.wasTruncated = wasTruncated
  }
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

public struct FileSystemAssociatedLocationEnumerator: AssociatedLocationEnumerating {
  public init() {}

  public func immediateChildren(
    at root: URL,
    limit: Int
  ) throws -> AssociatedLocationEnumeration {
    guard
      let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: nil,
        options: []
      )
    else {
      throw CocoaError(.fileReadUnknown)
    }
    var children: [URL] = []
    var wasTruncated = false
    for case let child as URL in enumerator {
      enumerator.skipDescendants()
      if children.count == limit {
        wasTruncated = true
        break
      }
      children.append(child)
    }
    return AssociatedLocationEnumeration(
      children: children.sorted { $0.path < $1.path },
      wasTruncated: wasTruncated
    )
  }
}

public struct ApplicationAssociatedLocationCollector: Sendable {
  public static let id: CollectorID = "application-associated-locations"
  public static let version = 3

  private let configuration: ApplicationAssociatedLocationConfiguration
  private let userHome: URL
  private let inspector: any AssociatedLocationInspecting
  private let enumerator: any AssociatedLocationEnumerating
  private let clock: any HALClock

  public init(
    configuration: ApplicationAssociatedLocationConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    inspector: any AssociatedLocationInspecting = FileSystemAssociatedLocationInspector(),
    enumerator: any AssociatedLocationEnumerating = FileSystemAssociatedLocationEnumerator(),
    clock: any HALClock = SystemClock()
  ) {
    self.configuration = configuration
    self.userHome = userHome.standardizedFileURL
    self.inspector = inspector
    self.enumerator = enumerator
    self.clock = clock
  }

  public func collect(
    scanID: ScanID,
    applications: [CollectedObservation<ApplicationBundleValue>],
    signatures: [CollectedObservation<ApplicationSignatureValue>] = []
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
                  ? "\(AppBrand.displayName) did not have permission to inspect a conventional application location."
                  : "\(AppBrand.displayName) could not inspect a conventional application location.",
                affectedScope: url.path
              )
            )
          }
        } catch {
          issues.append(
            CollectionIssue(
              id: "associated-location-invalid-\(location.id)-\(application.id.rawValue)",
              severity: .error,
              summary: "\(AppBrand.displayName) refused an unsafe associated-location candidate.",
              affectedScope: location.id
            )
          )
        }
      }
    }
    for root in configuration.enumerationRoots {
      collectEnumeratedRoot(
        root,
        scanID: scanID,
        applications: applications,
        signatures: signatures,
        observedAt: startedAt,
        observations: &observations,
        issues: &issues
      )
    }
    observations.sort {
      if $0.value.applicationPath != $1.value.applicationPath {
        return ($0.value.applicationPath ?? "") < ($1.value.applicationPath ?? "")
      }
      if $0.value.locationID != $1.value.locationID {
        return $0.value.locationID < $1.value.locationID
      }
      return $0.value.locationPath < $1.value.locationPath
    }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: issues.isEmpty ? .complete : .partial,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: configuration.locations.map(\.id) + configuration.enumerationRoots.map(\.id),
        issues: issues
      ),
      observations: observations
    )
  }

  private func collectEnumeratedRoot(
    _ root: AssociatedLocationEnumerationRoot,
    scanID: ScanID,
    applications: [CollectedObservation<ApplicationBundleValue>],
    signatures: [CollectedObservation<ApplicationSignatureValue>],
    observedAt: Date,
    observations: inout [CollectedObservation<ApplicationAssociatedLocationValue>],
    issues: inout [CollectionIssue]
  ) {
    do {
      guard root.maxEntries > 0 else {
        throw ApplicationAssociatedLocationConfigurationError.invalidEnumerationRoot(root.id)
      }
      let rootURL = try root.resolvedURL(userHome: userHome)
      guard isInsideUserHome(rootURL) else {
        throw ApplicationAssociatedLocationConfigurationError.invalidEnumerationRoot(root.id)
      }
      let rootInspection = inspector.inspectLocation(at: rootURL)
      guard rootInspection.status == .present, rootInspection.isDirectory == true else {
        if rootInspection.status == .permissionDenied || rootInspection.status == .unreadable {
          issues.append(rootIssue(root, status: rootInspection.status, scope: rootURL.path))
        }
        return
      }
      let enumeration = try enumerator.immediateChildren(
        at: rootURL,
        limit: min(root.maxEntries, 4096)
      )
      for child in enumeration.children {
        guard isImmediateChild(child, of: rootURL) else {
          issues.append(
            CollectionIssue(
              id: "associated-location-unsafe-child-\(root.id)",
              severity: .error,
              summary:
                "\(AppBrand.displayName) refused an unsafe associated-location enumeration result.",
              affectedScope: root.id
            )
          )
          continue
        }
        observations.append(
          contentsOf: enumeratedObservations(
            child,
            root: root,
            scanID: scanID,
            applications: applications,
            signatures: signatures,
            observedAt: observedAt
          )
        )
      }
      if enumeration.wasTruncated {
        issues.append(
          CollectionIssue(
            id: "associated-location-budget-\(root.id)",
            severity: .warning,
            summary:
              "\(AppBrand.displayName) stopped associated-location enumeration at its configured budget.",
            affectedScope: rootURL.path
          )
        )
      }
    } catch {
      issues.append(
        CollectionIssue(
          id: "associated-location-enumeration-\(root.id)",
          severity: .warning,
          summary:
            "\(AppBrand.displayName) could not enumerate a configured associated-location root.",
          affectedScope: root.id
        )
      )
    }
  }

  private func enumeratedObservations(
    _ child: URL,
    root: AssociatedLocationEnumerationRoot,
    scanID: ScanID,
    applications: [CollectedObservation<ApplicationBundleValue>],
    signatures: [CollectedObservation<ApplicationSignatureValue>],
    observedAt: Date
  ) -> [CollectedObservation<ApplicationAssociatedLocationValue>] {
    let matches = applicationMatches(
      child.lastPathComponent,
      matching: root.matching,
      applications: applications,
      signatures: signatures
    )
    let associations: [(path: String?, match: AssociatedLocationMatch)]
    if !matches.applicationGroupIdentifier.isEmpty {
      associations = matches.applicationGroupIdentifier.map {
        (path: $0, match: .applicationGroupIdentifier)
      }
    } else if !matches.bundleIdentifier.isEmpty {
      if matches.bundleIdentifier.count == 1 {
        associations = [(path: matches.bundleIdentifier[0], match: .bundleIdentifier)]
      } else {
        associations = [(path: nil, match: .unmatched)]
      }
    } else if !matches.applicationName.isEmpty {
      if matches.applicationName.count == 1 {
        associations = [(path: matches.applicationName[0], match: .applicationName)]
      } else {
        associations = [(path: nil, match: .unmatched)]
      }
    } else {
      associations = [
        (
          path: nil,
          match:
            root.matching == .applicationGroupIdentifiers
            ? .groupIdentifierUnavailable : .unmatched
        )
      ]
    }
    let candidates = Array(
      Set(
        matches.bundleIdentifier + matches.applicationName
          + matches.applicationGroupIdentifier
      )
    ).sorted()
    let inspection = inspector.inspectLocation(at: child)
    return associations.map { association in
      CollectedObservation(
        id: ObservationID(
          "associated-location-enumerated:\(root.id):\(child.path):\(association.path ?? "unresolved")"
        ),
        scanID: scanID,
        collectorID: Self.id,
        schemaVersion: Self.version,
        observedAt: observedAt,
        subject: SubjectIdentity(
          primary: IdentityClaim(kind: .canonicalPath, value: child.path)
        ),
        sensitivity: .privateMetadata,
        sourceReference: child.path,
        value: ApplicationAssociatedLocationValue(
          applicationPath: association.path,
          candidateApplicationPaths: candidates,
          locationID: root.id,
          locationPath: child.path,
          categoryLabel: root.categoryLabel,
          match: association.match,
          status: inspection.status,
          isDirectory: inspection.isDirectory
        )
      )
    }
  }

  private func applicationMatches(
    _ name: String,
    matching: AssociatedLocationEnumerationRoot.Matching,
    applications: [CollectedObservation<ApplicationBundleValue>],
    signatures: [CollectedObservation<ApplicationSignatureValue>]
  ) -> (
    bundleIdentifier: [String],
    applicationName: [String],
    applicationGroupIdentifier: [String]
  ) {
    if matching == .applicationGroupIdentifiers {
      let groupMatches = signatures.compactMap {
        $0.value.applicationGroupIdentifiers.contains(name) ? $0.value.applicationPath : nil
      }
      return ([], [], groupMatches.sorted())
    }
    let bundleMatches = applications.compactMap {
      $0.value.bundleIdentifier == name ? $0.value.path : nil
    }
    let nameMatches = applications.compactMap {
      $0.value.name == name ? $0.value.path : nil
    }
    return (bundleMatches.sorted(), nameMatches.sorted(), [])
  }

  private func rootIssue(
    _ root: AssociatedLocationEnumerationRoot,
    status: AssociatedLocationStatus,
    scope: String
  ) -> CollectionIssue {
    CollectionIssue(
      id: "associated-location-root-\(status.rawValue)-\(root.id)",
      severity: .warning,
      summary:
        status == .permissionDenied
        ? "\(AppBrand.displayName) did not have permission to enumerate an associated-location root."
        : "\(AppBrand.displayName) could not inspect an associated-location root.",
      affectedScope: scope
    )
  }

  private func isInsideUserHome(_ url: URL) -> Bool {
    let resolvedHome = userHome.resolvingSymlinksInPath().standardizedFileURL.path
    let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL.path
    return resolvedURL.hasPrefix(resolvedHome + "/")
  }

  private func isImmediateChild(_ child: URL, of root: URL) -> Bool {
    child.standardizedFileURL.deletingLastPathComponent().path
      == root.standardizedFileURL.path
  }
}
