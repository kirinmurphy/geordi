import Foundation
import GeordiCollectors
import GeordiDomain
import Testing

@Suite("Application associated-location collector")
struct ApplicationAssociatedLocationCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Bundled locations are declarative, bounded, and schema validated")
  func bundledConfiguration() throws {
    let configuration = try ApplicationAssociatedLocationConfiguration.bundled()
    #expect(configuration.schemaVersion == 3)
    #expect(!configuration.locations.isEmpty)
    #expect(!configuration.enumerationRoots.isEmpty)
    #expect(configuration.locations.allSatisfy { $0.pathTemplate.hasPrefix("$USER_HOME/") })
    #expect(
      configuration.locations.allSatisfy {
        $0.pathTemplate.contains("$BUNDLE_ID") || $0.pathTemplate.contains("$APP_NAME")
      }
    )
  }

  @Test("Unknown fields and unsafe paths fail configuration")
  func invalidConfiguration() throws {
    let unknownField = Data(
      """
      {
        "schemaVersion": 3,
        "locations": [{
          "id": "support",
          "categoryLabel": "Support",
          "pathTemplate": "$USER_HOME/Library/Application Support/$BUNDLE_ID",
          "match": "bundleIdentifier",
          "unexpected": true
        }],
        "enumerationRoots": []
      }
      """.utf8
    )
    #expect(throws: ApplicationAssociatedLocationConfigurationError.self) {
      try ApplicationAssociatedLocationConfiguration.decode(
        unknownField,
        schema: ApplicationAssociatedLocationConfiguration.declarativeSchemaData()
      )
    }

    let unsafePath = Data(
      """
      {
        "schemaVersion": 3,
        "locations": [{
          "id": "escape",
          "categoryLabel": "Support",
          "pathTemplate": "$USER_HOME/../$BUNDLE_ID",
          "match": "bundleIdentifier"
        }],
        "enumerationRoots": []
      }
      """.utf8
    )
    #expect(throws: ApplicationAssociatedLocationConfigurationError.self) {
      try ApplicationAssociatedLocationConfiguration.decode(
        unsafePath,
        schema: ApplicationAssociatedLocationConfiguration.declarativeSchemaData()
      )
    }

    let unsafeRoot = Data(
      """
      {
        "schemaVersion": 3,
        "locations": [{
          "id": "support",
          "categoryLabel": "Support",
          "pathTemplate": "$USER_HOME/Library/Application Support/$BUNDLE_ID",
          "match": "bundleIdentifier"
        }],
        "enumerationRoots": [{
          "id": "escape-root",
          "categoryLabel": "Escape",
          "path": "$USER_HOME/../Library",
          "matching": "applicationIdentifiers",
          "maxEntries": 2
        }]
      }
      """.utf8
    )
    #expect(
      throws: ApplicationAssociatedLocationConfigurationError.invalidEnumerationRoot(
        "escape-root"
      )
    ) {
      try ApplicationAssociatedLocationConfiguration.decode(
        unsafeRoot,
        schema: ApplicationAssociatedLocationConfiguration.declarativeSchemaData()
      )
    }
  }

  @Test("Bounded enumeration preserves matched, unmatched, and group-container ambiguity")
  func boundedEnumeration() {
    let configuration = ApplicationAssociatedLocationConfiguration(
      locations: [],
      enumerationRoots: [
        AssociatedLocationEnumerationRoot(
          id: "cache-root",
          categoryLabel: "Cache",
          path: "$USER_HOME/Library/Caches",
          matching: .applicationIdentifiers,
          maxEntries: 2
        ),
        AssociatedLocationEnumerationRoot(
          id: "group-root",
          categoryLabel: "Group container",
          path: "$USER_HOME/Library/Group Containers",
          matching: .applicationGroupIdentifiers,
          maxEntries: 2
        ),
      ]
    )
    let output = ApplicationAssociatedLocationCollector(
      configuration: configuration,
      userHome: URL(fileURLWithPath: "/test-home"),
      inspector: PresentDirectoryInspector(),
      enumerator: StubAssociatedLocationEnumerator(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan", applications: [application()])

    #expect(output.observations.count == 4)
    #expect(output.observations.count { $0.value.match == .bundleIdentifier } == 1)
    #expect(output.observations.count { $0.value.match == .unmatched } == 1)
    #expect(output.observations.count { $0.value.match == .groupIdentifierUnavailable } == 2)
    #expect(
      output.observations.first { $0.value.match == .bundleIdentifier }?.value.applicationPath
        == "/Applications/Example.app"
    )
    #expect(
      output.observations.first { $0.value.match == .unmatched }?.value.applicationPath == nil
    )
    #expect(
      output.observations.filter { $0.value.match == .groupIdentifierUnavailable }
        .allSatisfy { $0.value.candidateApplicationPaths.isEmpty }
    )
    #expect(output.run.state == .partial)
    #expect(output.run.issues.map(\.id) == ["associated-location-budget-cache-root"])
  }

  @Test("Signed application-group identifiers preserve shared container membership")
  func applicationGroupMembership() throws {
    let configuration = ApplicationAssociatedLocationConfiguration(
      locations: [],
      enumerationRoots: [
        AssociatedLocationEnumerationRoot(
          id: "group-root",
          categoryLabel: "Group container",
          path: "$USER_HOME/Library/Group Containers",
          matching: .applicationGroupIdentifiers,
          maxEntries: 2
        )
      ]
    )
    let first = application()
    let second = application(
      name: "Companion",
      path: "/Applications/Companion.app",
      bundleIdentifier: "com.example.companion"
    )
    let signatures = [first, second].map {
      CollectedObservation(
        id: ObservationID("signature:\($0.value.path)"),
        scanID: "scan",
        collectorID: ApplicationSignatureCollector.id,
        schemaVersion: 1,
        observedAt: timestamp,
        subject: $0.subject,
        value: ApplicationSignatureValue(
          applicationPath: $0.value.path,
          status: .valid,
          applicationGroupIdentifiers: ["TEAM.shared"]
        )
      )
    }
    let output = ApplicationAssociatedLocationCollector(
      configuration: configuration,
      userHome: URL(fileURLWithPath: "/test-home"),
      inspector: PresentDirectoryInspector(),
      enumerator: StubAssociatedLocationEnumerator(),
      clock: FixedClock(timestamp)
    ).collect(
      scanID: "scan",
      applications: [first, second],
      signatures: signatures
    )

    #expect(output.observations.count == 3)
    let shared = output.observations.filter {
      $0.value.match == .applicationGroupIdentifier
    }
    #expect(shared.count == 2)
    #expect(
      shared.map(\.value.applicationPath).compactMap { $0 }.sorted() == [
        "/Applications/Companion.app", "/Applications/Example.app",
      ])
    #expect(
      shared.allSatisfy {
        $0.value.candidateApplicationPaths == [
          "/Applications/Companion.app", "/Applications/Example.app",
        ]
      }
    )
    #expect(
      output.observations.count { $0.value.match == .groupIdentifierUnavailable } == 1
    )

    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: CollectorOutput(
        run: completeRun(collectorID: ApplicationBundleCollector.id),
        observations: [first, second]
      ),
      associatedLocations: output
    )
    try snapshot.graph.validate()
    #expect(snapshot.graph.relationships.count == 2)
    #expect(snapshot.graph.relationships.allSatisfy { $0.type == .shares })
    #expect(snapshot.graph.relationships.allSatisfy { $0.confidence == .high })
  }

  @Test("Collector preserves present, absent, permission-denied, and unreadable states")
  func collectionStates() throws {
    let configuration = ApplicationAssociatedLocationConfiguration(
      locations: [
        location("present", suffix: "present"),
        location("absent", suffix: "absent"),
        location("denied", suffix: "denied"),
        location("unreadable", suffix: "unreadable"),
      ]
    )
    let output = ApplicationAssociatedLocationCollector(
      configuration: configuration,
      userHome: URL(fileURLWithPath: "/test-home"),
      inspector: StateAssociatedLocationInspector(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan", applications: [application()])

    #expect(
      output.observations.map(\.value.status) == [
        .absent, .permissionDenied, .present, .unreadable,
      ])
    #expect(output.run.state == .partial)
    #expect(output.run.issues.count == 2)
  }

  @Test("Filesystem inspector observes metadata without descending into a location")
  func filesystemMetadataOnly() throws {
    let root = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let location = root.appending(path: "Observed", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: location, withIntermediateDirectories: true)
    try Data("content collectors must not read".utf8).write(
      to: location.appending(path: "private.txt")
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let inspector = FileSystemAssociatedLocationInspector()
    #expect(
      inspector.inspectLocation(at: location)
        == AssociatedLocationInspection(
          status: .present,
          isDirectory: true
        ))
    #expect(
      inspector.inspectLocation(at: root.appending(path: "Missing")).status == .absent
    )
  }

  @Test("Filesystem enumeration is immediate and stops at the configured budget")
  func filesystemEnumerationIsBounded() throws {
    let root = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let first = root.appending(path: "First", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(
      at: first.appending(path: "Nested", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: root.appending(path: "Second", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: root.appending(path: "Third", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let result = try FileSystemAssociatedLocationEnumerator()
      .immediateChildren(at: root, limit: 2)

    #expect(result.children.count == 2)
    #expect(result.wasTruncated)
    #expect(
      result.children.allSatisfy {
        $0.deletingLastPathComponent().standardizedFileURL.path == root.standardizedFileURL.path
      }
    )
  }

  @Test("Enumeration refuses a configured root that resolves outside the user home")
  func enumerationRefusesSymlinkEscape() throws {
    let base = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let home = base.appending(path: "home", directoryHint: .isDirectory)
    let library = home.appending(path: "Library", directoryHint: .isDirectory)
    let outside = base.appending(path: "outside", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: library.appending(path: "Caches"),
      withDestinationURL: outside
    )
    defer { try? FileManager.default.removeItem(at: base) }
    let configuration = ApplicationAssociatedLocationConfiguration(
      locations: [],
      enumerationRoots: [
        AssociatedLocationEnumerationRoot(
          id: "cache-root",
          categoryLabel: "Cache",
          path: "$USER_HOME/Library/Caches",
          matching: .applicationIdentifiers,
          maxEntries: 2
        )
      ]
    )

    let output = ApplicationAssociatedLocationCollector(
      configuration: configuration,
      userHome: home,
      inspector: PresentDirectoryInspector(),
      enumerator: StubAssociatedLocationEnumerator(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan", applications: [application()])

    #expect(output.observations.isEmpty)
    #expect(output.run.state == .partial)
    #expect(output.run.issues.map(\.id) == ["associated-location-enumeration-cache-root"])
  }

  @Test("Unsafe application names cannot escape the user home")
  func unsafeApplicationName() {
    let configuration = ApplicationAssociatedLocationConfiguration(
      locations: [
        AssociatedLocationConfiguration(
          id: "name",
          categoryLabel: "Support",
          pathTemplate: "$USER_HOME/Library/Application Support/$APP_NAME",
          match: .applicationName
        )
      ]
    )
    let unsafeApplication = application(name: "../Escape")
    let output = ApplicationAssociatedLocationCollector(
      configuration: configuration,
      userHome: URL(fileURLWithPath: "/test-home"),
      inspector: StateAssociatedLocationInspector(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan", applications: [unsafeApplication])

    #expect(output.observations.isEmpty)
    #expect(output.run.state == .partial)
    #expect(output.run.issues.count == 1)
  }

  @Test("Projection creates evidence-bearing relationships only for present locations")
  func projection() throws {
    let applicationOutput = CollectorOutput(
      run: completeRun(collectorID: ApplicationBundleCollector.id),
      observations: [application()]
    )
    let exact = associatedObservation(
      id: "exact",
      path: "/test-home/Library/Caches/com.example.application",
      match: .bundleIdentifier,
      status: .present
    )
    let name = associatedObservation(
      id: "name",
      path: "/test-home/Library/Logs/Example",
      match: .applicationName,
      status: .present
    )
    let absent = associatedObservation(
      id: "absent",
      path: "/test-home/Library/WebKit/com.example.application",
      match: .bundleIdentifier,
      status: .absent
    )
    let unmatched = associatedObservation(
      id: "unmatched",
      path: "/test-home/Library/Caches/unclaimed",
      match: .unmatched,
      status: .present,
      applicationPath: nil
    )
    let locations = CollectorOutput(
      run: completeRun(collectorID: ApplicationAssociatedLocationCollector.id),
      observations: [exact, name, absent, unmatched]
    )

    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: applicationOutput,
      associatedLocations: locations
    )

    try snapshot.graph.validate()
    #expect(snapshot.graph.entities.filter { $0.type == .file }.count == 2)
    #expect(snapshot.graph.relationships.count == 2)
    #expect(snapshot.graph.relationships.allSatisfy { $0.type == .mayBelongTo })
    #expect(
      snapshot.graph.relationships.first {
        $0.target.rawValue.hasSuffix("com.example.application")
      }?.confidence == .high
    )
    #expect(
      snapshot.graph.relationships.first {
        $0.target.rawValue.hasSuffix("/Example")
      }?.confidence == .possible
    )
    #expect(snapshot.graph.relationships.allSatisfy { $0.evidence.count == 2 })
  }

  @Test("Projection gives distinct identities to multiple locations from one rule")
  func multipleLocationsFromOneRule() throws {
    let locations = CollectorOutput(
      run: completeRun(collectorID: ApplicationAssociatedLocationCollector.id),
      observations: [
        associatedObservation(
          id: "first-group",
          locationID: "group-container-children",
          path: "/test-home/Library/Group Containers/TEAM.first",
          match: .applicationGroupIdentifier,
          status: .present
        ),
        associatedObservation(
          id: "second-group",
          locationID: "group-container-children",
          path: "/test-home/Library/Group Containers/TEAM.second",
          match: .applicationGroupIdentifier,
          status: .present
        ),
      ]
    )

    let snapshot = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: CollectorOutput(
        run: completeRun(collectorID: ApplicationBundleCollector.id),
        observations: [application()]
      ),
      associatedLocations: locations
    )

    try snapshot.graph.validate()
    #expect(snapshot.graph.relationships.count == 2)
    #expect(Set(snapshot.graph.relationships.map(\.id)).count == 2)
    #expect(Set(snapshot.graph.relationships.map(\.target)).count == 2)
  }

  private func location(_ id: String, suffix: String) -> AssociatedLocationConfiguration {
    AssociatedLocationConfiguration(
      id: id,
      categoryLabel: "Test",
      pathTemplate: "$USER_HOME/Library/\(suffix)/$BUNDLE_ID",
      match: .bundleIdentifier
    )
  }

  private func application(
    name: String = "Example",
    path: String = "/Applications/Example.app",
    bundleIdentifier: String = "com.example.application"
  ) -> CollectedObservation<ApplicationBundleValue> {
    CollectedObservation(
      id: ObservationID("application:\(path)"),
      scanID: "scan",
      collectorID: ApplicationBundleCollector.id,
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .bundleIdentifier, value: bundleIdentifier)
      ),
      value: ApplicationBundleValue(
        path: path,
        name: name,
        bundleIdentifier: bundleIdentifier
      )
    )
  }

  private func associatedObservation(
    id: String,
    locationID: String? = nil,
    path: String,
    match: AssociatedLocationMatch,
    status: AssociatedLocationStatus,
    applicationPath: String? = "/Applications/Example.app"
  ) -> CollectedObservation<ApplicationAssociatedLocationValue> {
    CollectedObservation(
      id: ObservationID(id),
      scanID: "scan",
      collectorID: ApplicationAssociatedLocationCollector.id,
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(kind: .bundleIdentifier, value: "com.example.application")
      ),
      value: ApplicationAssociatedLocationValue(
        applicationPath: applicationPath,
        locationID: locationID ?? id,
        locationPath: path,
        categoryLabel: "Test data",
        match: match,
        status: status,
        isDirectory: true
      )
    )
  }

  private func completeRun(collectorID: CollectorID) -> CollectorRun {
    CollectorRun(
      collectorID: collectorID,
      collectorVersion: 1,
      availability: .available,
      state: .complete,
      startedAt: timestamp,
      completedAt: timestamp
    )
  }
}

private struct StateAssociatedLocationInspector: AssociatedLocationInspecting {
  func inspectLocation(at url: URL) -> AssociatedLocationInspection {
    if url.path.contains("/present/") {
      return AssociatedLocationInspection(status: .present, isDirectory: true)
    }
    if url.path.contains("/denied/") {
      return AssociatedLocationInspection(status: .permissionDenied)
    }
    if url.path.contains("/unreadable/") {
      return AssociatedLocationInspection(status: .unreadable)
    }
    return AssociatedLocationInspection(status: .absent)
  }
}

private struct PresentDirectoryInspector: AssociatedLocationInspecting {
  func inspectLocation(at url: URL) -> AssociatedLocationInspection {
    AssociatedLocationInspection(status: .present, isDirectory: true)
  }
}

private struct StubAssociatedLocationEnumerator: AssociatedLocationEnumerating {
  func immediateChildren(
    at root: URL,
    limit: Int
  ) throws -> AssociatedLocationEnumeration {
    if root.lastPathComponent == "Caches" {
      return AssociatedLocationEnumeration(
        children: [
          root.appending(path: "com.example.application"),
          root.appending(path: "unclaimed.cache"),
        ],
        wasTruncated: true
      )
    }
    return AssociatedLocationEnumeration(
      children: [
        root.appending(path: "TEAM.shared"),
        root.appending(path: "TEAM.unresolved"),
      ],
      wasTruncated: false
    )
  }
}
