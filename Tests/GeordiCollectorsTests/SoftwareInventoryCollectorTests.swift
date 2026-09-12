import Foundation
import GeordiCollectors
import GeordiDomain
import Testing

@Suite("Runtime and package ecosystem collectors")
struct SoftwareInventoryCollectorTests {
  @Test("Collection composition is schema validated and contains required adapters")
  func collectionCompositionProfile() throws {
    let profile = try CollectionProfile.bundled()
    #expect(profile.schemaVersion == CollectionProfile.currentVersion)
    #expect(profile.maxConcurrentTasks == 4)
    #expect(profile.collectors.contains { $0.id == "applications" && $0.enabled })
    #expect(profile.collectors.contains { $0.id == "processes" && $0.enabled })
    #expect(Set(profile.collectors.map(\.id)).count == profile.collectors.count)
  }

  @Test("Runtime definitions and package ecosystems are schema validated")
  func bundledConfigurations() throws {
    let runtimes = try RuntimeCollectorConfiguration.bundled()
    let ecosystems = try PackageEcosystemConfiguration.bundled()
    #expect(runtimes.runtimes.map(\.id) == ["node", "python", "java", "go", "php", "javac"])
    #expect(ecosystems.ecosystems.map(\.id) == ["npm", "pypi"])
  }

  @Test("Executable stubs that fail version queries are not installed runtimes")
  func failedVersionQueryIsUnavailable() throws {
    let home = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let executable = home.appending(path: ".local/bin/java")
    try FileManager.default.createDirectory(
      at: executable.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("#!/bin/sh\nexit 1\n".utf8).write(to: executable)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: executable.path
    )
    defer { try? FileManager.default.removeItem(at: home) }
    let configuration = RuntimeCollectorConfiguration(
      runtimes: [
        RuntimeDefinition(
          id: "java",
          label: "Java",
          kind: .runtime,
          executableCandidates: [
            RuntimeExecutableCandidate(path: "$USER_HOME/.local/bin/java", scope: .user)
          ],
          versionArguments: ["-version"]
        )
      ]
    )

    let output = RuntimeCollector(
      configuration: configuration,
      userHome: home
    ).collect(scanID: "scan")

    #expect(output.observations.isEmpty)
  }

  @Test("npm packages are derived from package metadata")
  func npmPackages() throws {
    let home = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let package = home.appending(path: ".local/lib/node_modules/example")
    try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
    try Data(#"{"name":"example","version":"1.2.3"}"#.utf8)
      .write(to: package.appending(path: "package.json"))
    defer { try? FileManager.default.removeItem(at: home) }

    let output = PackageEcosystemCollector(
      configuration: PackageEcosystemConfiguration(
        ecosystems: [
          PackageEcosystemDefinition(
            id: "npm",
            label: "npm",
            layout: .nodeModules,
            roots: ["$USER_HOME/.local/lib/node_modules"]
          )
        ]
      ),
      userHome: home
    ).collect(scanID: "scan")

    #expect(output.observations.first?.value.packages.first?.name == "example")
    #expect(output.observations.first?.value.packages.first?.version == "1.2.3")
  }
}
