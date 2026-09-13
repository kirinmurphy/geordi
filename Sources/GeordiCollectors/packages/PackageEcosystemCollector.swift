import Foundation
import GeordiDomain
import GeordiManifestKit

public struct PackageEcosystemConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1
  public let schemaVersion: Int
  public let ecosystems: [PackageEcosystemDefinition]

  public init(schemaVersion: Int = Self.currentVersion, ecosystems: [PackageEcosystemDefinition]) {
    self.schemaVersion = schemaVersion
    self.ecosystems = ecosystems
  }

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "package-ecosystems", withExtension: "json"),
      let schema = Bundle.module.url(
        forResource: "package-ecosystems.schema",
        withExtension: "json"
      )
    else { throw PackageEcosystemCollectorError.resourceUnavailable }
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let value = try JSONDecoder().decode(Self.self, from: data)
      guard value.schemaVersion == currentVersion else {
        throw PackageEcosystemCollectorError.unsupportedVersion(value.schemaVersion)
      }
      guard Set(value.ecosystems.map(\.id)).count == value.ecosystems.count else {
        throw PackageEcosystemCollectorError.duplicateEcosystemID
      }
      return value
    } catch let error as PackageEcosystemCollectorError {
      throw error
    } catch {
      throw PackageEcosystemCollectorError.invalid(String(describing: error))
    }
  }
}

public struct PackageEcosystemDefinition: Codable, Hashable, Sendable, Identifiable {
  public enum Layout: String, Codable, Hashable, Sendable {
    case nodeModules
    case pythonUserSitePackages
  }

  public let id: String
  public let label: String
  public let layout: Layout
  public let roots: [String]

  public init(id: String, label: String, layout: Layout, roots: [String]) {
    self.id = id
    self.label = label
    self.layout = layout
    self.roots = roots
  }
}

public struct PackageEcosystemCollector: Sendable {
  public static let id: CollectorID = "package-ecosystems"
  public static let version = 1
  private let configuration: PackageEcosystemConfiguration
  private let userHome: URL
  private let clock: any TimeSource

  public init(
    configuration: PackageEcosystemConfiguration,
    userHome: URL = FileManager.default.homeDirectoryForCurrentUser,
    clock: any TimeSource = SystemClock()
  ) {
    self.configuration = configuration
    self.userHome = userHome
    self.clock = clock
  }

  public func collect(scanID: ScanID) -> CollectorOutput<PackageEcosystemInventoryValue> {
    let startedAt = clock.now()
    let observations: [CollectedObservation<PackageEcosystemInventoryValue>] =
      configuration.ecosystems.compactMap { ecosystem in
        let packages = packages(for: ecosystem)
        guard !packages.isEmpty else { return nil }
        return CollectedObservation(
          id: ObservationID("package-ecosystem:\(ecosystem.id)"),
          scanID: scanID,
          collectorID: Self.id,
          schemaVersion: Self.version,
          observedAt: startedAt,
          subject: SubjectIdentity(
            primary: IdentityClaim(kind: .collectorLocal, value: ecosystem.id)
          ),
          value: PackageEcosystemInventoryValue(
            managerID: ecosystem.id,
            managerLabel: ecosystem.label,
            packages: packages
          )
        )
      }
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: .complete,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: configuration.ecosystems.map(\.id)
      ),
      observations: observations
    )
  }

  private func packages(for ecosystem: PackageEcosystemDefinition) -> [ManagedPackageValue] {
    let roots = ecosystem.roots.compactMap(resolve)
    let packages = roots.flatMap { root in
      switch ecosystem.layout {
      case .nodeModules: nodePackages(at: root)
      case .pythonUserSitePackages: pythonPackages(below: root)
      }
    }
    return Dictionary(grouping: packages, by: { "\($0.name)|\($0.path)" })
      .compactMap(\.value.first)
      .sorted { $0.name < $1.name }
  }

  private func resolve(_ path: String) -> URL? {
    if path.hasPrefix("$USER_HOME/") {
      return userHome.appending(path: String(path.dropFirst("$USER_HOME/".count)))
    }
    guard path.hasPrefix("/"), !path.contains("..") else { return nil }
    return URL(filePath: path)
  }

  private func nodePackages(at root: URL) -> [ManagedPackageValue] {
    guard
      let entries = try? FileManager.default.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else { return [] }
    return entries.flatMap { entry -> [URL] in
      if entry.lastPathComponent.hasPrefix("@") {
        return
          (try? FileManager.default.contentsOfDirectory(
            at: entry,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
          )) ?? []
      }
      return [entry]
    }.compactMap { packageURL in
      guard
        let data = try? Data(contentsOf: packageURL.appending(path: "package.json")),
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let name = object["name"] as? String
      else { return nil }
      return ManagedPackageValue(
        name: name,
        version: object["version"] as? String,
        path: packageURL.path
      )
    }
  }

  private func pythonPackages(below root: URL) -> [ManagedPackageValue] {
    guard
      let versions = try? FileManager.default.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else { return [] }
    return versions.flatMap { versionRoot in
      let sitePackages = versionRoot.appending(path: "lib/python/site-packages")
      guard
        let entries = try? FileManager.default.contentsOfDirectory(
          at: sitePackages,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles]
        )
      else { return [ManagedPackageValue]() }
      return entries.compactMap { entry in
        let filename = entry.lastPathComponent
        guard filename.hasSuffix(".dist-info") else { return nil }
        let stem = String(filename.dropLast(".dist-info".count))
        let parts = stem.split(separator: "-", maxSplits: 1).map(String.init)
        return ManagedPackageValue(
          name: parts[0].replacingOccurrences(of: "_", with: "-"),
          version: parts.count > 1 ? parts[1] : nil,
          path: entry.path
        )
      }
    }
  }
}

public enum PackageEcosystemCollectorError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateEcosystemID
  case invalid(String)
}
