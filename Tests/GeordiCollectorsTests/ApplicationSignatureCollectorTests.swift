import Foundation
import GeordiCollectors
import GeordiDomain
import Testing

private struct StubSignatureInspector: CodeSignatureInspecting {
  let values: [String: ApplicationSignatureValue]

  func inspectApplication(at url: URL) -> ApplicationSignatureValue {
    values[url.path]
      ?? ApplicationSignatureValue(
        applicationPath: url.path,
        status: .unavailable,
        statusCode: -1
      )
  }
}

@Suite("Application signature collector")
struct ApplicationSignatureCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Signing observations preserve identity and validation facts")
  func signingFacts() throws {
    let path = "/Applications/Example.app"
    let application = applicationObservation(path: path)
    let inspector = StubSignatureInspector(values: [
      path: ApplicationSignatureValue(
        applicationPath: path,
        status: .valid,
        signingIdentifier: "com.example.application",
        teamIdentifier: "TEAM123",
        applicationGroupIdentifiers: ["TEAM123.shared"],
        authorities: ["Developer ID Application: Example"],
        platformBinary: false,
        statusCode: 0
      )
    ])
    let output = ApplicationSignatureCollector(
      inspector: inspector,
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan", applications: [application])

    #expect(output.run.state == .complete)
    let signature = try #require(output.observations.first)
    #expect(signature.subject == application.subject)
    #expect(signature.value.status == .valid)
    #expect(signature.value.teamIdentifier == "TEAM123")
    #expect(signature.value.applicationGroupIdentifiers == ["TEAM123.shared"])
    #expect(signature.value.authorities == ["Developer ID Application: Example"])
  }

  @Test(
    "Unsigned and invalid signatures are observations rather than collection failures",
    arguments: [
      CodeSignatureStatus.unsigned,
      CodeSignatureStatus.invalid,
    ]
  )
  func negativeSignatureStates(status: CodeSignatureStatus) {
    let path = "/Applications/Example.app"
    let application = applicationObservation(path: path)
    let output = ApplicationSignatureCollector(
      inspector: StubSignatureInspector(values: [
        path: ApplicationSignatureValue(
          applicationPath: path,
          status: status,
          statusCode: -1
        )
      ]),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan", applications: [application])

    #expect(output.run.state == .complete)
    #expect(output.run.issues.isEmpty)
    #expect(output.observations.first?.value.status == status)
  }

  @Test("Unavailable signing data makes collector coverage partial")
  func unavailableSignature() {
    let path = "/Applications/Example.app"
    let output = ApplicationSignatureCollector(
      inspector: StubSignatureInspector(values: [:]),
      clock: FixedClock(timestamp)
    ).collect(
      scanID: "scan",
      applications: [applicationObservation(path: path)]
    )

    #expect(output.run.state == .partial)
    #expect(output.run.issues.count == 1)
    #expect(output.observations.first?.value.status == .unavailable)
  }

  private func applicationObservation(
    path: String
  ) -> CollectedObservation<ApplicationBundleValue> {
    CollectedObservation(
      id: "application",
      scanID: "scan",
      collectorID: "application-bundles",
      schemaVersion: 1,
      observedAt: timestamp,
      subject: SubjectIdentity(
        primary: IdentityClaim(
          kind: .bundleIdentifier,
          value: "com.example.application"
        ),
        aliases: [IdentityClaim(kind: .canonicalPath, value: path)]
      ),
      sourceReference: "\(path)/Contents/Info.plist",
      value: ApplicationBundleValue(
        path: path,
        name: "Example",
        bundleIdentifier: "com.example.application",
        version: "1.0"
      )
    )
  }
}
