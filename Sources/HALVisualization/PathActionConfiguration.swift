import Foundation
import HALManifestKit

public struct TerminalAdapterConfiguration: Codable, Sendable {
  public static let currentVersion = 2
  public let schemaVersion: Int
  public let adapters: [TerminalAdapter]

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "terminal-adapters", withExtension: "json"),
      let schema = Bundle.module.url(forResource: "terminal-adapters.schema", withExtension: "json")
    else { throw TerminalAdapterConfigurationError.resourceUnavailable }
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let value = try JSONDecoder().decode(Self.self, from: data)
      guard value.schemaVersion == currentVersion else {
        throw TerminalAdapterConfigurationError.unsupportedVersion(value.schemaVersion)
      }
      guard Set(value.adapters.map(\.id)).count == value.adapters.count else {
        throw TerminalAdapterConfigurationError.duplicateID
      }
      guard Set(value.adapters.map(\.bundleIdentifier)).count == value.adapters.count else {
        throw TerminalAdapterConfigurationError.duplicateBundleIdentifier
      }
      return value
    } catch let error as TerminalAdapterConfigurationError {
      throw error
    } catch {
      throw TerminalAdapterConfigurationError.invalid(String(describing: error))
    }
  }
}

public struct TerminalAdapter: Codable, Identifiable, Hashable, Sendable {
  public enum Strategy: String, Codable, Sendable {
    case workspaceOpen = "workspace-open"
    case warpNewWindowURL = "warp-new-window-url"
  }

  public let id: String
  public let displayName: String
  public let bundleIdentifier: String
  public let requiredURLSchemes: [String]
  public let strategy: Strategy

  public init(
    id: String,
    displayName: String,
    bundleIdentifier: String,
    requiredURLSchemes: [String] = [],
    strategy: Strategy
  ) {
    self.id = id
    self.displayName = displayName
    self.bundleIdentifier = bundleIdentifier
    self.requiredURLSchemes = requiredURLSchemes
    self.strategy = strategy
  }
}

public struct InstalledTerminalApplication: Hashable, Sendable {
  public let bundleIdentifier: String
  public let declaredURLSchemes: Set<String>

  public init(bundleIdentifier: String, declaredURLSchemes: Set<String> = []) {
    self.bundleIdentifier = bundleIdentifier
    self.declaredURLSchemes = declaredURLSchemes
  }
}

public struct AvailableTerminalAdapter: Hashable, Sendable, Identifiable {
  public let adapter: TerminalAdapter
  public let isRunning: Bool
  public let isPreferred: Bool

  public var id: String { adapter.id }
}

public struct TerminalAvailabilityResolver: Sendable {
  public init() {}

  public func availableAdapters(
    configuration: TerminalAdapterConfiguration,
    installedApplications: [InstalledTerminalApplication],
    runningBundleIdentifiers: Set<String>,
    activationOrder: [String],
    preferredBundleIdentifier: String?
  ) -> [AvailableTerminalAdapter] {
    let installed = Dictionary(
      uniqueKeysWithValues: installedApplications.map { ($0.bundleIdentifier, $0) }
    )
    return configuration.adapters.compactMap { adapter in
      guard let application = installed[adapter.bundleIdentifier],
        Set(adapter.requiredURLSchemes).isSubset(of: application.declaredURLSchemes)
      else { return nil }
      return AvailableTerminalAdapter(
        adapter: adapter,
        isRunning: runningBundleIdentifiers.contains(adapter.bundleIdentifier),
        isPreferred: preferredBundleIdentifier == adapter.bundleIdentifier
      )
    }.sorted { lhs, rhs in
      rank(lhs, activationOrder: activationOrder)
        < rank(rhs, activationOrder: activationOrder)
    }
  }

  private func rank(
    _ available: AvailableTerminalAdapter,
    activationOrder: [String]
  ) -> (Int, Int, String) {
    let activationRank =
      activationOrder.firstIndex(of: available.adapter.bundleIdentifier) ?? Int.max
    return (
      available.isRunning ? 0 : 1,
      available.isRunning ? activationRank : (available.isPreferred ? 0 : 1),
      available.adapter.displayName
    )
  }
}

public enum TerminalPathTarget {
  public static func directoryPath(
    for path: String,
    exists: Bool,
    isDirectory: Bool
  ) -> String? {
    guard path.hasPrefix("/"),
      !URL(fileURLWithPath: path).pathComponents.contains("..")
    else { return nil }
    let target = URL(fileURLWithPath: path).standardizedFileURL
    return exists && isDirectory ? target.path : target.deletingLastPathComponent().path
  }
}

public enum TerminalAdapterConfigurationError: Error, Equatable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateID
  case duplicateBundleIdentifier
  case invalid(String)
}
