import Darwin
import Foundation
import GeordiDomain

public protocol ApplicationProvenanceInspecting: Sendable {
  func inspectApplication(
    at url: URL,
    adapters: [ApplicationProvenanceAdapterConfiguration]
  ) -> [ApplicationProvenanceFact]
}

public struct FileSystemApplicationProvenanceInspector: ApplicationProvenanceInspecting {
  public init() {}

  public func inspectApplication(
    at url: URL,
    adapters: [ApplicationProvenanceAdapterConfiguration]
  ) -> [ApplicationProvenanceFact] {
    adapters.map { adapter in
      switch adapter.kind {
      case .appStoreReceipt:
        appStoreReceiptFact(at: url, displayLabel: adapter.displayLabel)
      case .downloadOrigin:
        downloadOriginFact(at: url, displayLabel: adapter.displayLabel)
      }
    }
  }

  private func appStoreReceiptFact(
    at applicationURL: URL,
    displayLabel: String
  ) -> ApplicationProvenanceFact {
    let receiptURL = applicationURL.appending(path: "Contents/_MASReceipt/receipt")
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(
      atPath: receiptURL.path,
      isDirectory: &isDirectory
    )
    return ApplicationProvenanceFact(
      kind: .appStoreReceipt,
      displayLabel: displayLabel,
      status: exists && !isDirectory.boolValue ? .present : .absent,
      source: "Application bundle receipt location"
    )
  }

  private func downloadOriginFact(
    at applicationURL: URL,
    displayLabel: String
  ) -> ApplicationProvenanceFact {
    let attribute = "com.apple.metadata:kMDItemWhereFroms"
    switch extendedAttribute(named: attribute, at: applicationURL) {
    case .missing:
      return ApplicationProvenanceFact(
        kind: .downloadOrigin,
        displayLabel: displayLabel,
        status: .absent,
        source: "Filesystem extended attribute"
      )
    case .unreadable:
      return ApplicationProvenanceFact(
        kind: .downloadOrigin,
        displayLabel: displayLabel,
        status: .unreadable,
        source: "Filesystem extended attribute"
      )
    case .data(let data):
      guard
        let values = try? PropertyListSerialization.propertyList(
          from: data,
          options: [],
          format: nil
        ) as? [String]
      else {
        return ApplicationProvenanceFact(
          kind: .downloadOrigin,
          displayLabel: displayLabel,
          status: .unreadable,
          source: "Filesystem extended attribute"
        )
      }
      let hosts = values.compactMap { URL(string: $0)?.host(percentEncoded: false) }
      return ApplicationProvenanceFact(
        kind: .downloadOrigin,
        displayLabel: displayLabel,
        status: .present,
        source: "Filesystem extended attribute",
        detail: hosts.isEmpty ? nil : Array(Set(hosts)).sorted().joined(separator: ", ")
      )
    }
  }

  private enum ExtendedAttributeResult {
    case data(Data)
    case missing
    case unreadable
  }

  private func extendedAttribute(named name: String, at url: URL) -> ExtendedAttributeResult {
    let size = getxattr(url.path, name, nil, 0, 0, 0)
    guard size >= 0 else {
      return errno == ENOATTR ? .missing : .unreadable
    }
    var data = Data(count: size)
    let count = data.withUnsafeMutableBytes { bytes in
      getxattr(url.path, name, bytes.baseAddress, size, 0, 0)
    }
    guard count == size else { return .unreadable }
    return .data(data)
  }
}

public struct ApplicationProvenanceCollector: Sendable {
  public static let id: CollectorID = "application-provenance"
  public static let version = 2

  private let adapters: [ApplicationProvenanceAdapterConfiguration]
  private let inspector: any ApplicationProvenanceInspecting
  private let clock: any TimeSource

  public init(
    configuration: ApplicationProvenanceConfiguration,
    inspector: any ApplicationProvenanceInspecting = FileSystemApplicationProvenanceInspector(),
    clock: any TimeSource = SystemClock()
  ) {
    adapters = configuration.adapters
    self.inspector = inspector
    self.clock = clock
  }

  public func collect(
    scanID: ScanID,
    applications: [CollectedObservation<ApplicationBundleValue>]
  ) -> CollectorOutput<ApplicationProvenanceValue> {
    let startedAt = clock.now()
    let observations = applications.map { application in
      let facts = inspector.inspectApplication(
        at: URL(fileURLWithPath: application.value.path),
        adapters: adapters
      )
      return CollectedObservation(
        id: ObservationID("provenance:\(application.value.path)"),
        scanID: scanID,
        collectorID: Self.id,
        schemaVersion: Self.version,
        observedAt: startedAt,
        subject: application.subject,
        sensitivity: application.sensitivity,
        sourceReference: application.value.path,
        value: ApplicationProvenanceValue(
          applicationPath: application.value.path,
          facts: facts
        )
      )
    }
    let unreadableCount = observations.reduce(0) { count, observation in
      count + observation.value.facts.count { $0.status == .unreadable }
    }
    let issues =
      unreadableCount == 0
      ? []
      : [
        CollectionIssue(
          id: "unreadable-provenance",
          severity: .warning,
          summary: "Provenance metadata was unreadable for \(unreadableCount) source(s)."
        )
      ]
    return CollectorOutput(
      run: CollectorRun(
        collectorID: Self.id,
        collectorVersion: Self.version,
        availability: .available,
        state: unreadableCount == 0 ? .complete : .partial,
        startedAt: startedAt,
        completedAt: clock.now(),
        scope: adapters.map(\.id),
        issues: issues
      ),
      observations: observations
    )
  }
}
