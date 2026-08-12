import Foundation
import HALDomain
import HALManifestKit

public struct HomebrewInstallationConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 2

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
            && !$0.caskroomRelativePath.hasPrefix("/")
            && !$0.caskroomRelativePath.split(separator: "/").contains("..")
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
  public let caskroomRelativePath: String

  public init(
    id: String,
    prefix: String,
    cellarRelativePath: String,
    caskroomRelativePath: String = "Caskroom"
  ) {
    self.id = id
    self.prefix = prefix
    self.cellarRelativePath = cellarRelativePath
    self.caskroomRelativePath = caskroomRelativePath
  }
}

public struct HomebrewCollector: Sendable {
  public static let id: CollectorID = "homebrew-packages"
  public static let version = 2

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
      let caskroom = prefix.appending(path: installation.caskroomRelativePath).standardizedFileURL
      var isDirectory: ObjCBool = false
      let cellarExists = FileManager.default.fileExists(
        atPath: cellar.path,
        isDirectory: &isDirectory
      )
      let cellarIsDirectory = cellarExists && isDirectory.boolValue
      isDirectory = false
      let caskroomExists = FileManager.default.fileExists(
        atPath: caskroom.path,
        isDirectory: &isDirectory
      )
      let caskroomIsDirectory = caskroomExists && isDirectory.boolValue
      guard cellarExists || caskroomExists else {
        continue
      }
      guard (!cellarExists || cellarIsDirectory) && (!caskroomExists || caskroomIsDirectory) else {
        issues.append(
          CollectionIssue(
            id: "invalid-homebrew-root-\(installation.id)",
            severity: .warning,
            summary: "A configured Homebrew inventory location was not a directory.",
            affectedScope: prefix.path
          )
        )
        continue
      }
      do {
        let packages = cellarIsDirectory ? try packages(in: cellar) : []
        let casks = caskroomIsDirectory ? try casks(in: caskroom) : []
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
              caskroomPath: caskroom.path,
              packages: packages,
              casks: casks
            )
          )
        )
      } catch {
        issues.append(
          CollectionIssue(
            id: "unreadable-homebrew-cellar-\(installation.id)",
            severity: .warning,
            summary: "\(AppBrand.displayName) could not read an installed Homebrew inventory.",
            affectedScope: prefix.path
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
      let receipts = versions.compactMap { version in
        formulaReceipt(
          at:
            packageURL
            .appending(path: version, directoryHint: .isDirectory)
            .appending(path: "INSTALL_RECEIPT.json")
        )
      }
      let installedOnRequest: Bool? =
        receipts.contains { $0.installedOnRequest == true }
        ? true
        : (receipts.contains { $0.installedOnRequest != nil } ? false : nil)
      return HomebrewPackageValue(
        name: packageURL.lastPathComponent,
        versions: versions,
        installedOnRequest: installedOnRequest,
        runtimeDependencies: Array(Set(receipts.flatMap(\.runtimeDependencies))).sorted()
      )
    }.sorted { $0.name < $1.name }
  }

  private func formulaReceipt(at url: URL) -> FormulaReceipt? {
    guard
      let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attributes[.size] as? NSNumber,
      size.intValue <= 1_048_576,
      let data = try? Data(contentsOf: url),
      data.count <= 1_048_576
    else { return nil }
    return try? JSONDecoder().decode(FormulaReceipt.self, from: data)
  }

  private struct FormulaReceipt: Decodable {
    let installedOnRequest: Bool?
    let runtimeDependencies: [String]

    private enum CodingKeys: String, CodingKey {
      case installedOnRequest = "installed_on_request"
      case runtimeDependencies = "runtime_dependencies"
    }

    private struct Dependency: Decodable {
      let fullName: String

      private enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
      }
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      installedOnRequest = try container.decodeIfPresent(Bool.self, forKey: .installedOnRequest)
      runtimeDependencies =
        try container.decodeIfPresent([Dependency].self, forKey: .runtimeDependencies)?
        .map(\.fullName) ?? []
    }
  }

  private func casks(in caskroom: URL) throws -> [HomebrewCaskValue] {
    let caskURLs = try FileManager.default.contentsOfDirectory(
      at: caskroom,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    return try caskURLs.compactMap { caskURL in
      guard try caskURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
        return nil
      }
      let versions = try FileManager.default.contentsOfDirectory(
        at: caskURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      ).filter {
        (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
      }.sorted { $0.lastPathComponent < $1.lastPathComponent }
      guard !versions.isEmpty else { return nil }

      let receiptURL = caskURL.appending(path: ".metadata/INSTALL_RECEIPT.json")
      let artifactNames = try installedApplicationNames(from: receiptURL)
      var artifacts: [HomebrewCaskArtifactValue] = []
      for name in artifactNames {
        let identifiers = versions.compactMap { version -> String? in
          Bundle(url: version.appending(path: name))?.bundleIdentifier
        }
        artifacts.append(
          HomebrewCaskArtifactValue(
            applicationName: name,
            bundleIdentifier: identifiers.sorted().first
          )
        )
      }
      return HomebrewCaskValue(
        token: caskURL.lastPathComponent,
        versions: versions.map(\.lastPathComponent),
        artifacts: artifacts.sorted { $0.applicationName < $1.applicationName }
      )
    }.sorted { $0.token < $1.token }
  }

  private func installedApplicationNames(from receiptURL: URL) throws -> [String] {
    guard FileManager.default.fileExists(atPath: receiptURL.path) else { return [] }
    let data = try Data(contentsOf: receiptURL, options: [.mappedIfSafe])
    guard data.count <= 1_048_576,
      let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let artifacts = root["uninstall_artifacts"] as? [[String: Any]]
    else { return [] }
    return Array(
      Set(
        artifacts.flatMap { artifact in
          (artifact["app"] as? [String] ?? []).filter {
            $0.hasSuffix(".app") && !$0.contains("/") && !$0.contains("..")
          }
        }
      )
    ).sorted()
  }
}

public enum HomebrewCollectorError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateInstallationID
  case invalidPath
  case invalid(String)
}
