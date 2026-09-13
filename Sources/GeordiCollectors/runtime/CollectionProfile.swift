import Foundation
import GeordiDomain
import GeordiManifestKit

public struct CollectionProfile: Codable, Hashable, Sendable {
  public static let currentVersion = 1

  public let schemaVersion: Int
  public let maxConcurrentTasks: Int
  public let collectors: [CollectionProfileEntry]

  public init(
    schemaVersion: Int = Self.currentVersion,
    maxConcurrentTasks: Int,
    collectors: [CollectionProfileEntry]
  ) {
    self.schemaVersion = schemaVersion
    self.maxConcurrentTasks = maxConcurrentTasks
    self.collectors = collectors
  }

  public static func bundled() throws -> Self {
    try BundledManifestResource<Self>(
      manifestName: "collection-profile",
      schemaName: "collection-profile.schema",
      bundle: .module
    ).load { profile in
      guard profile.schemaVersion == currentVersion else {
        throw CollectionProfileError.unsupportedVersion(profile.schemaVersion)
      }
      guard Set(profile.collectors.map(\.id)).count == profile.collectors.count else {
        throw CollectionProfileError.duplicateCollectorID
      }
      let required = Set(CollectionAdapterID.required.map(\.rawValue))
      let configured = Set(profile.collectors.filter(\.enabled).map(\.id))
      let missing = required.subtracting(configured)
      guard missing.isEmpty else {
        throw CollectionProfileError.missingRequiredCollectors(missing.sorted())
      }
    }
  }
}

public struct CollectionProfileEntry: Codable, Hashable, Sendable {
  public let id: String
  public let enabled: Bool
  public let required: Bool

  public init(id: String, enabled: Bool, required: Bool) {
    self.id = id
    self.enabled = enabled
    self.required = required
  }
}

public enum CollectionAdapterID: String, CaseIterable, Sendable {
  case applications
  case applicationSignatures
  case applicationProvenance
  case associatedLocations
  case rebuildableData
  case processes
  case persistence
  case persistenceRuntimeCorrelation
  case homebrew
  case runtimes
  case packageEcosystems
  case commandLineSoftware
  case shellFrameworks
  case applicationClassifications

  fileprivate static let required: [Self] = [
    .applications,
    .applicationSignatures,
    .applicationProvenance,
    .associatedLocations,
    .processes,
    .persistence,
    .applicationClassifications,
  ]
}

public enum CollectionProfileError: Error, Equatable, Sendable {
  case unsupportedVersion(Int)
  case duplicateCollectorID
  case missingRequiredCollectors([String])
}

extension CollectionProfileError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .unsupportedVersion(let version):
      "Collection profile version \(version) is unsupported."
    case .duplicateCollectorID:
      "Collection profile collector identifiers must be unique."
    case .missingRequiredCollectors(let identifiers):
      "Collection profile is missing required collectors: \(identifiers.joined(separator: ", "))."
    }
  }
}

public struct LiveApplicationSnapshotFactory: Sendable {
  public let profile: CollectionProfile

  public init(profile: CollectionProfile) {
    self.profile = profile
  }

  public static func bundled() throws -> Self {
    Self(profile: try CollectionProfile.bundled())
  }

  public func snapshot(scanID: ScanID) async throws -> GraphSnapshot {
    let enabled = Set(profile.collectors.filter(\.enabled).map(\.id))
    func includes(_ id: CollectionAdapterID) -> Bool { enabled.contains(id.rawValue) }

    let applicationConfiguration = try ApplicationCollectorConfiguration.bundled()
    let provenanceConfiguration = try ApplicationProvenanceConfiguration.bundled()
    let associatedLocationConfiguration =
      try ApplicationAssociatedLocationConfiguration.bundled()
    let processConfiguration = try ProcessCollectorConfiguration.bundled()
    let persistenceConfiguration = try PersistenceCollectorConfiguration.bundled()
    let classifications = try ApplicationClassificationConfiguration.bundled()

    return try await ApplicationInventorySnapshotProvider(
      scanID: scanID,
      configuration: applicationConfiguration,
      provenanceConfiguration: provenanceConfiguration,
      associatedLocationConfiguration: associatedLocationConfiguration,
      rebuildableDataConfiguration:
        includes(.rebuildableData) ? try RebuildableDataConfiguration.bundled() : nil,
      processConfiguration: processConfiguration,
      persistenceConfiguration: persistenceConfiguration,
      persistenceRuntimeMatchingConfiguration:
        includes(.persistenceRuntimeCorrelation)
        ? try PersistenceRuntimeMatchingConfiguration.bundled() : nil,
      homebrewConfiguration:
        includes(.homebrew) ? try HomebrewInstallationConfiguration.bundled() : nil,
      runtimeConfiguration:
        includes(.runtimes) ? try RuntimeCollectorConfiguration.bundled() : nil,
      packageEcosystemConfiguration:
        includes(.packageEcosystems) ? try PackageEcosystemConfiguration.bundled() : nil,
      commandLineSoftwareConfiguration:
        includes(.commandLineSoftware) ? try CommandLineSoftwareConfiguration.bundled() : nil,
      shellFrameworkConfiguration:
        includes(.shellFrameworks) ? try ShellFrameworkConfiguration.bundled() : nil,
      applicationClassifications: classifications
    ).cancellableSnapshot(maxConcurrentTasks: profile.maxConcurrentTasks)
  }
}
