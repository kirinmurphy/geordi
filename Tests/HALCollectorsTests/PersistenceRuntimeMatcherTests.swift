import Foundation
import HALCollectors
import HALDomain
import Testing

@Suite("Persistence runtime matcher")
struct PersistenceRuntimeMatcherTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Bundled manifest is schema validated")
  func bundledManifest() throws {
    let configuration = try PersistenceRuntimeMatchingConfiguration.bundled()
    #expect(configuration.schemaVersion == 1)
    #expect(configuration.strategies.map(\.id) == ["exact-declared-executable"])
  }

  @Test("Manifest rejects unknown keys, enums, and unsupported versions")
  func invalidManifests() throws {
    let schema = try resource("persistence-runtime-matching.schema")
    let valid = try resource("persistence-runtime-matching")
    let unknown = String(decoding: valid, as: UTF8.self)
      .replacingOccurrences(
        of: "\"schemaVersion\": 1,", with: "\"schemaVersion\": 1, \"extra\": true,")
    #expect(throws: PersistenceRuntimeMatchingError.self) {
      try PersistenceRuntimeMatchingConfiguration.decode(Data(unknown.utf8), schema: schema)
    }
    let invalidEnum = String(decoding: valid, as: UTF8.self)
      .replacingOccurrences(of: "\"comparison\": \"exact\"", with: "\"comparison\": \"similar\"")
    #expect(throws: PersistenceRuntimeMatchingError.self) {
      try PersistenceRuntimeMatchingConfiguration.decode(Data(invalidEnum.utf8), schema: schema)
    }
    let unsupported = String(decoding: valid, as: UTF8.self)
      .replacingOccurrences(of: "\"schemaVersion\": 1", with: "\"schemaVersion\": 2")
    #expect(throws: PersistenceRuntimeMatchingError.unsupportedVersion(2)) {
      try PersistenceRuntimeMatchingConfiguration.decode(Data(unsupported.utf8), schema: schema)
    }
  }

  @Test("Only exact retained executable identity matches, with stable instance ordering")
  func exactOnly() throws {
    let matcher = try makeMatcher()
    let processes = processOutput([
      process(pid: 20, name: "Helper", path: "/opt/example/Helper"),
      process(pid: 10, name: "Anything", path: "/opt/example/Helper"),
      process(pid: 30, name: "Helper", path: "/opt/example/Helper-copy"),
      process(pid: 40, name: "Helper", path: "/other/Helper"),
    ])
    let output = matcher.match(
      scanID: "scan",
      declarations: declarationOutput([
        declaration(path: "/Library/LaunchDaemons/exact.plist", program: "/opt/example/Helper"),
        declaration(path: "/Library/LaunchDaemons/near.plist", program: "/opt/example/Help"),
      ]),
      processes: processes
    )
    #expect(output.observations[0].value.processIDs == [10, 20])
    #expect(output.observations[0].value.state == .matched)
    #expect(output.observations[1].value.state == .unmatched)
    #expect(output.observations[1].value.processIDs.isEmpty)
  }

  @Test("Missing identity is ambiguous and process evidence states remain explicit")
  func evidenceStates() throws {
    let matcher = try makeMatcher()
    let declaration = declarationOutput([
      declaration(path: "/Library/LaunchDaemons/example.plist", program: nil)
    ])
    #expect(
      matcher.match(scanID: "scan", declarations: declaration, processes: processOutput([]))
        .observations.first?.value.state == .ambiguous
    )
    for (availability, runState, expected) in [
      (CollectorAvailability.available, CollectorRunState.partial, .partial),
      (.unavailable, .failed, .unavailable),
      (.permissionDenied, .failed, .permissionDenied),
    ] as [(CollectorAvailability, CollectorRunState, PersistenceRuntimeCorrelationState)] {
      let processes = processOutput([], availability: availability, state: runState)
      #expect(
        matcher.match(scanID: "scan", declarations: declaration, processes: processes)
          .observations.first?.value.state == expected
      )
    }
  }

  @Test("Shuffled equivalent inputs produce identical correlation values")
  func deterministic() throws {
    let matcher = try makeMatcher()
    let declarations = [
      declaration(path: "/Library/LaunchDaemons/b.plist", program: "/bin/b"),
      declaration(path: "/Library/LaunchDaemons/a.plist", program: "/bin/a"),
    ]
    let processes = [
      process(pid: 2, name: "b", path: "/bin/b"),
      process(pid: 1, name: "a", path: "/bin/a"),
    ]
    let first = matcher.match(
      scanID: "scan",
      declarations: declarationOutput(declarations),
      processes: processOutput(processes)
    )
    let second = matcher.match(
      scanID: "scan",
      declarations: declarationOutput(declarations.reversed()),
      processes: processOutput(processes.reversed())
    )
    #expect(first.observations.map(\.value) == second.observations.map(\.value))
  }

  @Test("Projection preserves declaration and process IDs, timestamp, and evidence")
  func projection() throws {
    let declarations = declarationOutput([
      declaration(
        path: "/Library/LaunchDaemons/example.plist",
        program: "/opt/example/Helper"
      )
    ])
    let processes = processOutput([
      process(pid: 10, name: "Helper", path: "/opt/example/Helper")
    ])
    let correlations = try makeMatcher().match(
      scanID: "scan",
      declarations: declarations,
      processes: processes
    )
    let processResolutions = CollectorOutput(
      run: run(id: "process-resolution"),
      observations: [
        CollectedObservation(
          id: "process-resolution:10",
          scanID: "scan",
          collectorID: "process-resolution",
          schemaVersion: 1,
          observedAt: timestamp,
          subject: SubjectIdentity(
            primary: IdentityClaim(kind: .processInstance, value: "10")
          ),
          value: ProcessApplicationResolutionValue(processID: 10, state: .unmatched)
        )
      ]
    )
    let applications = CollectorOutput<ApplicationBundleValue>(
      run: run(id: "applications"),
      observations: []
    )
    let graph = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: applications,
      processes: processes,
      processResolutions: processResolutions,
      persistence: declarations,
      persistenceRuntimeCorrelations: correlations
    ).graph

    let relationship = try #require(
      graph.relationships.first { $0.type == .observedRunning }
    )
    #expect(
      relationship.source
        == "persistence:declaration:/Library/LaunchDaemons/example.plist"
    )
    #expect(graph.entity(relationship.target)?.type == .process)
    #expect(relationship.evidence.map(\.observedAt) == [timestamp, timestamp])
    #expect(
      graph.entity(relationship.source)?.details.first {
        $0.label == "Running state"
      }?.value == "Observed running in this snapshot"
    )
  }

  private func makeMatcher() throws -> PersistenceRuntimeMatcher {
    PersistenceRuntimeMatcher(
      configuration: try .bundled(),
      clock: FixedClock(timestamp)
    )
  }

  private func declaration(path: String, program: String?) -> CollectedObservation<
    PersistenceDeclarationValue
  > {
    CollectedObservation(
      id: ObservationID("declaration:\(path)"),
      scanID: "scan",
      collectorID: "persistence",
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(primary: IdentityClaim(kind: .canonicalPath, value: path)),
      sourceReference: path,
      value: PersistenceDeclarationValue(
        declarationPath: path,
        kind: .launchDaemon,
        scope: .system,
        label: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent,
        programPath: program,
        runAtLoad: false,
        keepAlive: false
      )
    )
  }

  private func process(pid: Int32, name: String, path: String) -> CollectedObservation<ProcessValue>
  {
    CollectedObservation(
      id: ObservationID("process:\(pid)"),
      scanID: "scan",
      collectorID: "process",
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(primary: IdentityClaim(kind: .processInstance, value: "\(pid)")),
      sourceReference: "read-only process snapshot",
      value: ProcessValue(pid: pid, name: name, executablePath: path, accessibility: .accessible)
    )
  }

  private func declarationOutput<S: Sequence>(
    _ values: S
  ) -> CollectorOutput<PersistenceDeclarationValue>
  where S.Element == CollectedObservation<PersistenceDeclarationValue> {
    CollectorOutput(run: run(id: "persistence"), observations: Array(values))
  }

  private func processOutput<S: Sequence>(
    _ values: S,
    availability: CollectorAvailability = .available,
    state: CollectorRunState = .complete
  ) -> CollectorOutput<ProcessValue>
  where S.Element == CollectedObservation<ProcessValue> {
    CollectorOutput(
      run: run(id: "process", availability: availability, state: state),
      observations: Array(values)
    )
  }

  private func run(
    id: CollectorID,
    availability: CollectorAvailability = .available,
    state: CollectorRunState = .complete
  ) -> CollectorRun {
    CollectorRun(
      collectorID: id,
      collectorVersion: 1,
      availability: availability,
      state: state,
      startedAt: timestamp,
      completedAt: timestamp
    )
  }

  private func resource(_ name: String) throws -> Data {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    return try Data(
      contentsOf: root.appending(path: "Sources/HALCollectors/Resources/\(name).json")
    )
  }
}
