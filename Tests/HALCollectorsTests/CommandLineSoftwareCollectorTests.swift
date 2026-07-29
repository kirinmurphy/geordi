import Foundation
import HALCollectors
import Testing

@Suite("Command-line software collector")
struct CommandLineSoftwareCollectorTests {
  @Test("Bundled roots are schema validated and include open-ended command sources")
  func bundledConfiguration() throws {
    let configuration = try CommandLineSoftwareConfiguration.bundled()
    #expect(configuration.roots.contains { $0.path == "/usr/bin" })
    #expect(configuration.roots.contains { $0.packageManagerID == "homebrew" })
  }

  @Test("Collector retains unknown executable tools without executing them")
  func unknownExecutable() throws {
    let home = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let bin = home.appending(path: ".local/bin", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
    let executable = bin.appending(path: "future-runtime")
    try Data().write(to: executable)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: executable.path
    )
    defer { try? FileManager.default.removeItem(at: home) }

    let output = CommandLineSoftwareCollector(
      configuration: CommandLineSoftwareConfiguration(
        roots: [
          CommandLineSoftwareRoot(
            id: "test",
            label: "Test commands",
            path: "$USER_HOME/.local/bin",
            scope: .user,
            maxEntries: 10
          )
        ]
      ),
      userHome: home
    ).collect(scanID: "scan")

    #expect(output.observations.count == 1)
    #expect(output.observations.first?.value.name == "future-runtime")
    #expect(output.observations.first?.value.sourceLabel == "Test commands")
  }
}
