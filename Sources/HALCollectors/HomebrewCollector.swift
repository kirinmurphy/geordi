import Foundation
import HALDomain
import HALManifestKit

public struct HomebrewInstallationConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let installations: [HomebrewInstallation]

  public init(
    schemaVersion: Int = Self.currentVersion,
    installations: [HomebrewInstallation]
  ) {
    self.schemaVersion = schemaVersion
    self.installations = installations
  }

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(
        forResource: "homebrew-installations",
        withExtension: "json"
      ),
      let schema = Bundle.module.url(
        forResource: "homebrew-installations.schema",
        withExtension: "json"
      )
    else {
      throw HomebrewCollectorError.resourceUnavailable
    }
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schema = Bundle.module.url(
        forResource: "homebrew-installations.schema",
        withExtension: "json"
      )
    else {
      throw HomebrewCollectorError.resourceUnavailable
    }
    return try Data(contentsOf: schema)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw HomebrewCollectorError.unsupportedVersion(configuration.schemaVersion)
      }
      guard Set(configuration.installations.map(\.id)).count == configuration.installations.count
      else {
        throw HomebrewCollectorError.duplicateInstallationID
      }
      guard
        configuration.installations.allSatisfy({
          $0.prefix.hasPrefix("/") && !$0.prefix.contains("..")
            && !$0.cellarRelativePath.hasPrefix("/")
            && !$0.cellarRelativePath.split(separator: "/").contains("..")
        })
      else {
        throw HomebrewCollectorError.invalidPath
      }
      return configuration
    } catch let error as HomebrewCollectorError {
      throw error
    } catch {
      throw HomebrewCollectorError.invalid(String(describing: error))
    }
  }
}

public struct HomebrewInstallation: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let prefix: String
  public let cellarRelativePath: String

  public init(id: String, prefix: String, cellarRelativePath: String) {
    self.id = id
    self.prefix = prefix
    self.cellarRelativePath = cellarRelativePath
  }
}

public struct HomebrewCollector: Sendable {
  public static let id: CollectorID = "homebrew-packages"
  public static let version = 1

  private let configuration: HomebrewInstallationConfiguration
  private let clock: any HALClock

  public init(
    configuration: HomebrewInstallationConfiguration,
    clock: any HALClock = SystemClock()
  ) {
    self.configuration = configuration
    self.clock = clock
  }

  public func collect(scanID: ScanID) -> CollectorOutput<HomebrewInventoryValue> {
    let startedAt = clock.now()
    var observations: [CollectedObservation<HomebrewInventoryValue>] = []
    var issues: [CollectionIssue] = []

    for installation in configuration.installations {
      let prefix = URL(filePath: installation.prefix).standardizedFileURL
      let cellar = prefix.appending(path: installation.cellarRelativePath).standardizedFileURL
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: cellar.path, isDirectory: &isDirectory) else {
        continue
      }
      guard isDirectory.boolValue else {
        issues.append(
          CollectionIssue(
            id: "invalid-homebrew-cellar-\(installation.id)",
            severity: .warning,
            summary: "A configured Homebrew Cellar was not a directory.",
            affectedScope: cellar.path
          )
        )
        continue
      }
      do {
        let packages = try packages(in: cellar)
        observations.append(
          CollectedObservation(
            id: ObservationID("homebrew:\(prefix.path)"),
            scanID: scanID,
            collectorID: Self.id,
            schemaVersion: Self.version,
            observedAt: startedAt,
            subject: SubjectIdentity(
              primary: IdentityClaim(kind: .canonicalPath, value: prefix.path)
            ),
            sourceReference: cellar.path,
            value: HomebrewInventoryValue(
              prefix: prefix.path,
              cellarPath: cellar.path,
              packages: packages
            )
          )
        )
      } catch {
        issues.append(
          CollectionIssue(
            id: "unreadable-homebrew-cellar-\(installation.id)",
            severity: .warning,
            summary: "HAL could not read an installed Homebrew package inventory.",
            affectedScope: cellar.path
          )
        )
      }
    }

    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: issues.isEmpty ? .complete : .partial,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: configuration.installations.map(\.prefix),
        issues: issues
      ),
      observations: observations
    )
  }

  private func packages(in cellar: URL) throws -> [HomebrewPackageValue] {
    let packageURLs = try FileManager.default.contentsOfDirectory(
      at: cellar,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    return try packageURLs.compactMap { packageURL in
      guard
        try packageURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
      else { return nil }
      let versions = try FileManager.default.contentsOfDirectory(
        at: packageURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      ).filter {
        (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
      }.map(\.lastPathComponent).sorted()
      guard !versions.isEmpty else { return nil }
      return HomebrewPackageValue(name: packageURL.lastPathComponent, versions: versions)
    }.sorted { $0.name < $1.name }
  }
}

public enum HomebrewCollectorError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateInstallationID
  case invalidPath
  case invalid(String)
}
