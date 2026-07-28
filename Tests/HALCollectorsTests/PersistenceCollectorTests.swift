import Foundation
import HALCollectors
import HALDomain
import Testing

@Suite("Persistence declaration collector")
struct PersistenceCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Collector retains only actionable declaration fields")
  func collection() throws {
    let root = try temporaryDirectory()
    let plist = root.appending(path: "com.example.helper.plist")
    try writePlist(
      [
        "Label": "com.example.helper",
        "ProgramArguments": [
          "/Applications/Example.app/Contents/Helpers/Helper",
          "--secret-argument",
        ],
        "RunAtLoad": true,
        "KeepAlive": ["SuccessfulExit": false],
      ],
      to: plist
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let output = PersistenceCollector(
      roots: [
        PersistenceSearchRoot(id: "test", url: root, kind: .launchAgent)
      ],
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    let value = try #require(output.observations.first?.value)
    #expect(value.label == "com.example.helper")
    #expect(value.programPath == "/Applications/Example.app/Contents/Helpers/Helper")
    #expect(value.runAtLoad)
    #expect(value.keepAlive)
    let encoded = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    #expect(!encoded.contains("secret-argument"))
  }

  @Test("Malformed declarations are partial outcomes")
  func malformed() throws {
    let root = try temporaryDirectory()
    try writePlist(["Program": "/bin/example"], to: root.appending(path: "invalid.plist"))
    defer { try? FileManager.default.removeItem(at: root) }

    let output = PersistenceCollector(
      roots: [PersistenceSearchRoot(id: "test", url: root, kind: .launchAgent)],
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(output.run.state == .partial)
    #expect(output.observations.isEmpty)
    #expect(output.run.issues.count == 1)
  }

  @Test("Resolver preserves matched and unmatched declarations")
  func resolution() throws {
    let root = try temporaryDirectory()
    try writePlist(
      [
        "Label": "com.example.helper",
        "Program": "/Applications/Example.app/Contents/Helpers/Helper",
      ],
      to: root.appending(path: "matched.plist")
    )
    try writePlist(
      [
        "Label": "com.other.helper",
        "Program": "/Library/PrivilegedHelperTools/com.other.helper",
      ],
      to: root.appending(path: "unmatched.plist")
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let declarations = PersistenceCollector(
      roots: [PersistenceSearchRoot(id: "test", url: root, kind: .launchAgent)],
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")
    let resolutions = PersistenceApplicationResolver(
      clock: FixedClock(timestamp)
    ).resolve(
      scanID: "scan",
      declarations: declarations,
      applications: [application()]
    )

    #expect(resolutions.observations.map(\.value.state) == [.matched, .unmatched])
    #expect(resolutions.observations.first?.value.confidence == .high)
  }

  private func application() -> CollectedObservation<ApplicationBundleValue> {
    CollectedObservation(
      id: "application",
      scanID: "scan",
      collectorID: ApplicationBundleCollector.id,
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .bundleIdentifier, value: "com.example.application")
      ),
      value: ApplicationBundleValue(
        path: "/Applications/Example.app",
        name: "Example",
        bundleIdentifier: "com.example.application"
      )
    )
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func writePlist(_ value: [String: Any], to url: URL) throws {
    let data = try PropertyListSerialization.data(
      fromPropertyList: value,
      format: .xml,
      options: 0
    )
    try data.write(to: url)
  }
}
