import Foundation
import GeordiDomain
import GeordiManifestKit

public struct CommandLineSoftwareConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1
  public let schemaVersion: Int
  public let roots: [CommandLineSoftwareRoot]

  public init(schemaVersion: Int = Self.currentVersion, roots: [CommandLineSoftwareRoot]) {
    self.schemaVersion = schemaVersion
    self.roots = roots
  }

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(
        forResource: "command-line-software", withExtension: "json"),
      let schema = Bundle.module.url(
        forResource: "command-line-software.schema", withExtension: "json")
    else { throw CommandLineSoftwareCollectorError.resourceUnavailable }
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let value = try JSONDecoder().decode(Self.self, from: data)
      guard value.schemaVersion == currentVersion else {
        throw CommandLineSoftwareCollectorError.unsupportedVersion(value.schemaVersion)
      }
      guard Set(value.roots.map(\.id)).count == value.roots.count else {
        throw CommandLineSoftwareCollectorError.duplicateRootID
      }
      return value
    } catch let error as CommandLineSoftwareCollectorError {
      throw error
    } catch {
      throw CommandLineSoftwareCollectorError.invalid(String(describing: error))
    }
  }
}

public struct CommandLineSoftwareRoot: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let label: String
  public let path: String
  public let scope: RuntimeExecutableCandidate.Scope
  public let maxEntries: Int
  public let packageManagerID: String?

  public init(
    id: String,
    label: String,
    path: String,
    scope: RuntimeExecutableCandidate.Scope,
    maxEntries: Int,
    packageManagerID: String? = nil
  ) {
    self.id = id
    self.label = label
    self.path = path
    self.scope = scope
    self.maxEntries = maxEntries
    self.packageManagerID = packageManagerID
  }
}

public struct CommandLineSoftwareCollector: Sendable {
  public static let id: CollectorID = "command-line-software"
  public static let version = 1

  private let configuration: CommandLineSoftwareConfiguration
  private let userHome: URL
  private let clock: any TimeSource

  public init(
    configuration: CommandLineSoftwareConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    clock: any TimeSource = SystemClock()
  ) {
    self.configuration = configuration
    self.userHome = userHome
    self.clock = clock
  }

  public func collect(scanID: ScanID) -> CollectorOutput<CommandLineSoftwareValue> {
    let startedAt = clock.now()
    var observations: [CollectedObservation<CommandLineSoftwareValue>] = []
    var issues: [CollectionIssue] = []
    for root in configuration.roots {
      guard let rootURL = resolve(root) else {
        issues.append(
          CollectionIssue(
            id: "command-line-root-invalid:\(root.id)",
            severity: .error,
            summary: "A configured command-line software root was unsafe.",
            affectedScope: root.id
          ))
        continue
      }
      guard
        let entries = try? FileManager.default.contentsOfDirectory(
          at: rootURL,
          includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
          options: [.skipsHiddenFiles]
        )
      else { continue }
      let executableEntries =
        entries
        .filter { FileManager.default.isExecutableFile(atPath: $0.path) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
      if executableEntries.count > root.maxEntries {
        issues.append(
          CollectionIssue(
            id: "command-line-root-limited:\(root.id)",
            severity: .warning,
            summary: "The configured command-line software root exceeded its observation budget.",
            affectedScope: root.id
          ))
      }
      for executable in executableEntries.prefix(root.maxEntries) {
        let resolved = executable.resolvingSymlinksInPath().standardizedFileURL
        let packageName = homebrewPackageName(
          resolvedPath: resolved.path,
          managerID: root.packageManagerID
        )
        observations.append(
          CollectedObservation(
            id: ObservationID("command-line:\(root.id):\(executable.path)"),
            scanID: scanID,
            collectorID: Self.id,
            schemaVersion: Self.version,
            observedAt: startedAt,
            subject: SubjectIdentity(
              primary: IdentityClaim(kind: .canonicalPath, value: resolved.path)
            ),
            sourceReference: executable.path,
            value: CommandLineSoftwareValue(
              name: executable.lastPathComponent,
              executablePath: executable.path,
              resolvedExecutablePath: resolved.path,
              sourceID: root.id,
              sourceLabel: root.label,
              packageManagerID: root.packageManagerID,
              packageName: packageName
            )
          ))
      }
    }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: issues.contains { $0.severity == .warning } ? .partial : .complete,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: configuration.roots.map(\.id),
        issues: issues
      ),
      observations: observations
    )
  }

  private func resolve(_ root: CommandLineSoftwareRoot) -> URL? {
    switch root.scope {
    case .system:
      guard root.path.hasPrefix("/"), !root.path.contains("..") else { return nil }
      return URL(filePath: root.path).standardizedFileURL
    case .user:
      let prefix = "$USER_HOME/"
      guard root.path.hasPrefix(prefix), !root.path.contains("..") else { return nil }
      return userHome.appending(path: String(root.path.dropFirst(prefix.count)))
        .standardizedFileURL
    }
  }

  private func homebrewPackageName(resolvedPath: String, managerID: String?) -> String? {
    guard managerID == "homebrew" else { return nil }
    let components = URL(filePath: resolvedPath).pathComponents
    guard let cellarIndex = components.firstIndex(of: "Cellar"),
      components.indices.contains(cellarIndex + 1)
    else { return nil }
    return components[cellarIndex + 1]
  }
}

public enum CommandLineSoftwareCollectorError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateRootID
  case invalid(String)
}
