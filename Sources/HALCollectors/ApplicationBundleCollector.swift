import Foundation
import HALDomain

public struct ApplicationSearchRoot: Hashable, Sendable {
  public let url: URL
  public let required: Bool

  public init(url: URL, required: Bool = false) {
    self.url = url
    self.required = required
  }
}

public struct ApplicationBundleCollector: Sendable {
  public static let id: CollectorID = "application-bundles"
  public static let version = 1

  public let roots: [ApplicationSearchRoot]
  private let setupMarkerURL: URL?
  private let setupTolerance: TimeInterval
  private let clock: any HALClock

  public init(
    roots: [ApplicationSearchRoot],
    setupMarkerURL: URL? = nil,
    setupTolerance: TimeInterval = 300,
    clock: any HALClock = SystemClock()
  ) {
    self.roots = roots
    self.setupMarkerURL = setupMarkerURL
    self.setupTolerance = setupTolerance
    self.clock = clock
  }

  public func collect(scanID: ScanID) -> CollectorOutput<ApplicationBundleValue> {
    let startedAt = clock.now()
    var observations: [CollectedObservation<ApplicationBundleValue>] = []
    var issues: [CollectionIssue] = []
    let setupCompletedAt = setupMarkerURL.flatMap { creationDate(at: $0) }

    for root in roots {
      collect(
        root: root,
        scanID: scanID,
        observedAt: startedAt,
        setupCompletedAt: setupCompletedAt,
        observations: &observations,
        issues: &issues
      )
    }

    observations.sort { $0.value.path < $1.value.path }
    let completedAt = clock.now()
    let state: CollectorRunState =
      issues.contains(where: { $0.severity == .error }) ? .partial : .complete
    let run = CollectorRun(
      collectorID: Self.id,
      collectorVersion: Self.version,
      availability: .available,
      state: state,
      startedAt: startedAt,
      completedAt: completedAt,
      scope: roots.map(\.url.path),
      issues: issues
    )
    return CollectorOutput(run: run, observations: observations)
  }

  private func collect(
    root: ApplicationSearchRoot,
    scanID: ScanID,
    observedAt: Date,
    setupCompletedAt: Date?,
    observations: inout [CollectedObservation<ApplicationBundleValue>],
    issues: inout [CollectionIssue]
  ) {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root.url.path, isDirectory: &isDirectory) else {
      if root.required {
        issues.append(
          CollectionIssue(
            id: "missing-root-\(root.url.path)",
            severity: .error,
            summary: "A required application search location was unavailable.",
            affectedScope: root.url.path
          )
        )
      }
      return
    }
    guard isDirectory.boolValue else {
      issues.append(
        CollectionIssue(
          id: "invalid-root-\(root.url.path)",
          severity: .error,
          summary: "An application search location was not a directory.",
          affectedScope: root.url.path
        )
      )
      return
    }

    let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
    var enumerationIssues: [CollectionIssue] = []
    guard
      let enumerator = FileManager.default.enumerator(
        at: root.url,
        includingPropertiesForKeys: keys,
        options: [.skipsHiddenFiles],
        errorHandler: { url, _ in
          enumerationIssues.append(
            CollectionIssue(
              id: "enumeration-error-\(url.path)",
              severity: .error,
              summary:
                "\(AppBrand.displayName) could not read part of an application search location.",
              affectedScope: url.path
            )
          )
          return true
        }
      )
    else {
      issues.append(
        CollectionIssue(
          id: "enumerator-unavailable-\(root.url.path)",
          severity: .error,
          summary: "\(AppBrand.displayName) could not enumerate an application search location.",
          affectedScope: root.url.path
        )
      )
      return
    }

    for case let url as URL in enumerator {
      guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
        continue
      }
      enumerator.skipDescendants()
      guard let value = applicationValue(at: url, setupCompletedAt: setupCompletedAt) else {
        issues.append(
          CollectionIssue(
            id: "invalid-bundle-\(url.path)",
            severity: .warning,
            summary: "An application bundle did not contain readable bundle metadata.",
            affectedScope: url.path
          )
        )
        continue
      }
      observations.append(
        CollectedObservation(
          id: ObservationID("application:\(url.standardizedFileURL.path)"),
          scanID: scanID,
          collectorID: Self.id,
          schemaVersion: Self.version,
          observedAt: observedAt,
          subject: subject(for: value),
          sensitivity: sensitivity(for: url),
          sourceReference: url.appending(path: "Contents/Info.plist").path,
          value: value
        )
      )
    }
    issues.append(contentsOf: enumerationIssues)
  }

  private func applicationValue(at url: URL, setupCompletedAt: Date?) -> ApplicationBundleValue? {
    guard let bundle = Bundle(url: url) else { return nil }
    let name =
      bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? url.deletingPathExtension().lastPathComponent
    return ApplicationBundleValue(
      path: url.standardizedFileURL.path,
      name: name,
      bundleIdentifier: bundle.bundleIdentifier,
      version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
      buildVersion: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
      executableName: bundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
      bundleCreatedAt: creationDate(at: url),
      setupCompletedAt: setupCompletedAt,
      setupToleranceSeconds: Int(setupTolerance)
    )
  }

  private func creationDate(at url: URL) -> Date? {
    try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
  }

  private func subject(for value: ApplicationBundleValue) -> SubjectIdentity {
    let pathClaim = IdentityClaim(kind: .canonicalPath, value: value.path)
    guard let bundleIdentifier = value.bundleIdentifier else {
      return SubjectIdentity(primary: pathClaim)
    }
    return SubjectIdentity(
      primary: IdentityClaim(kind: .bundleIdentifier, value: bundleIdentifier),
      aliases: [pathClaim]
    )
  }

  private func sensitivity(for url: URL) -> DataSensitivity {
    url.path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path)
      ? .privateMetadata
      : .ordinary
  }
}
