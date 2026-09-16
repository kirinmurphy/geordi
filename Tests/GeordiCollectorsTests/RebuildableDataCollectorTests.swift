import Foundation
import GeordiCollectors
import GeordiDomain
import Testing

@Suite("Rebuildable-data collector")
struct RebuildableDataCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Collector preserves metadata states without traversing configured roots")
  func metadataStates() {
    let output = RebuildableDataCollector(
      configuration: configuration(paths: [
        ("present", "$USER_HOME/present"),
        ("absent", "$USER_HOME/absent"),
        ("denied", "$USER_HOME/denied"),
        ("unreadable", "$USER_HOME/unreadable"),
        ("link", "$USER_HOME/link"),
      ]),
      userHome: URL(fileURLWithPath: "/test-home"),
      inspector: StubRebuildableDataInspector(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(
      output.observations.map(\.value.status) == [
        .absent, .permissionDenied, .present, .present, .unreadable,
      ])
    #expect(
      output.observations.first { $0.value.locationID == "link" }?.value.isSymbolicLink == true
    )
    #expect(output.run.state == .partial)
    #expect(output.run.issues.count == 3)
    #expect(output.observations.allSatisfy { $0.value.excludedDescendantNames == [".git"] })
  }

  @Test("Filesystem inspection does not descend into a rebuildable-data root")
  func filesystemMetadataOnly() throws {
    let root = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("collectors must not read this".utf8).write(to: root.appending(path: "private.txt"))
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(
      FileSystemRebuildableDataInspector().inspectLocation(at: root)
        == RebuildableDataInspection(
          status: .present,
          isDirectory: true,
          isSymbolicLink: false
        )
    )
  }

  @Test("Collector refuses a configured location that resolves outside the user home")
  func refusesSymlinkEscape() throws {
    let base = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let home = base.appending(path: "home", directoryHint: .isDirectory)
    let library = home.appending(path: "Library", directoryHint: .isDirectory)
    let outside = base.appending(path: "outside", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: library.appending(path: "Caches"),
      withDestinationURL: outside
    )
    defer { try? FileManager.default.removeItem(at: base) }

    let output = RebuildableDataCollector(
      configuration: configuration(paths: [
        ("escaped", "$USER_HOME/Library/Caches")
      ]),
      userHome: home,
      inspector: StubRebuildableDataInspector(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(output.observations.isEmpty)
    #expect(output.run.state == .partial)
    #expect(
      output.run.issues.map(\.id) == [
        "rebuildable-data-escaped-root-test-detector-escaped"
      ])
  }

  @Test("Projection exposes safe present roots without inventing sizes")
  func projection() throws {
    let output = RebuildableDataCollector(
      configuration: configuration(paths: [
        ("present", "$USER_HOME/present"),
        ("link", "$USER_HOME/link"),
      ]),
      userHome: URL(fileURLWithPath: "/test-home"),
      inspector: StubRebuildableDataInspector(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")
    let applications = CollectorOutput<ApplicationBundleValue>(
      run: CollectorRun(
        collectorID: ApplicationBundleCollector.id,
        collectorVersion: 1,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: []
    )

    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: applications,
      rebuildableData: output
    )

    try snapshot.graph.validate()
    #expect(snapshot.graph.entities.count == 1)
    #expect(snapshot.graph.entities[0].name == "present")
    #expect(
      snapshot.graph.entities[0].details.first { $0.label == "Size" }?.value == "Not collected")
    #expect(snapshot.scan.collectorRuns.contains { $0.collectorID == RebuildableDataCollector.id })
  }

  @Test("Size walk counts allocated bytes once, skips symlinks and excluded names")
  func sizeMeasurement() throws {
    let base = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let root = base.appending(path: "home/root", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data(repeating: 0x41, count: 10_000).write(to: root.appending(path: "a.bin"))
    let sub = root.appending(path: "sub", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
    try Data(repeating: 0x42, count: 5_000).write(to: sub.appending(path: "b.bin"))
    try FileManager.default.createSymbolicLink(
      at: root.appending(path: "link"), withDestinationURL: root.appending(path: "a.bin"))
    try FileManager.default.createDirectory(
      at: root.appending(path: ".git"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    let output = RebuildableDataCollector(
      configuration: configuration(paths: [("root", "$USER_HOME/root")]),
      userHome: base.appending(path: "home"),
      inspector: FileSystemRebuildableDataInspector(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    let measurement = try #require(
      output.observations.first { $0.value.locationID == "root" }?.value.measuredSize)
    #expect(!measurement.isTruncated)
    // a.bin + sub + b.bin + link + .git are all entries; b.bin lives in sub.
    #expect(measurement.entryCount == 5)
    // Both files counted (allocated ≥ logical), symlink not followed,
    // .git skipped from the walk's byte total.
    #expect(measurement.allocatedBytes >= 15_000)
    #expect(measurement.allocatedBytes < 40_000)
  }

  @Test("Size walk truncates at the entry budget and reports a lower bound")
  func sizeTruncation() throws {
    let base = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let root = base.appending(path: "home/root", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    for name in ["a", "b", "c"] {
      try Data(repeating: 0x41, count: 1_000).write(to: root.appending(path: "\(name).bin"))
    }
    defer { try? FileManager.default.removeItem(at: base) }

    var config = configuration(paths: [("root", "$USER_HOME/root")])
    config = RebuildableDataConfiguration(
      measurementPolicy: RebuildableDataMeasurementPolicy(
        maxEntriesPerLocation: 2,
        maxDepth: 8,
        maxDurationMilliseconds: 5_000,
        cancellationCheckIntervalEntries: 256,
        stayOnFileSystem: true,
        symbolicLinkPolicy: .doNotFollow,
        hardLinkPolicy: .countAllocatedBytesOncePerFileID,
        clonePolicy: .allocatedBytesMayOverlap
      ),
      classifications: config.classifications,
      detectors: config.detectors
    )

    let output = RebuildableDataCollector(
      configuration: config,
      userHome: base.appending(path: "home"),
      inspector: FileSystemRebuildableDataInspector(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    let measurement = try #require(
      output.observations.first { $0.value.locationID == "root" }?.value.measuredSize)
    #expect(measurement.isTruncated)
    #expect(measurement.entryCount == 2)
    #expect(measurement.displayLabel.hasPrefix("≥"))
  }

  private func configuration(
    paths: [(id: String, path: String)]
  ) -> RebuildableDataConfiguration {
    RebuildableDataConfiguration(
      classifications: [
        RebuildableDataClassification(
          id: "build",
          label: "Build output",
          rebuildability: .rebuildable
        )
      ],
      detectors: [
        RebuildableDataDetector(
          id: "test-detector",
          classificationID: "build",
          locations: paths.map { RebuildableDataLocation(id: $0.id, path: $0.path) },
          excludedDescendantNames: [".git"],
          evidenceRule: RebuildableDataEvidenceRule(
            id: "test-rule",
            kind: .toolManagedRoot,
            confidence: .high,
            explanation: "The test tool manages this root."
          )
        )
      ]
    )
  }
}

private struct StubRebuildableDataInspector: RebuildableDataInspecting {
  func inspectLocation(at url: URL) -> RebuildableDataInspection {
    switch url.lastPathComponent {
    case "present":
      RebuildableDataInspection(
        status: .present,
        isDirectory: true,
        isSymbolicLink: false
      )
    case "denied":
      RebuildableDataInspection(status: .permissionDenied)
    case "unreadable":
      RebuildableDataInspection(status: .unreadable)
    case "link":
      RebuildableDataInspection(
        status: .present,
        isDirectory: false,
        isSymbolicLink: true
      )
    default:
      RebuildableDataInspection(status: .absent)
    }
  }
}
