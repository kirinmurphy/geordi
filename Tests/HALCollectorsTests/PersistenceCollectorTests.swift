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
    #expect(value.scope == .user)
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
    #expect(output.run.issues.first?.severity == .warning)
    #expect(
      output.run.issues.first?.summary
        == "A persistence property list did not declare a launchd label."
    )
  }

  @Test("Empty property lists are logged as placeholders without limiting collection")
  func emptyPlaceholder() throws {
    let root = try temporaryDirectory()
    try writePlist([:], to: root.appending(path: "placeholder.plist"))
    defer { try? FileManager.default.removeItem(at: root) }

    let output = PersistenceCollector(
      roots: [PersistenceSearchRoot(id: "test", url: root, kind: .launchAgent)],
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(output.run.state == .complete)
    #expect(output.observations.isEmpty)
    #expect(output.run.issues.count == 1)
    #expect(output.run.issues.first?.severity == .information)
    #expect(
      output.run.issues.first?.summary
        == "\(AppBrand.displayName) ignored an empty persistence placeholder."
    )
  }

  @Test("Undecodable property lists remain partial outcomes")
  func undecodable() throws {
    let root = try temporaryDirectory()
    try Data("not a property list".utf8).write(to: root.appending(path: "broken.plist"))
    defer { try? FileManager.default.removeItem(at: root) }

    let output = PersistenceCollector(
      roots: [PersistenceSearchRoot(id: "test", url: root, kind: .launchAgent)],
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(output.run.state == .partial)
    #expect(output.run.issues.first?.severity == .warning)
    #expect(
      output.run.issues.first?.summary
        == "\(AppBrand.displayName) could not decode a persistence property list."
    )
  }

  @Test("Resolver does not duplicate upstream declaration issues")
  func resolverDoesNotDuplicateIssues() throws {
    let root = try temporaryDirectory()
    try writePlist(["Program": "/bin/example"], to: root.appending(path: "invalid.plist"))
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

    #expect(declarations.run.state == .partial)
    #expect(resolutions.run.state == .complete)
    #expect(resolutions.run.issues.isEmpty)
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

  @Test("Projection preserves matched and unresolved declarations with evidence")
  func projection() throws {
    let root = try temporaryDirectory()
    try writePlist(
      [
        "Label": "com.unresolved.helper",
        "Program": "/Library/PrivilegedHelperTools/com.unresolved.helper",
      ],
      to: root.appending(path: "unresolved.plist")
    )
    try writePlist(
      [
        "Label": "com.example.helper",
        "Program": "/Applications/Example.app/Contents/Helpers/Helper",
        "RunAtLoad": true,
      ],
      to: root.appending(path: "matched.plist")
    )
    defer { try? FileManager.default.removeItem(at: root) }
    let declarations = PersistenceCollector(
      roots: [PersistenceSearchRoot(id: "test", url: root, kind: .launchAgent)],
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")
    let application = application()
    let resolutions = PersistenceApplicationResolver(
      clock: FixedClock(timestamp)
    ).resolve(
      scanID: "scan",
      declarations: declarations,
      applications: [application]
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

    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: applications,
      persistence: declarations,
      persistenceResolutions: resolutions
    )

    try snapshot.graph.validate()
    let persistence = snapshot.graph.entities.filter { $0.type == .persistence }
    #expect(persistence.count == 2)
    #expect(
      persistence.first { $0.name == "com.unresolved.helper" }?
        .details.first { $0.label == "Ownership" }?.value == "Unresolved"
    )
    #expect(snapshot.graph.relationships.first?.type == .persistsThrough)
    #expect(snapshot.graph.relationships.first?.evidence.count == 2)
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
