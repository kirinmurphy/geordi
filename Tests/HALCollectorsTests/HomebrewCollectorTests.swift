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
    #expect(configuration.schemaVersion == 2)
    #expect(configuration.installations.map(\.prefix) == ["/opt/homebrew", "/usr/local"])
    #expect(configuration.installations.allSatisfy { $0.caskroomRelativePath == "Caskroom" })
  }

  @Test("Manifest rejects unknown keys and unsafe Caskroom paths")
  func rejectsInvalidManifest() throws {
    let schema = try HomebrewInstallationConfiguration.declarativeSchemaData()
    let unknownKey = Data(
      """
      {"schemaVersion":2,"installations":[{"id":"test","prefix":"/opt/test","cellarRelativePath":"Cellar","caskroomRelativePath":"Caskroom","extra":true}]}
      """.utf8
    )
    #expect(throws: HomebrewCollectorError.self) {
      try HomebrewInstallationConfiguration.decode(unknownKey, schema: schema)
    }

    let unsafePath = Data(
      """
      {"schemaVersion":2,"installations":[{"id":"test","prefix":"/opt/test","cellarRelativePath":"Cellar","caskroomRelativePath":"../Caskroom"}]}
      """.utf8
    )
    #expect(throws: HomebrewCollectorError.invalidPath) {
      try HomebrewInstallationConfiguration.decode(unsafePath, schema: schema)
    }
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

  @Test("Collector derives cask artifacts and bundle identity from bounded local metadata")
  func collectsCasks() throws {
    let root = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let cask = root.appending(path: "Caskroom/warp", directoryHint: .isDirectory)
    let application = cask.appending(
      path: "1.0/Warp.app/Contents",
      directoryHint: .isDirectory
    )
    let metadata = cask.appending(path: ".metadata", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: metadata, withIntermediateDirectories: true)
    try PropertyListSerialization.data(
      fromPropertyList: [
        "CFBundleIdentifier": "dev.warp.Warp-Stable",
        "CFBundleName": "Warp",
      ],
      format: .xml,
      options: 0
    ).write(to: application.appending(path: "Info.plist"))
    try Data(
      """
      {"uninstall_artifacts":[{"app":["Warp.app"]},{"zap":[{"trash":["~/.warp"]}]}]}
      """.utf8
    ).write(to: metadata.appending(path: "INSTALL_RECEIPT.json"))
    defer { try? FileManager.default.removeItem(at: root) }

    let output = HomebrewCollector(
      configuration: HomebrewInstallationConfiguration(
        installations: [
          HomebrewInstallation(
            id: "test",
            prefix: root.path,
            cellarRelativePath: "Cellar",
            caskroomRelativePath: "Caskroom"
          )
        ]
      ),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(
      output.observations.first?.value.casks == [
        HomebrewCaskValue(
          token: "warp",
          versions: ["1.0"],
          artifacts: [
            HomebrewCaskArtifactValue(
              applicationName: "Warp.app",
              bundleIdentifier: "dev.warp.Warp-Stable"
            )
          ]
        )
      ]
    )
  }

  @Test("Projection keeps cask ownership separate from download origin")
  func projectsCaskApplicationOwnership() throws {
    let application = CollectedObservation(
      id: ObservationID("application:warp"),
      scanID: ScanID("scan"),
      collectorID: ApplicationBundleCollector.id,
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .bundleIdentifier, value: "dev.warp.Warp-Stable")
      ),
      value: ApplicationBundleValue(
        path: "/Applications/Warp.app",
        name: "Warp",
        bundleIdentifier: "dev.warp.Warp-Stable"
      )
    )
    let applications = CollectorOutput(
      run: CollectorRun(
        collectorID: ApplicationBundleCollector.id,
        collectorVersion: 1,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: [application]
    )
    let homebrewObservation = CollectedObservation(
      id: ObservationID("homebrew"),
      scanID: ScanID("scan"),
      collectorID: HomebrewCollector.id,
      schemaVersion: 2,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .canonicalPath, value: "/opt/homebrew")
      ),
      value: HomebrewInventoryValue(
        prefix: "/opt/homebrew",
        cellarPath: "/opt/homebrew/Cellar",
        caskroomPath: "/opt/homebrew/Caskroom",
        packages: [],
        casks: [
          HomebrewCaskValue(
            token: "warp",
            versions: ["1.0"],
            artifacts: [
              HomebrewCaskArtifactValue(
                applicationName: "Warp.app",
                bundleIdentifier: "dev.warp.Warp-Stable"
              )
            ]
          )
        ]
      )
    )
    let homebrew = CollectorOutput(
      run: CollectorRun(
        collectorID: HomebrewCollector.id,
        collectorVersion: 2,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: [homebrewObservation]
    )

    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: applications,
      homebrew: homebrew
    )

    try snapshot.graph.validate()
    let projectedApplication = try #require(
      snapshot.graph.entities.first { $0.type == .application }
    )
    #expect(
      projectedApplication.details.contains {
        $0.label == "Installed with" && $0.value == "Homebrew cask warp"
      }
    )
    #expect(!projectedApplication.details.contains { $0.label == "Download origin" })
    #expect(!projectedApplication.details.contains { $0.label == "Homebrew cask" })
    #expect(
      snapshot.graph.relationships.contains {
        $0.source.rawValue.contains("cask:homebrew")
          && $0.target == projectedApplication.id
          && $0.type == .owns
      }
    )
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
