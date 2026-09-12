import Foundation
import GeordiDomain
import Security

public protocol CodeSignatureInspecting: Sendable {
  func inspectApplication(at url: URL) -> ApplicationSignatureValue
}

public struct SecurityCodeSignatureInspector: CodeSignatureInspecting {
  public init() {}

  public func inspectApplication(at url: URL) -> ApplicationSignatureValue {
    var staticCode: SecStaticCode?
    let createStatus = SecStaticCodeCreateWithPath(
      url as CFURL,
      SecCSFlags(),
      &staticCode
    )
    guard createStatus == errSecSuccess, let staticCode else {
      return ApplicationSignatureValue(
        applicationPath: url.path,
        status: .unavailable,
        statusCode: createStatus
      )
    }

    let validationStatus = SecStaticCodeCheckValidity(
      staticCode,
      SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
      nil
    )
    guard validationStatus == errSecSuccess else {
      return ApplicationSignatureValue(
        applicationPath: url.path,
        status: validationStatus == errSecCSUnsigned ? .unsigned : .invalid,
        statusCode: validationStatus
      )
    }

    var information: CFDictionary?
    let informationStatus = SecCodeCopySigningInformation(
      staticCode,
      SecCSFlags(rawValue: kSecCSSigningInformation),
      &information
    )
    guard informationStatus == errSecSuccess,
      let values = information as? [CFString: Any]
    else {
      return ApplicationSignatureValue(
        applicationPath: url.path,
        status: .valid,
        statusCode: informationStatus
      )
    }

    return ApplicationSignatureValue(
      applicationPath: url.path,
      status: .valid,
      signingIdentifier: values[kSecCodeInfoIdentifier] as? String,
      teamIdentifier: values[kSecCodeInfoTeamIdentifier] as? String,
      applicationGroupIdentifiers: applicationGroupIdentifiers(
        values[kSecCodeInfoEntitlementsDict]
      ),
      authorities: certificateAuthorities(values[kSecCodeInfoCertificates]),
      platformBinary: values[kSecCodeInfoPlatformIdentifier] != nil,
      statusCode: validationStatus
    )
  }

  private func certificateAuthorities(_ value: Any?) -> [String] {
    guard let certificates = value as? [SecCertificate] else { return [] }
    return certificates.compactMap { certificate in
      SecCertificateCopySubjectSummary(certificate) as String?
    }
  }

  private func applicationGroupIdentifiers(_ value: Any?) -> [String] {
    guard
      let entitlements = value as? [String: Any],
      let identifiers = entitlements["com.apple.security.application-groups"] as? [String]
    else {
      return []
    }
    return Array(Set(identifiers.filter { !$0.isEmpty })).sorted()
  }
}

public struct ApplicationSignatureCollector: Sendable {
  public static let id: CollectorID = "application-signatures"
  public static let version = 1

  private let inspector: any CodeSignatureInspecting
  private let clock: any TimeSource

  public init(
    inspector: any CodeSignatureInspecting = SecurityCodeSignatureInspector(),
    clock: any TimeSource = SystemClock()
  ) {
    self.inspector = inspector
    self.clock = clock
  }

  public func collect(
    scanID: ScanID,
    applications: [CollectedObservation<ApplicationBundleValue>]
  ) -> CollectorOutput<ApplicationSignatureValue> {
    let startedAt = clock.now()
    let observations = applications.map { application in
      let value = inspector.inspectApplication(
        at: URL(fileURLWithPath: application.value.path)
      )
      return CollectedObservation(
        id: ObservationID("signature:\(application.value.path)"),
        scanID: scanID,
        collectorID: Self.id,
        schemaVersion: Self.version,
        observedAt: startedAt,
        subject: application.subject,
        sensitivity: application.sensitivity,
        sourceReference: application.value.path,
        value: value
      )
    }
    let completedAt = clock.now()
    let unavailableCount = observations.count {
      $0.value.status == .unavailable
    }
    let issues =
      unavailableCount == 0
      ? []
      : [
        CollectionIssue(
          id: "unavailable-signatures",
          severity: .warning,
          summary: "Signing information was unavailable for \(unavailableCount) application(s)."
        )
      ]
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: unavailableCount == 0 ? .complete : .partial,
        startedAt: startedAt,
        completedAt: completedAt,
        scope: applications.map(\.value.path),
        issues: issues
      ),
      observations: observations
    )
  }
}
