import Foundation
import HALDomain

public enum DataSourceMode: String, Codable, Sendable {
  case synthetic
  case linkedMac
}

public protocol DataSourcePreferenceStore: Sendable {
  func mode() -> DataSourceMode
  func setMode(_ mode: DataSourceMode)
  func syntheticWelcomeDismissed() -> Bool
  func setSyntheticWelcomeDismissed(_ dismissed: Bool)
  func linkedCompletionDismissed() -> Bool
  func setLinkedCompletionDismissed(_ dismissed: Bool)
}

extension DataSourcePreferenceStore {
  public func linkedCompletionDismissed() -> Bool { false }
  public func setLinkedCompletionDismissed(_ dismissed: Bool) {}
}

public final class UserDefaultsDataSourcePreferenceStore: DataSourcePreferenceStore,
  @unchecked Sendable
{
  private enum Key {
    static let mode = "dataSource.mode"
    static let welcomeDismissed = "dataSource.syntheticWelcomeDismissed"
    static let linkedCompletionDismissed = "dataSource.linkedCompletionDismissed"
  }

  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func mode() -> DataSourceMode {
    defaults.string(forKey: Key.mode).flatMap(DataSourceMode.init(rawValue:)) ?? .synthetic
  }

  public func setMode(_ mode: DataSourceMode) {
    defaults.set(mode.rawValue, forKey: Key.mode)
  }

  public func syntheticWelcomeDismissed() -> Bool {
    defaults.bool(forKey: Key.welcomeDismissed)
  }

  public func setSyntheticWelcomeDismissed(_ dismissed: Bool) {
    defaults.set(dismissed, forKey: Key.welcomeDismissed)
  }

  public func linkedCompletionDismissed() -> Bool {
    defaults.bool(forKey: Key.linkedCompletionDismissed)
  }

  public func setLinkedCompletionDismissed(_ dismissed: Bool) {
    defaults.set(dismissed, forKey: Key.linkedCompletionDismissed)
  }
}

public struct HALUserDataStore: Sendable {
  public let root: URL

  public init(root: URL) {
    self.root = root.standardizedFileURL
  }

  public static func applicationSupport(
    fileManager: FileManager = .default
  ) throws -> Self {
    let base = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    return Self(root: base.appending(path: "HAL", directoryHint: .isDirectory))
  }

  public func loadSnapshot(fileManager: FileManager = .default) throws -> GraphSnapshot? {
    let url = snapshotURL
    guard fileManager.fileExists(atPath: url.path) else { return nil }
    return try JSONDecoder().decode(GraphSnapshot.self, from: Data(contentsOf: url))
  }

  public func saveSnapshot(
    _ snapshot: GraphSnapshot,
    fileManager: FileManager = .default
  ) throws {
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    let data = try JSONEncoder.sorted.encode(snapshot)
    try data.write(to: snapshotURL, options: .atomic)
  }

  public func exportBackup(
    to destination: URL,
    fileManager: FileManager = .default
  ) throws {
    guard fileManager.fileExists(atPath: snapshotURL.path) else {
      throw HALUserDataStoreError.noCompiledData
    }
    guard destination.standardizedFileURL != root else {
      throw HALUserDataStoreError.unsafeDestination
    }
    let data = try Data(contentsOf: snapshotURL)
    try data.write(to: destination, options: .atomic)
  }

  public func reset(fileManager: FileManager = .default) throws {
    let standardized = root.standardizedFileURL
    guard
      standardized.pathComponents.count >= 3,
      standardized.path != "/",
      standardized.path != fileManager.homeDirectoryForCurrentUser.standardizedFileURL.path
    else {
      throw HALUserDataStoreError.unsafeRoot
    }
    guard fileManager.fileExists(atPath: standardized.path) else { return }
    let values = try standardized.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
    guard values.isDirectory == true, values.isSymbolicLink != true else {
      throw HALUserDataStoreError.unsafeRoot
    }
    try fileManager.removeItem(at: standardized)
  }

  private var snapshotURL: URL {
    root.appending(path: "latest-live-snapshot.json")
  }
}

public enum HALUserDataStoreError: Error, Equatable, Sendable {
  case noCompiledData
  case unsafeDestination
  case unsafeRoot
}

extension HALUserDataStoreError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .noCompiledData:
      "There is no compiled live snapshot to export."
    case .unsafeDestination:
      "The selected backup destination is inside HAL's managed data location."
    case .unsafeRoot:
      "HAL refused to remove an unexpected or unsafe data location."
    }
  }
}

extension JSONEncoder {
  fileprivate static var sorted: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }
}
