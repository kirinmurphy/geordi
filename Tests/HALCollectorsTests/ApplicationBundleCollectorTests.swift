import Foundation
import HALCollectors
import HALDomain
import Testing

@Suite("Application bundle collector")
struct ApplicationBundleCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Collector reads bundle metadata without descending into bundles")
  func bundleMetadata() throws {
    let root = try temporaryDirectory()
    let app = root.appending(path: "Example.app")
    try createBundle(
      at: app,
      name: "Example Application",
      identifier: "com.example.application",
      version: "2.3",
      build: "45"
    )
    try createBundle(
      at: app.appending(path: "Contents/Helpers/Nested.app"),
      name: "Nested Helper",
      identifier: "com.example.nested",
      version: "1.0",
      build: "1"
    )

    let output = ApplicationBundleCollector(
      roots: [ApplicationSearchRoot(url: root, required: true)],
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(output.run.state == .complete)
    #expect(output.observations.count == 1)
    let observation = try #require(output.observations.first)
    #expect(observation.value.name == "Example Application")
    #expect(observation.value.bundleIdentifier == "com.example.application")
    #expect(observation.value.version == "2.3")
    #expect(observation.subject.primary.kind == .bundleIdentifier)
    #expect(observation.observedAt == timestamp)
  }

  @Test("Missing optional and required roots remain distinguishable")
  func missingRoots() throws {
    let parent = try temporaryDirectory()
    let missing = parent.appending(path: "Missing")

    let optional = ApplicationBundleCollector(
      roots: [ApplicationSearchRoot(url: missing)],
      clock: FixedClock(timestamp)
    ).collect(scanID: "optional")
    #expect(optional.run.state == .complete)
    #expect(optional.run.issues.isEmpty)

    let required = ApplicationBundleCollector(
      roots: [ApplicationSearchRoot(url: missing, required: true)],
      clock: FixedClock(timestamp)
    ).collect(scanID: "required")
    #expect(required.run.state == .partial)
    #expect(required.run.issues.count == 1)
    #expect(required.run.issues.first?.affectedScope == missing.path)
  }

  @Test("Projector preserves collection context and typed metadata")
  func projection() async throws {
    let root = try temporaryDirectory()
    try createBundle(
      at: root.appending(path: "Example.app"),
      name: "Example",
      identifier: "com.example.application",
      version: "1.0",
      build: "7"
    )
    let collector = ApplicationBundleCollector(
      roots: [ApplicationSearchRoot(url: root, required: true)],
      clock: FixedClock(timestamp)
    )
    let output = collector.collect(scanID: "projection")
    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "projection",
      output: output
    )

    try snapshot.graph.validate()
    #expect(snapshot.scan.environment == .liveReadOnly)
    #expect(snapshot.scan.completedAt == timestamp)
    #expect(snapshot.graph.entities.count == 1)
    #expect(
      snapshot.graph.entities.first?.details.contains {
        $0.label == "Bundle identifier" && $0.value == "com.example.application"
      } == true
    )
  }

  @Test("Live provider remains explicit and deterministic with injected scope")
  func liveProvider() async throws {
    let root = try temporaryDirectory()
    try createBundle(
      at: root.appending(path: "Example.app"),
      name: "Example",
      identifier: "com.example.application",
      version: "1.0",
      build: "7"
    )
    let provider = ApplicationInventorySnapshotProvider(
      scanID: "manual-scan",
      roots: [ApplicationSearchRoot(url: root, required: true)],
      provenanceConfiguration: ApplicationProvenanceConfiguration(
        adapters: [
          ApplicationProvenanceAdapterConfiguration(
            id: "test-receipt",
            kind: .appStoreReceipt,
            displayLabel: "Test receipt"
          )
        ]
      ),
      associatedLocationConfiguration: ApplicationAssociatedLocationConfiguration(
        locations: []
      ),
      processConfiguration: ProcessCollectorConfiguration(
        maxProcessesPerApplication: 8,
        strategies: []
      ),
      persistenceRoots: [],
      signatureInspector: StubProviderSignatureInspector(),
      provenanceInspector: StubProviderProvenanceInspector(),
      associatedLocationInspector: StubAssociatedLocationInspector(),
      processSampler: EmptyProcessSampler(),
      clock: FixedClock(timestamp)
    )

    let snapshot = try await provider.cancellableSnapshot()
    #expect(snapshot.scan.id == "manual-scan")
    #expect(snapshot.scan.environment == .liveReadOnly)
    #expect(snapshot.graph.entities.map(\.name) == ["Example"])
  }

  @Test("Live provider rejects an unexplained empty application inventory")
  func emptyLiveProviderFails() async throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let provider = ApplicationInventorySnapshotProvider(
      scanID: "empty-scan",
      roots: [ApplicationSearchRoot(url: root, required: true)],
      provenanceConfiguration: ApplicationProvenanceConfiguration(adapters: []),
      associatedLocationConfiguration: ApplicationAssociatedLocationConfiguration(locations: []),
      processConfiguration: ProcessCollectorConfiguration(
        maxProcessesPerApplication: 8,
        strategies: []
      ),
      persistenceRoots: [],
      signatureInspector: StubProviderSignatureInspector(),
      provenanceInspector: StubProviderProvenanceInspector(),
      associatedLocationInspector: StubAssociatedLocationInspector(),
      processSampler: EmptyProcessSampler(),
      clock: FixedClock(timestamp)
    )

    await #expect(throws: ApplicationInventorySnapshotError.noApplicationsObserved) {
      try await provider.cancellableSnapshot()
    }
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func createBundle(
    at url: URL,
    name: String,
    identifier: String,
    version: String,
    build: String
  ) throws {
    let contents = url.appending(path: "Contents", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let plist: [String: Any] = [
      "CFBundlePackageType": "APPL",
      "CFBundleName": name,
      "CFBundleIdentifier": identifier,
      "CFBundleShortVersionString": version,
      "CFBundleVersion": build,
      "CFBundleExecutable": "Example",
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist,
      format: .xml,
      options: 0
    )
    try data.write(to: contents.appending(path: "Info.plist"))
  }
}

private struct StubAssociatedLocationInspector: AssociatedLocationInspecting {
  func inspectLocation(at url: URL) -> AssociatedLocationInspection {
    AssociatedLocationInspection(status: .absent)
  }
}

private struct EmptyProcessSampler: ProcessSampling {
  func sample() throws -> [ProcessValue] { [] }
}

private struct StubProviderSignatureInspector: CodeSignatureInspecting {
  func inspectApplication(at url: URL) -> ApplicationSignatureValue {
    ApplicationSignatureValue(
      applicationPath: url.path,
      status: .valid,
      signingIdentifier: "com.example.application",
      teamIdentifier: "TEAM123"
    )
  }
}

private struct StubProviderProvenanceInspector: ApplicationProvenanceInspecting {
  func inspectApplication(
    at url: URL,
    adapters: [ApplicationProvenanceAdapterConfiguration]
  ) -> [ApplicationProvenanceFact] {
    [
      ApplicationProvenanceFact(
        kind: .appStoreReceipt,
        displayLabel: "Test receipt",
        status: .absent,
        source: "Test"
      )
    ]
  }
}
