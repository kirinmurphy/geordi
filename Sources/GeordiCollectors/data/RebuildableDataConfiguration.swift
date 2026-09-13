import Foundation
import GeordiDomain
import GeordiManifestKit

public struct RebuildableDataConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 3

  public let schemaVersion: Int
  public let measurementPolicy: RebuildableDataMeasurementPolicy
  public let classifications: [RebuildableDataClassification]
  public let detectors: [RebuildableDataDetector]

  public init(
    schemaVersion: Int = Self.currentVersion,
    measurementPolicy: RebuildableDataMeasurementPolicy = .safeDefault,
    classifications: [RebuildableDataClassification],
    detectors: [RebuildableDataDetector]
  ) {
    self.schemaVersion = schemaVersion
    self.measurementPolicy = measurementPolicy
    self.classifications = classifications
    self.detectors = detectors
  }

  public static func bundled() throws -> Self {
    guard
      let manifestURL = Bundle.module.url(
        forResource: "rebuildable-data-detectors",
        withExtension: "json"
      ),
      let schemaURL = Bundle.module.url(
        forResource: "rebuildable-data-detectors.schema",
        withExtension: "json"
      )
    else {
      throw RebuildableDataConfigurationError.resourceUnavailable
    }
    return try decode(Data(contentsOf: manifestURL), schema: Data(contentsOf: schemaURL))
  }

  public static func declarativeSchemaData() throws -> Data {
    guard
      let schemaURL = Bundle.module.url(
        forResource: "rebuildable-data-detectors.schema",
        withExtension: "json"
      )
    else {
      throw RebuildableDataConfigurationError.resourceUnavailable
    }
    return try Data(contentsOf: schemaURL)
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let configuration = try JSONDecoder().decode(Self.self, from: data)
      guard configuration.schemaVersion == currentVersion else {
        throw RebuildableDataConfigurationError.unsupportedVersion(
          configuration.schemaVersion
        )
      }
      try configuration.measurementPolicy.validate()
      guard
        Set(configuration.classifications.map(\.id)).count
          == configuration.classifications.count
      else {
        throw RebuildableDataConfigurationError.duplicateClassificationID
      }
      guard Set(configuration.detectors.map(\.id)).count == configuration.detectors.count else {
        throw RebuildableDataConfigurationError.duplicateDetectorID
      }
      let classificationIDs = Set(configuration.classifications.map(\.id))
      for detector in configuration.detectors {
        guard classificationIDs.contains(detector.classificationID) else {
          throw RebuildableDataConfigurationError.unknownClassification(
            detector: detector.id,
            classification: detector.classificationID
          )
        }
        try detector.validate()
      }
      return configuration
    } catch let error as RebuildableDataConfigurationError {
      throw error
    } catch {
      throw RebuildableDataConfigurationError.invalid(String(describing: error))
    }
  }
}

public struct RebuildableDataMeasurementPolicy: Codable, Hashable, Sendable {
  public enum SymbolicLinkPolicy: String, Codable, Hashable, Sendable {
    case doNotFollow
  }

  public enum HardLinkPolicy: String, Codable, Hashable, Sendable {
    case countAllocatedBytesOncePerFileID
  }

  public enum ClonePolicy: String, Codable, Hashable, Sendable {
    case allocatedBytesMayOverlap
  }

  public static let safeDefault = Self(
    maxEntriesPerLocation: 250_000,
    maxDepth: 64,
    maxDurationMilliseconds: 5_000,
    cancellationCheckIntervalEntries: 256,
    stayOnFileSystem: true,
    symbolicLinkPolicy: .doNotFollow,
    hardLinkPolicy: .countAllocatedBytesOncePerFileID,
    clonePolicy: .allocatedBytesMayOverlap
  )

  public let maxEntriesPerLocation: Int
  public let maxDepth: Int
  public let maxDurationMilliseconds: Int
  public let cancellationCheckIntervalEntries: Int
  public let stayOnFileSystem: Bool
  public let symbolicLinkPolicy: SymbolicLinkPolicy
  public let hardLinkPolicy: HardLinkPolicy
  public let clonePolicy: ClonePolicy

  public init(
    maxEntriesPerLocation: Int,
    maxDepth: Int,
    maxDurationMilliseconds: Int,
    cancellationCheckIntervalEntries: Int,
    stayOnFileSystem: Bool,
    symbolicLinkPolicy: SymbolicLinkPolicy,
    hardLinkPolicy: HardLinkPolicy,
    clonePolicy: ClonePolicy
  ) {
    self.maxEntriesPerLocation = maxEntriesPerLocation
    self.maxDepth = maxDepth
    self.maxDurationMilliseconds = maxDurationMilliseconds
    self.cancellationCheckIntervalEntries = cancellationCheckIntervalEntries
    self.stayOnFileSystem = stayOnFileSystem
    self.symbolicLinkPolicy = symbolicLinkPolicy
    self.hardLinkPolicy = hardLinkPolicy
    self.clonePolicy = clonePolicy
  }

  fileprivate func validate() throws {
    guard
      (1...1_000_000).contains(maxEntriesPerLocation),
      (1...128).contains(maxDepth),
      (100...60_000).contains(maxDurationMilliseconds),
      (1...4_096).contains(cancellationCheckIntervalEntries),
      stayOnFileSystem
    else {
      throw RebuildableDataConfigurationError.invalidMeasurementPolicy
    }
  }
}

public struct RebuildableDataClassification: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let label: String
  public let rebuildability: Rebuildability

  public init(id: String, label: String, rebuildability: Rebuildability) {
    self.id = id
    self.label = label
    self.rebuildability = rebuildability
  }
}

public struct RebuildableDataDetector: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let classificationID: String
  public let locations: [RebuildableDataLocation]
  public let excludedDescendantNames: [String]
  public let evidenceRule: RebuildableDataEvidenceRule
  public let manager: RebuildableDataManager?

  public init(
    id: String,
    classificationID: String,
    locations: [RebuildableDataLocation],
    excludedDescendantNames: [String],
    evidenceRule: RebuildableDataEvidenceRule,
    manager: RebuildableDataManager? = nil
  ) {
    self.id = id
    self.classificationID = classificationID
    self.locations = locations
    self.excludedDescendantNames = excludedDescendantNames
    self.evidenceRule = evidenceRule
    self.manager = manager
  }

  fileprivate func validate() throws {
    guard Set(locations.map(\.id)).count == locations.count else {
      throw RebuildableDataConfigurationError.duplicateLocationID(id)
    }
    for location in locations {
      guard
        location.path.hasPrefix("$USER_HOME/"),
        !location.path.contains(".."),
        !location.path.contains("*"),
        !location.path.contains("\0")
      else {
        throw RebuildableDataConfigurationError.invalidPath(location.id)
      }
    }
    for exclusion in excludedDescendantNames {
      guard
        !exclusion.isEmpty,
        exclusion != ".",
        exclusion != "..",
        !exclusion.contains("/"),
        !exclusion.contains("\0")
      else {
        throw RebuildableDataConfigurationError.invalidExclusion(id)
      }
    }
  }

  public func resolvedLocations(userHome: URL) throws -> [URL] {
    try locations.map { location in
      let prefix = "$USER_HOME/"
      guard location.path.hasPrefix(prefix) else {
        throw RebuildableDataConfigurationError.invalidPath(location.id)
      }
      let relative = String(location.path.dropFirst(prefix.count))
      let resolved = userHome.appending(path: relative).standardizedFileURL
      guard resolved.path.hasPrefix(userHome.standardizedFileURL.path + "/") else {
        throw RebuildableDataConfigurationError.invalidPath(location.id)
      }
      return resolved
    }
  }
}

public struct RebuildableDataManager: Codable, Hashable, Sendable {
  public let id: String
  public let label: String

  public init(id: String, label: String) {
    self.id = id
    self.label = label
  }
}

public struct RebuildableDataLocation: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let path: String

  public init(id: String, path: String) {
    self.id = id
    self.path = path
  }
}

public struct RebuildableDataEvidenceRule: Codable, Hashable, Sendable {
  public enum Kind: String, Codable, Hashable, Sendable {
    case toolManagedRoot
    case pathConvention
  }

  public let id: String
  public let kind: Kind
  public let confidence: Confidence
  public let explanation: String

  public init(id: String, kind: Kind, confidence: Confidence, explanation: String) {
    self.id = id
    self.kind = kind
    self.confidence = confidence
    self.explanation = explanation
  }
}

public enum RebuildableDataConfigurationError: Error, Equatable, Sendable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateClassificationID
  case duplicateDetectorID
  case duplicateLocationID(String)
  case unknownClassification(detector: String, classification: String)
  case invalidPath(String)
  case invalidExclusion(String)
  case invalidMeasurementPolicy
  case invalid(String)
}
