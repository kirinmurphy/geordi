import Foundation
import GeordiCollectors
import GeordiDomain
import Testing

@Suite("Application provenance collector")
struct ApplicationProvenanceCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Bundled adapters are declarative and schema validated")
  func bundledConfiguration() throws {
    let configuration = try ApplicationProvenanceConfiguration.bundled()
    #expect(configuration.schemaVersion == 3)
    #expect(configuration.adapters.map(\.kind) == [.appStoreReceipt, .downloadOrigin])
  }

  @Test("Unknown configuration keys fail declarative validation")
  func unknownConfigurationKey() throws {
    let data = Data(
      """
      {
        "schemaVersion": 3,
        "adapters": [
          {
            "id": "receipt",
            "kind": "appStoreReceipt",
            "displayLabel": "Receipt",
            "unexpected": true
          }
        ]
      }
      """.utf8
    )

    #expect(throws: ApplicationProvenanceConfigurationError.self) {
      try ApplicationProvenanceConfiguration.decode(
        data,
        schema: ApplicationProvenanceConfiguration.declarativeSchemaData()
      )
    }
  }

  @Test("Collector preserves present, absent, and unreadable facts")
  func explicitStates() throws {
    let application = CollectedObservation(
      id: ObservationID("application"),
      scanID: ScanID("scan"),
      collectorID: ApplicationBundleCollector.id,
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .bundleIdentifier, value: "com.example.application")
      ),
      value: ApplicationBundleValue(
        path: "/Applications/Example.app",
        name: "Example"
      )
    )
    let configuration = ApplicationProvenanceConfiguration(
      adapters: [
        ApplicationProvenanceAdapterConfiguration(
          id: "receipt",
          kind: .appStoreReceipt,
          displayLabel: "Receipt"
        ),
        ApplicationProvenanceAdapterConfiguration(
          id: "origin",
          kind: .downloadOrigin,
          displayLabel: "Origin"
        ),
      ]
    )
    let output = ApplicationProvenanceCollector(
      configuration: configuration,
      inspector: StubProvenanceInspector(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan", applications: [application])

    #expect(output.run.state == .partial)
    #expect(output.run.issues.count == 1)
    #expect(output.observations.first?.value.facts.map(\.status) == [.present, .unreadable])
  }

  @Test("Receipt adapter observes presence without reading receipt contents")
  func receiptPresence() throws {
    let root = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let app = root.appending(path: "Example.app", directoryHint: .isDirectory)
    let receipt = app.appending(path: "Contents/_MASReceipt/receipt")
    try FileManager.default.createDirectory(
      at: receipt.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("private receipt payload".utf8).write(to: receipt)
    defer { try? FileManager.default.removeItem(at: root) }

    let inspector = FileSystemApplicationProvenanceInspector()
    let facts = inspector.inspectApplication(
      at: app,
      adapters: [
        ApplicationProvenanceAdapterConfiguration(
          id: "receipt",
          kind: .appStoreReceipt,
          displayLabel: "App Store receipt"
        )
      ]
    )

    #expect(facts.count == 1)
    #expect(facts.first?.status == .present)
    #expect(facts.first?.detail == nil)
  }

  @Test("Projection does not infer a web download from missing metadata")
  func negativeProjection() throws {
    let application = applicationOutput()
    let provenance = CollectorOutput(
      run: CollectorRun(
        collectorID: ApplicationProvenanceCollector.id,
        collectorVersion: 1,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: [
        CollectedObservation(
          id: "provenance",
          scanID: "scan",
          collectorID: ApplicationProvenanceCollector.id,
          schemaVersion: 1,
          observedAt: timestamp,
          subject: application.observations[0].subject,
          value: ApplicationProvenanceValue(
            applicationPath: "/Applications/Example.app",
            facts: [
              ApplicationProvenanceFact(
                kind: .downloadOrigin,
                displayLabel: "Download origin",
                status: .absent,
                source: "Test"
              )
            ]
          )
        )
      ]
    )

    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: application,
      provenance: provenance
    )
    let detail = try #require(
      snapshot.graph.entities.first?.details.first { $0.label == "Download origin" }
    )
    #expect(detail.value == "Not observed")
    #expect(!detail.value.localizedCaseInsensitiveContains("web"))
    #expect(
      snapshot.scan.collectorRuns.map(\.collectorID) == [
        ApplicationBundleCollector.id,
        ApplicationProvenanceCollector.id,
      ])
  }

  @Test("Present App Store receipts project a navigable software source")
  func appStoreSourceProjection() {
    let application = applicationOutput()
    let provenance = CollectorOutput(
      run: CollectorRun(
        collectorID: ApplicationProvenanceCollector.id,
        collectorVersion: ApplicationProvenanceCollector.version,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: [
        CollectedObservation(
          id: "provenance",
          scanID: "scan",
          collectorID: ApplicationProvenanceCollector.id,
          schemaVersion: ApplicationProvenanceCollector.version,
          observedAt: timestamp,
          subject: application.observations[0].subject,
          value: ApplicationProvenanceValue(
            applicationPath: "/Applications/Example.app",
            facts: [
              ApplicationProvenanceFact(
                kind: .appStoreReceipt,
                displayLabel: "App Store receipt",
                status: .present,
                source: "Test"
              )
            ]
          )
        )
      ]
    )

    let graph = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: application,
      provenance: provenance
    ).graph

    #expect(graph.entity("package-manager:app-store")?.name == "App Store")
    #expect(
      graph.relationships.contains {
        $0.source == "package-manager:app-store"
          && $0.target == "application:bundleIdentifier:com.example.application"
          && $0.type == .owns
      }
    )
  }

  private func applicationOutput() -> CollectorOutput<ApplicationBundleValue> {
    let value = ApplicationBundleValue(
      path: "/Applications/Example.app",
      name: "Example",
      bundleIdentifier: "com.example.application"
    )
    return CollectorOutput(
      run: CollectorRun(
        collectorID: ApplicationBundleCollector.id,
        collectorVersion: 1,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: [
        CollectedObservation(
          id: "application",
          scanID: "scan",
          collectorID: ApplicationBundleCollector.id,
          schemaVersion: 1,
          observedAt: timestamp,
          subject: SubjectIdentity(
            primary: IdentityClaim(kind: .bundleIdentifier, value: "com.example.application")
          ),
          value: value
        )
      ]
    )
  }
}

private struct StubProvenanceInspector: ApplicationProvenanceInspecting {
  func inspectApplication(
    at url: URL,
    adapters: [ApplicationProvenanceAdapterConfiguration]
  ) -> [ApplicationProvenanceFact] {
    [
      ApplicationProvenanceFact(
        kind: .appStoreReceipt,
        displayLabel: "Receipt",
        status: .present,
        source: "Test"
      ),
      ApplicationProvenanceFact(
        kind: .downloadOrigin,
        displayLabel: "Origin",
        status: .unreadable,
        source: "Test"
      ),
    ]
  }
}
