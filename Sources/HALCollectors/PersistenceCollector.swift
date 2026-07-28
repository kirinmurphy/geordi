import Foundation
import HALDomain

public struct PersistenceCollector: Sendable {
  public static let id: CollectorID = "persistence-declarations"
  public static let version = 1

  private let roots: [PersistenceSearchRoot]
  private let clock: any HALClock

  public init(
    roots: [PersistenceSearchRoot],
    clock: any HALClock = SystemClock()
  ) {
    self.roots = roots
    self.clock = clock
  }

  public func collect(scanID: ScanID) -> CollectorOutput<PersistenceDeclarationValue> {
    let startedAt = clock.now()
    var observations: [CollectedObservation<PersistenceDeclarationValue>] = []
    var issues: [CollectionIssue] = []
    for root in roots {
      collect(
        root: root,
        scanID: scanID,
        observedAt: startedAt,
        observations: &observations,
        issues: &issues
      )
    }
    observations.sort { $0.value.declarationPath < $1.value.declarationPath }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: issues.contains { $0.severity == .error } ? .partial : .complete,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: roots.map(\.url.path),
        issues: issues
      ),
      observations: observations
    )
  }

  private func collect(
    root: PersistenceSearchRoot,
    scanID: ScanID,
    observedAt: Date,
    observations: inout [CollectedObservation<PersistenceDeclarationValue>],
    issues: inout [CollectionIssue]
  ) {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root.url.path, isDirectory: &isDirectory) else {
      return
    }
    guard isDirectory.boolValue else {
      issues.append(
        issue(
          id: "invalid-persistence-root-\(root.id)",
          summary: "A persistence search root was not a directory.",
          path: root.url.path
        )
      )
      return
    }
    let files: [URL]
    do {
      files = try FileManager.default.contentsOfDirectory(
        at: root.url,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    } catch {
      issues.append(
        issue(
          id: "unreadable-persistence-root-\(root.id)",
          summary: "HAL could not read a persistence search root.",
          path: root.url.path
        )
      )
      return
    }
    for file in files.sorted(by: { $0.path < $1.path })
    where file.pathExtension.caseInsensitiveCompare("plist") == .orderedSame {
      do {
        let value = try declaration(at: file, kind: root.kind)
        observations.append(
          CollectedObservation(
            id: ObservationID("persistence:\(file.standardizedFileURL.path)"),
            scanID: scanID,
            collectorID: Self.id,
            schemaVersion: Self.version,
            observedAt: observedAt,
            subject: SubjectIdentity(
              primary: IdentityClaim(kind: .canonicalPath, value: file.standardizedFileURL.path),
              aliases: [IdentityClaim(kind: .collectorLocal, value: value.label)]
            ),
            sensitivity: .privateMetadata,
            sourceReference: file.path,
            value: value
          )
        )
      } catch {
        issues.append(
          issue(
            id: "invalid-persistence-declaration-\(file.lastPathComponent)",
            summary: "HAL could not parse a persistence declaration.",
            path: file.path
          )
        )
      }
    }
  }

  private func declaration(
    at url: URL,
    kind: PersistenceDeclarationKind
  ) throws -> PersistenceDeclarationValue {
    let data = try Data(contentsOf: url, options: .mappedIfSafe)
    guard
      let dictionary = try PropertyListSerialization.propertyList(
        from: data,
        options: [],
        format: nil
      ) as? [String: Any],
      let label = dictionary["Label"] as? String,
      !label.isEmpty
    else {
      throw PersistenceCollectorError.invalidDeclaration
    }
    let program =
      dictionary["Program"] as? String
      ?? (dictionary["ProgramArguments"] as? [String])?.first
    let keepAlive =
      (dictionary["KeepAlive"] as? Bool)
      ?? (dictionary["KeepAlive"] is [String: Any])
    return PersistenceDeclarationValue(
      declarationPath: url.standardizedFileURL.path,
      kind: kind,
      label: label,
      programPath: program,
      runAtLoad: dictionary["RunAtLoad"] as? Bool ?? false,
      keepAlive: keepAlive
    )
  }

  private func issue(id: String, summary: String, path: String) -> CollectionIssue {
    CollectionIssue(
      id: id,
      severity: .error,
      summary: summary,
      affectedScope: path
    )
  }
}

public enum PersistenceCollectorError: Error, Equatable, Sendable {
  case invalidDeclaration
}
