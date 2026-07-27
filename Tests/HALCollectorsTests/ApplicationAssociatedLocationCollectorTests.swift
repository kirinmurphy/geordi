import Foundation
import HALCollectors
import HALDomain
import Testing

@Suite("Application associated-location collector")
struct ApplicationAssociatedLocationCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Bundled locations are declarative, bounded, and schema validated")
  func bundledConfiguration() throws {
    let configuration = try ApplicationAssociatedLocationConfiguration.bundled()
    #expect(configuration.schemaVersion == 1)
    #expect(!configuration.locations.isEmpty)
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
        "schemaVersion": 1,
        "locations": [{
          "id": "support",
          "categoryLabel": "Support",
          "pathTemplate": "$USER_HOME/Library/Application Support/$BUNDLE_ID",
          "match": "bundleIdentifier",
          "unexpected": true
        }]
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
        "schemaVersion": 1,
        "locations": [{
          "id": "escape",
          "categoryLabel": "Support",
          "pathTemplate": "$USER_HOME/../$BUNDLE_ID",
          "match": "bundleIdentifier"
        }]
      }
      """.utf8
    )
    #expect(throws: ApplicationAssociatedLocationConfigurationError.self) {
      try ApplicationAssociatedLocationConfiguration.decode(
        unsafePath,
        schema: ApplicationAssociatedLocationConfiguration.declarativeSchemaData()
      )
    }
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
    try Data("content HAL must not read".utf8).write(
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
    let locations = CollectorOutput(
      run: completeRun(collectorID: ApplicationAssociatedLocationCollector.id),
      observations: [exact, name, absent]
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

  private func location(_ id: String, suffix: String) -> AssociatedLocationConfiguration {
    AssociatedLocationConfiguration(
      id: id,
      categoryLabel: "Test",
      pathTemplate: "$USER_HOME/Library/\(suffix)/$BUNDLE_ID",
      match: .bundleIdentifier
    )
  }

  private func application(
    name: String = "Example"
  ) -> CollectedObservation<ApplicationBundleValue> {
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
        name: name,
        bundleIdentifier: "com.example.application"
      )
    )
  }

  private func associatedObservation(
    id: String,
    path: String,
    match: AssociatedLocationMatch,
    status: AssociatedLocationStatus
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
        applicationPath: "/Applications/Example.app",
        locationID: id,
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
