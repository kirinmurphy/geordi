import Foundation
import GeordiCollectors
import GeordiDomain
import Testing

@Suite("Shell-framework collector")
struct ShellFrameworkCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Bundled framework definitions are versioned and schema validated")
  func bundledConfiguration() throws {
    let configuration = try ShellFrameworkConfiguration.bundled()
    #expect(configuration.schemaVersion == 2)
    #expect(configuration.frameworks.map(\.id) == ["oh-my-zsh"])
  }

  @Test("Manifest rejects unknown keys and unsafe paths")
  func rejectsInvalidManifest() throws {
    let schema = try ShellFrameworkConfiguration.declarativeSchemaData()
    let unknown = Data(
      """
      {"schemaVersion":2,"frameworks":[{"id":"x","label":"X","rootPath":"$USER_HOME/.x","configurationPath":"$USER_HOME/.zshrc","requiredRelativePaths":["x"],"configurationReferenceTokens":["x"],"repositoryHosts":["example.com"],"repositoryPathSuffixes":["x/x"],"associatedShellExecutablePaths":["/bin/zsh"],"maximumAssociatedProcesses":8,"extra":true}]}
      """.utf8
    )
    #expect(throws: ShellFrameworkCollectorError.self) {
      try ShellFrameworkConfiguration.decode(unknown, schema: schema)
    }
    let unsafe = Data(
      """
      {"schemaVersion":2,"frameworks":[{"id":"x","label":"X","rootPath":"$USER_HOME/../x","configurationPath":"$USER_HOME/.zshrc","requiredRelativePaths":["x"],"configurationReferenceTokens":["x"],"repositoryHosts":["example.com"],"repositoryPathSuffixes":["x/x"],"associatedShellExecutablePaths":["/bin/zsh"],"maximumAssociatedProcesses":8}]}
      """.utf8
    )
    #expect(throws: ShellFrameworkCollectorError.self) {
      try ShellFrameworkConfiguration.decode(unsafe, schema: schema)
    }
  }

  @Test(
    "Collector observes bounded Git identity and active configuration without retaining contents")
  func observesFramework() throws {
    let home = try temporaryHome()
    defer { try? FileManager.default.removeItem(at: home) }
    try installFramework(in: home)
    try Data("source $ZSH/oh-my-zsh.sh\nSECRET=value".utf8)
      .write(to: home.appending(path: ".zshrc"))

    let output = collector(home: home).collect(scanID: "scan")
    let value = try #require(output.observations.first?.value)
    #expect(value.installationStatus == .observed)
    #expect(value.configurationStatus == .active)
    #expect(value.repositoryHost == "github.com")
    #expect(!String(describing: value).contains("SECRET"))
  }

  @Test("Collector preserves absent, inactive, unreadable, and ambiguous states")
  func negativeStates() throws {
    let absentHome = try temporaryHome()
    defer { try? FileManager.default.removeItem(at: absentHome) }
    var value = try #require(
      collector(home: absentHome).collect(scanID: "absent").observations.first
    )
    .value
    #expect(value.installationStatus == .absent)
    #expect(value.configurationStatus == .absent)

    try installFramework(in: absentHome)
    try Data("# no framework source\n".utf8).write(to: absentHome.appending(path: ".zshrc"))
    value = try #require(
      collector(home: absentHome).collect(scanID: "inactive").observations.first
    ).value
    #expect(value.configurationStatus == .inactive)

    try Data(repeating: 0x61, count: 262_145).write(to: absentHome.appending(path: ".zshrc"))
    value = try #require(
      collector(home: absentHome).collect(scanID: "unreadable").observations.first
    ).value
    #expect(value.configurationStatus == .unreadable)

    try FileManager.default.removeItem(at: absentHome.appending(path: ".oh-my-zsh/themes"))
    value = try #require(
      collector(home: absentHome).collect(scanID: "ambiguous").observations.first
    ).value
    #expect(value.installationStatus == .ambiguous)
  }

  @Test("Collector refuses a framework root symlinked outside the configured home")
  func refusesUnsafeSymlink() throws {
    let home = try temporaryHome()
    let outside = try temporaryHome()
    defer {
      try? FileManager.default.removeItem(at: home)
      try? FileManager.default.removeItem(at: outside)
    }
    try installFramework(in: outside)
    try FileManager.default.createSymbolicLink(
      at: home.appending(path: ".oh-my-zsh"),
      withDestinationURL: outside.appending(path: ".oh-my-zsh")
    )

    let output = collector(home: home).collect(scanID: "unsafe")
    #expect(output.run.state == .partial)
    #expect(output.observations.first?.value.installationStatus == .ambiguous)
  }

  @Test("Projection explains Git bootstrap evidence without claiming witnessed curl")
  func projection() throws {
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
    let framework = CollectedObservation(
      id: ObservationID("shell-framework:oh-my-zsh"),
      scanID: ScanID("scan"),
      collectorID: ShellFrameworkCollector.id,
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .canonicalPath, value: "/Users/test/.oh-my-zsh")
      ),
      value: ShellFrameworkValue(
        frameworkID: "oh-my-zsh",
        label: "Oh My Zsh",
        rootPath: "/Users/test/.oh-my-zsh",
        installationStatus: .observed,
        configurationPath: "/Users/test/.zshrc",
        configurationStatus: .active,
        repositoryHost: "github.com"
      )
    )
    let output = CollectorOutput(
      run: CollectorRun(
        collectorID: ShellFrameworkCollector.id,
        collectorVersion: 1,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: [framework]
    )
    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: applications,
      shellFrameworks: output
    )

    let entity = try #require(snapshot.graph.entities.first)
    #expect(entity.type == .shellFramework)
    #expect(entity.name == "Oh My Zsh")
    #expect(entity.details.contains { $0.value.contains("did not witness") })
    #expect(!entity.details.contains { $0.value.contains("curl") })
  }

  @Test("Projection bounds possible active-shell relationships without claiming proof")
  func activeShellProjection() throws {
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
    let framework = CollectedObservation(
      id: ObservationID("shell-framework:oh-my-zsh"),
      scanID: ScanID("scan"),
      collectorID: ShellFrameworkCollector.id,
      schemaVersion: 2,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .canonicalPath, value: "/Users/test/.oh-my-zsh")
      ),
      value: ShellFrameworkValue(
        frameworkID: "oh-my-zsh",
        label: "Oh My Zsh",
        rootPath: "/Users/test/.oh-my-zsh",
        installationStatus: .observed,
        configurationPath: "/Users/test/.zshrc",
        configurationStatus: .active,
        associatedShellExecutablePaths: ["/bin/zsh"],
        maximumAssociatedProcesses: 1
      )
    )
    let frameworkOutput = CollectorOutput(
      run: CollectorRun(
        collectorID: ShellFrameworkCollector.id,
        collectorVersion: 2,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: [framework]
    )
    let processOutput = CollectorOutput(
      run: CollectorRun(
        collectorID: ProcessCollector.id,
        collectorVersion: 1,
        availability: .available,
        state: .complete,
        startedAt: timestamp,
        completedAt: timestamp
      ),
      observations: [
        process(pid: 10, executable: "/bin/zsh"),
        process(pid: 11, executable: "/bin/zsh"),
        process(pid: 12, executable: "/bin/bash"),
      ]
    )

    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: applications,
      processes: processOutput,
      shellFrameworks: frameworkOutput
    )

    let relationship = try #require(
      snapshot.graph.relationships.first { $0.id.rawValue.contains("shell-framework-process") }
    )
    #expect(
      snapshot.graph.entities.filter { $0.id.rawValue.hasPrefix("shell-process:") }.count == 1
    )
    #expect(relationship.confidence == .possible)
    #expect(relationship.explanation.contains("did not inspect"))
    #expect(!relationship.explanation.contains("loaded"))
  }

  private func collector(home: URL) -> ShellFrameworkCollector {
    ShellFrameworkCollector(
      configuration: ShellFrameworkConfiguration(frameworks: [definition]),
      userHome: home,
      clock: FixedClock(timestamp)
    )
  }

  private var definition: ShellFrameworkDefinition {
    ShellFrameworkDefinition(
      id: "oh-my-zsh",
      label: "Oh My Zsh",
      rootPath: "$USER_HOME/.oh-my-zsh",
      configurationPath: "$USER_HOME/.zshrc",
      requiredRelativePaths: ["oh-my-zsh.sh", "plugins", "themes", ".git/config"],
      configurationReferenceTokens: ["$ZSH/oh-my-zsh.sh"],
      repositoryHosts: ["github.com"],
      repositoryPathSuffixes: ["ohmyzsh/ohmyzsh"],
      associatedShellExecutablePaths: ["/bin/zsh"],
      maximumAssociatedProcesses: 8
    )
  }

  private func process(pid: Int32, executable: String) -> CollectedObservation<ProcessValue> {
    CollectedObservation(
      id: ObservationID("process:\(pid)"),
      scanID: ScanID("scan"),
      collectorID: ProcessCollector.id,
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .processInstance, value: "\(pid)")
      ),
      value: ProcessValue(
        pid: pid,
        parentPID: 1,
        name: URL(fileURLWithPath: executable).lastPathComponent,
        executablePath: executable,
        accessibility: .accessible
      )
    )
  }

  private func temporaryHome() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func installFramework(in home: URL) throws {
    let root = home.appending(path: ".oh-my-zsh")
    for path in ["plugins", "themes", ".git"] {
      try FileManager.default.createDirectory(
        at: root.appending(path: path),
        withIntermediateDirectories: true
      )
    }
    try Data("# framework\n".utf8).write(to: root.appending(path: "oh-my-zsh.sh"))
    try Data(
      """
      [remote "origin"]
        url = https://user:secret@github.com/ohmyzsh/ohmyzsh.git
      """.utf8
    ).write(to: root.appending(path: ".git/config"))
  }
}
