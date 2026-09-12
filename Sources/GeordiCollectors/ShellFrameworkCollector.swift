import Foundation
import GeordiDomain
import GeordiManifestKit

public struct ShellFrameworkConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 2
  public let schemaVersion: Int
  public let frameworks: [ShellFrameworkDefinition]

  public init(
    schemaVersion: Int = Self.currentVersion,
    frameworks: [ShellFrameworkDefinition]
  ) {
    self.schemaVersion = schemaVersion
    self.frameworks = frameworks
  }

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "shell-frameworks", withExtension: "json"),
      let schema = Bundle.module.url(forResource: "shell-frameworks.schema", withExtension: "json")
    else { throw ShellFrameworkCollectorError.resourceUnavailable }
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schema = Bundle.module.url(forResource: "shell-frameworks.schema", withExtension: "json")
    else { throw ShellFrameworkCollectorError.resourceUnavailable }
    return try Data(contentsOf: schema)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let value = try JSONDecoder().decode(Self.self, from: data)
      guard value.schemaVersion == currentVersion else {
        throw ShellFrameworkCollectorError.unsupportedVersion(value.schemaVersion)
      }
      guard Set(value.frameworks.map(\.id)).count == value.frameworks.count else {
        throw ShellFrameworkCollectorError.duplicateFrameworkID
      }
      guard value.frameworks.allSatisfy(\.hasSafePaths) else {
        throw ShellFrameworkCollectorError.invalidPath
      }
      return value
    } catch let error as ShellFrameworkCollectorError {
      throw error
    } catch {
      throw ShellFrameworkCollectorError.invalid(String(describing: error))
    }
  }
}

public struct ShellFrameworkDefinition: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let label: String
  public let rootPath: String
  public let configurationPath: String
  public let requiredRelativePaths: [String]
  public let configurationReferenceTokens: [String]
  public let repositoryHosts: [String]
  public let repositoryPathSuffixes: [String]
  public let associatedShellExecutablePaths: [String]
  public let maximumAssociatedProcesses: Int

  public init(
    id: String,
    label: String,
    rootPath: String,
    configurationPath: String,
    requiredRelativePaths: [String],
    configurationReferenceTokens: [String],
    repositoryHosts: [String],
    repositoryPathSuffixes: [String],
    associatedShellExecutablePaths: [String],
    maximumAssociatedProcesses: Int
  ) {
    self.id = id
    self.label = label
    self.rootPath = rootPath
    self.configurationPath = configurationPath
    self.requiredRelativePaths = requiredRelativePaths
    self.configurationReferenceTokens = configurationReferenceTokens
    self.repositoryHosts = repositoryHosts
    self.repositoryPathSuffixes = repositoryPathSuffixes
    self.associatedShellExecutablePaths = associatedShellExecutablePaths
    self.maximumAssociatedProcesses = maximumAssociatedProcesses
  }

  fileprivate var hasSafePaths: Bool {
    [rootPath, configurationPath].allSatisfy {
      $0.hasPrefix("$USER_HOME/") && !$0.contains("..")
    }
      && requiredRelativePaths.allSatisfy {
        !$0.hasPrefix("/") && !$0.split(separator: "/").contains("..")
      }
      && associatedShellExecutablePaths.allSatisfy {
        $0.hasPrefix("/") && !$0.split(separator: "/").contains("..")
      }
  }
}

public struct ShellFrameworkCollector: Sendable {
  public static let id: CollectorID = "shell-frameworks"
  public static let version = 2

  private let configuration: ShellFrameworkConfiguration
  private let userHome: URL
  private let clock: any TimeSource
  private let maximumMetadataBytes = 262_144

  public init(
    configuration: ShellFrameworkConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    clock: any TimeSource = SystemClock()
  ) {
    self.configuration = configuration
    self.userHome = userHome.standardizedFileURL
    self.clock = clock
  }

  public func collect(scanID: ScanID) -> CollectorOutput<ShellFrameworkValue> {
    let startedAt = clock.now()
    var issues: [CollectionIssue] = []
    let observations = configuration.frameworks.map { definition in
      observation(
        definition,
        scanID: scanID,
        observedAt: startedAt,
        issues: &issues
      )
    }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: issues.isEmpty ? .complete : .partial,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: configuration.frameworks.map(\.id),
        issues: issues
      ),
      observations: observations
    )
  }

  private func observation(
    _ definition: ShellFrameworkDefinition,
    scanID: ScanID,
    observedAt: Date,
    issues: inout [CollectionIssue]
  ) -> CollectedObservation<ShellFrameworkValue> {
    let root = resolve(definition.rootPath)
    let config = resolve(definition.configurationPath)
    let status = installationStatus(definition, root: root, issues: &issues)
    let configurationStatus = configurationStatus(
      definition,
      configurationURL: config,
      issues: &issues
    )
    let host = status == .observed ? repositoryHost(definition, root: root) : nil
    return CollectedObservation(
      id: ObservationID("shell-framework:\(definition.id)"),
      scanID: scanID,
      collectorID: Self.id,
      schemaVersion: Self.version,
      observedAt: observedAt,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .canonicalPath, value: root.path)
      ),
      sensitivity: .privateMetadata,
      sourceReference: root.path,
      value: ShellFrameworkValue(
        frameworkID: definition.id,
        label: definition.label,
        rootPath: root.path,
        installationStatus: status,
        configurationPath: config.path,
        configurationStatus: configurationStatus,
        repositoryHost: host,
        associatedShellExecutablePaths: definition.associatedShellExecutablePaths.map {
          URL(filePath: $0).standardizedFileURL.path
        },
        maximumAssociatedProcesses: definition.maximumAssociatedProcesses
      )
    )
  }

  private func installationStatus(
    _ definition: ShellFrameworkDefinition,
    root: URL,
    issues: inout [CollectionIssue]
  ) -> ShellFrameworkInstallationStatus {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
      return .absent
    }
    guard isDirectory.boolValue, isInsideUserHome(root.resolvingSymlinksInPath()) else {
      issues.append(unsafeIssue(definition.id, path: root.path))
      return .ambiguous
    }
    do {
      let values = try root.resourceValues(forKeys: [.isReadableKey])
      guard values.isReadable == true else { return .unreadable }
      let allExpected = definition.requiredRelativePaths.allSatisfy {
        let expected = root.appending(path: $0)
        return FileManager.default.fileExists(atPath: expected.path)
          && isInside(expected.resolvingSymlinksInPath(), boundary: root)
      }
      return allExpected ? .observed : .ambiguous
    } catch {
      return .unreadable
    }
  }

  private func configurationStatus(
    _ definition: ShellFrameworkDefinition,
    configurationURL: URL,
    issues: inout [CollectionIssue]
  ) -> ShellFrameworkConfigurationStatus {
    guard isInsideUserHome(configurationURL.resolvingSymlinksInPath()) else {
      issues.append(unsafeIssue(definition.id, path: configurationURL.path))
      return .unreadable
    }
    guard FileManager.default.fileExists(atPath: configurationURL.path) else { return .absent }
    guard let data = boundedData(at: configurationURL),
      let text = String(data: data, encoding: .utf8)
    else { return .unreadable }
    return definition.configurationReferenceTokens.contains(where: text.contains)
      ? .active : .inactive
  }

  private func repositoryHost(
    _ definition: ShellFrameworkDefinition,
    root: URL
  ) -> String? {
    let config = root.appending(path: ".git/config")
    guard isInside(config.resolvingSymlinksInPath(), boundary: root) else { return nil }
    guard
      let data = boundedData(at: config),
      let text = String(data: data, encoding: .utf8)
    else { return nil }
    for line in text.split(whereSeparator: \.isNewline) {
      let value = line.trimmingCharacters(in: .whitespaces)
      guard value.hasPrefix("url =") else { continue }
      let remote = value.dropFirst(5).trimmingCharacters(in: .whitespaces)
      let normalized = remote.replacingOccurrences(of: "git@", with: "ssh://git@")
      guard let url = URL(string: normalized), let host = url.host?.lowercased() else {
        continue
      }
      let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        .replacingOccurrences(of: ".git", with: "")
      guard definition.repositoryHosts.contains(host),
        definition.repositoryPathSuffixes.contains(where: path.hasSuffix)
      else { continue }
      return host
    }
    return nil
  }

  private func boundedData(at url: URL) -> Data? {
    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
      values.isRegularFile == true,
      let size = values.fileSize,
      size <= maximumMetadataBytes
    else { return nil }
    return try? Data(contentsOf: url, options: [.mappedIfSafe])
  }

  private func resolve(_ path: String) -> URL {
    userHome.appending(path: String(path.dropFirst("$USER_HOME/".count))).standardizedFileURL
  }

  private func isInsideUserHome(_ url: URL) -> Bool {
    isInside(url, boundary: userHome)
  }

  private func isInside(_ url: URL, boundary: URL) -> Bool {
    url.path == boundary.path || url.path.hasPrefix(boundary.path + "/")
  }

  private func unsafeIssue(_ id: String, path: String) -> CollectionIssue {
    CollectionIssue(
      id: "unsafe-shell-framework-path-\(id)",
      severity: .warning,
      summary: "A shell-framework path resolved outside the configured user home.",
      affectedScope: path
    )
  }
}

public enum ShellFrameworkCollectorError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateFrameworkID
  case invalidPath
  case invalid(String)
}
