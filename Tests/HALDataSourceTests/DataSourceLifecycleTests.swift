import Foundation
import HALDataSource
import HALDomain
import Testing

@Suite("Data source lifecycle")
struct DataSourceLifecycleTests {
  @Test("Stored snapshots are validated before use")
  func invalidStoredSnapshotIsRejected() throws {
    let temporary = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let store = HALUserDataStore(root: temporary.appending(path: "HAL"))
    defer { try? FileManager.default.removeItem(at: temporary) }
    try FileManager.default.createDirectory(at: store.root, withIntermediateDirectories: true)
    let invalid = GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(id: "invalid", name: "Invalid", summary: "Invalid"),
        entities: [],
        relationships: [
          Relationship(
            id: "missing",
            source: "missing-a",
            target: "missing-b",
            type: .owns,
            confidence: .confirmed,
            explanation: "Invalid endpoints",
            evidence: [
              Evidence(
                id: "evidence",
                kind: .observed,
                summary: "Observed",
                source: "Test",
                observedAt: Date(timeIntervalSince1970: 1)
              )
            ]
          )
        ]
      ),
      scan: ScanContext(
        id: "invalid",
        environment: .liveReadOnly,
        startedAt: Date(timeIntervalSince1970: 1)
      )
    )
    let data = try JSONEncoder().encode(invalid)
    try data.write(to: store.root.appending(path: "latest-live-snapshot.json"))

    #expect(throws: HALUserDataStoreError.self) {
      try store.loadSnapshot()
    }
  }

  @Test("Mode defaults to synthetic and persists explicitly")
  func preferenceLifecycle() throws {
    let suite = "HALDataSourceTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = UserDefaultsDataSourcePreferenceStore(defaults: defaults)

    #expect(store.mode() == .synthetic)
    store.setMode(.linkedMac)
    #expect(store.mode() == .linkedMac)
    store.setMode(.synthetic)
    #expect(store.mode() == .synthetic)
  }

  @Test("Snapshot backup and reset stay inside an exact temporary root")
  func backupAndReset() throws {
    let temporary = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let root = temporary.appending(path: "HAL", directoryHint: .isDirectory)
    let backup = temporary.appending(path: "backup.json")
    defer { try? FileManager.default.removeItem(at: temporary) }
    let store = HALUserDataStore(root: root)
    let snapshot = sampleSnapshot()

    try store.saveSnapshot(snapshot)
    #expect(try store.loadSnapshot() == snapshot)
    try store.exportBackup(to: backup)
    #expect(FileManager.default.fileExists(atPath: backup.path))
    try store.reset()
    #expect(!FileManager.default.fileExists(atPath: root.path))
    #expect(FileManager.default.fileExists(atPath: backup.path))
  }

  @Test("Reset refuses a symbolic-link root")
  func resetRejectsSymlink() throws {
    let temporary = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let target = temporary.appending(path: "target", directoryHint: .isDirectory)
    let link = temporary.appending(path: "link", directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: temporary) }
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

    #expect(throws: HALUserDataStoreError.unsafeRoot) {
      try HALUserDataStore(root: link).reset()
    }
  }

  @Test("Reset refuses broad roots")
  func resetRejectsBroadRoots() {
    #expect(throws: HALUserDataStoreError.unsafeRoot) {
      try HALUserDataStore(root: URL(filePath: "/")).reset()
    }
    #expect(throws: HALUserDataStoreError.unsafeRoot) {
      try HALUserDataStore(root: FileManager.default.homeDirectoryForCurrentUser).reset()
    }
  }

  @Test("A replacement backup is complete JSON")
  func backupReplacementIsAtomic() throws {
    let temporary = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let root = temporary.appending(path: "HAL", directoryHint: .isDirectory)
    let backup = temporary.appending(path: "backup.json")
    defer { try? FileManager.default.removeItem(at: temporary) }
    let store = HALUserDataStore(root: root)
    let snapshot = sampleSnapshot()
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    try Data("old".utf8).write(to: backup)

    try store.saveSnapshot(snapshot)
    try store.exportBackup(to: backup)

    let exported = try JSONDecoder().decode(GraphSnapshot.self, from: Data(contentsOf: backup))
    #expect(exported == snapshot)
  }

  private func sampleSnapshot() -> GraphSnapshot {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    return GraphSnapshot(
      graph: SystemGraph(
        metadata: FixtureMetadata(
          id: "live-applications",
          name: "This Mac",
          summary: "Read-only application inventory."
        ),
        entities: [],
        relationships: []
      ),
      scan: ScanContext(
        id: "scan-1",
        environment: .liveReadOnly,
        startedAt: date,
        completedAt: date
      )
    )
  }
}
