import Foundation
import HALCollectors
import HALDomain
import Testing

@Suite("Runtime and package ecosystem collectors")
struct SoftwareInventoryCollectorTests {
  @Test("Runtime definitions and package ecosystems are schema validated")
  func bundledConfigurations() throws {
    let runtimes = try RuntimeCollectorConfiguration.bundled()
    let ecosystems = try PackageEcosystemConfiguration.bundled()
    #expect(runtimes.runtimes.map(\.id) == ["node", "python", "java", "go", "php", "javac"])
    #expect(ecosystems.ecosystems.map(\.id) == ["npm", "pypi"])
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
