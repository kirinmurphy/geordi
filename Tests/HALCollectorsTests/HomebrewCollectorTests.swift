import Foundation
import HALCollectors
import HALDomain
import Testing

@Suite("Homebrew package collector")
struct HomebrewCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Bundled installation roots are manifest-driven and schema validated")
  func bundledConfiguration() throws {
    let configuration = try HomebrewInstallationConfiguration.bundled()
    #expect(configuration.schemaVersion == 1)
    #expect(configuration.installations.map(\.prefix) == ["/opt/homebrew", "/usr/local"])
  }

  @Test("Collector derives formula names and versions from Cellar directories")
  func collectsFormulae() throws {
    let root = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let cellar = root.appending(path: "Cellar", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
      at: cellar.appending(path: "wget/1.2.3", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: cellar.appending(path: "node/22.1.0", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let output = HomebrewCollector(
      configuration: HomebrewInstallationConfiguration(
        installations: [
          HomebrewInstallation(
            id: "test",
            prefix: root.path,
            cellarRelativePath: "Cellar"
          )
        ]
      ),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(output.run.state == .complete)
    #expect(
      output.observations.first?.value.packages == [
        HomebrewPackageValue(name: "node", versions: ["22.1.0"]),
        HomebrewPackageValue(name: "wget", versions: ["1.2.3"]),
      ])
  }

  @Test("Projection creates package-manager ownership relationships")
  func projection() throws {
    let inventory = CollectedObservation(
      id: ObservationID("homebrew"),
      scanID: ScanID("scan"),
      collectorID: HomebrewCollector.id,
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .canonicalPath, value: "/opt/homebrew")
      ),
      value: HomebrewInventoryValue(
        prefix: "/opt/homebrew",
        cellarPath: "/opt/homebrew/Cellar",
        packages: [HomebrewPackageValue(name: "wget", versions: ["1.2.3"])]
      )
    )
    let run = CollectorRun(
      collectorID: HomebrewCollector.id,
      collectorVersion: 1,
      availability: .available,
      state: .complete,
      startedAt: timestamp,
      completedAt: timestamp
    )
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
      homebrew: CollectorOutput(run: run, observations: [inventory])
    )

    try snapshot.graph.validate()
    #expect(snapshot.graph.entities.contains { $0.type == .packageManager })
    #expect(snapshot.graph.entities.contains { $0.type == .package && $0.name == "wget" })
    #expect(snapshot.graph.relationships.first?.type == .owns)
    #expect(snapshot.graph.relationships.first?.confidence == .confirmed)
  }
}
