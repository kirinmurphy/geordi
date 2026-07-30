import Foundation
import HALDomain
import HALManifestKit

public struct RuntimeCollectorConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 2
  public let schemaVersion: Int
  public let runtimes: [RuntimeDefinition]

  public init(schemaVersion: Int = Self.currentVersion, runtimes: [RuntimeDefinition]) {
    self.schemaVersion = schemaVersion
    self.runtimes = runtimes
  }

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "runtimes", withExtension: "json"),
      let schema = Bundle.module.url(forResource: "runtimes.schema", withExtension: "json")
    else { throw RuntimeCollectorError.resourceUnavailable }
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let value = try JSONDecoder().decode(Self.self, from: data)
      guard value.schemaVersion == currentVersion else {
        throw RuntimeCollectorError.unsupportedVersion(value.schemaVersion)
      }
      guard Set(value.runtimes.map(\.id)).count == value.runtimes.count else {
        throw RuntimeCollectorError.duplicateRuntimeID
      }
      return value
    } catch let error as RuntimeCollectorError {
      throw error
    } catch {
      throw RuntimeCollectorError.invalid(String(describing: error))
    }
  }
}

public struct RuntimeDefinition: Codable, Hashable, Sendable, Identifiable {
  public enum Kind: String, Codable, Hashable, Sendable {
    case runtime
    case compiler
    case toolchain
  }

  public let id: String
  public let label: String
  public let kind: Kind
  public let packageIdentities: [RuntimePackageIdentity]
  public let executableCandidates: [RuntimeExecutableCandidate]
  public let versionArguments: [String]

  public init(
    id: String,
    label: String,
    kind: Kind,
    packageIdentities: [RuntimePackageIdentity] = [],
    executableCandidates: [RuntimeExecutableCandidate],
    versionArguments: [String]
  ) {
    self.id = id
    self.label = label
    self.kind = kind
    self.packageIdentities = packageIdentities
    self.executableCandidates = executableCandidates
    self.versionArguments = versionArguments
  }
}

public struct RuntimePackageIdentity: Codable, Hashable, Sendable {
  public let managerID: String
  public let packageName: String

  public init(managerID: String, packageName: String) {
    self.managerID = managerID
    self.packageName = packageName
  }
}

public struct RuntimeExecutableCandidate: Codable, Hashable, Sendable {
  public enum Scope: String, Codable, Hashable, Sendable {
    case system
    case user
  }

  public let path: String
  public let scope: Scope

  public init(path: String, scope: Scope) {
    self.path = path
    self.scope = scope
  }

  fileprivate func resolved(userHome: URL) -> URL? {
    switch scope {
    case .system:
      guard path.hasPrefix("/"), !path.contains("..") else { return nil }
      return URL(filePath: path).standardizedFileURL
    case .user:
      let prefix = "$USER_HOME/"
      guard path.hasPrefix(prefix), !path.contains("..") else { return nil }
      return userHome.appending(path: String(path.dropFirst(prefix.count))).standardizedFileURL
    }
  }
}

public struct RuntimeCollector: Sendable {
  public static let id: CollectorID = "runtimes"
  public static let version = 2

  private let configuration: RuntimeCollectorConfiguration
  private let userHome: URL
  private let clock: any HALClock

  public init(
    configuration: RuntimeCollectorConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    clock: any HALClock = SystemClock()
  ) {
    self.configuration = configuration
    self.userHome = userHome
    self.clock = clock
  }

  public func collect(scanID: ScanID) -> CollectorOutput<RuntimeValue> {
    let startedAt = clock.now()
    let observations = configuration.runtimes.compactMap { runtime in
      runtimeObservation(runtime, scanID: scanID, observedAt: startedAt)
    }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: .complete,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: configuration.runtimes.map(\.id)
      ),
      observations: observations
    )
  }

  private func runtimeObservation(
    _ runtime: RuntimeDefinition,
    scanID: ScanID,
    observedAt: Date
  ) -> CollectedObservation<RuntimeValue>? {
    guard
      let executable = runtime.executableCandidates.compactMap({
        $0.resolved(userHome: userHome)
      }).first(where: { FileManager.default.isExecutableFile(atPath: $0.path) })
    else { return nil }
    let resolved = executable.resolvingSymlinksInPath().standardizedFileURL
    guard let version = version(executable: executable, arguments: runtime.versionArguments) else {
      return nil
    }
    return CollectedObservation(
      id: ObservationID("runtime:\(runtime.id):\(executable.path)"),
      scanID: scanID,
      collectorID: Self.id,
      schemaVersion: Self.version,
      observedAt: observedAt,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .canonicalPath, value: resolved.path)
      ),
      sourceReference: executable.path,
      value: RuntimeValue(
        runtimeID: runtime.id,
        label: runtime.label,
        kind: runtime.kind.rawValue,
        packageIdentities: runtime.packageIdentities.map {
          RuntimePackageIdentityValue(managerID: $0.managerID, packageName: $0.packageName)
        },
        executablePath: executable.path,
        resolvedExecutablePath: resolved.path,
        version: version
      )
    )
  }

  private func version(executable: URL, arguments: [String]) -> String? {
    let process = Process()
    let output = Pipe()
    process.executableURL = executable
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = output
    do {
      let completed = DispatchSemaphore(value: 0)
      process.terminationHandler = { _ in completed.signal() }
      try process.run()
      guard completed.wait(timeout: .now() + 2) == .success else {
        process.terminate()
        return nil
      }
      guard process.terminationStatus == 0 else { return nil }
      return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
      return nil
    }
  }
}

public enum RuntimeCollectorError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateRuntimeID
  case invalid(String)
}
