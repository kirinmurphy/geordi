import Foundation
import HALDomain

public protocol ProcessSampling: Sendable {
  func sample() throws -> [ProcessValue]
}

public struct PSProcessSampler: ProcessSampling {
  public init() {}

  public func sample() throws -> [ProcessValue] {
    let process = Process()
    let output = Pipe()
    let errors = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/ps")
    process.arguments = ["-axo", "pid=,ppid=,rss=,comm="]
    process.standardOutput = output
    process.standardError = errors
    try process.run()
    let outputData = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let message = String(
        decoding: errors.fileHandleForReading.readDataToEndOfFile(),
        as: UTF8.self
      )
      throw ProcessCollectorError.samplerFailed(message)
    }
    return String(decoding: outputData, as: UTF8.self)
      .split(whereSeparator: \.isNewline)
      .compactMap(parseLine)
      .sorted { $0.pid < $1.pid }
  }

  private func parseLine(_ line: Substring) -> ProcessValue? {
    let fields = line.split(
      maxSplits: 3,
      omittingEmptySubsequences: true,
      whereSeparator: \.isWhitespace
    )
    guard
      fields.count == 4,
      let pid = Int32(fields[0]),
      let parentPID = Int32(fields[1]),
      let residentKilobytes = UInt64(fields[2])
    else {
      return nil
    }
    let executable = String(fields[3])
    return ProcessValue(
      pid: pid,
      parentPID: parentPID,
      name: URL(fileURLWithPath: executable).lastPathComponent,
      executablePath: executable.hasPrefix("/") ? executable : nil,
      residentMemoryBytes: residentKilobytes * 1_024,
      accessibility: executable.hasPrefix("/") ? .accessible : .limited
    )
  }
}

public struct ProcessCollector: Sendable {
  public static let id: CollectorID = "process-snapshot"
  public static let version = 1

  private let sampler: any ProcessSampling
  private let clock: any HALClock

  public init(
    sampler: any ProcessSampling = PSProcessSampler(),
    clock: any HALClock = SystemClock()
  ) {
    self.sampler = sampler
    self.clock = clock
  }

  public func collect(scanID: ScanID) -> CollectorOutput<ProcessValue> {
    let startedAt = clock.now()
    do {
      let values = try sampler.sample()
      let observations = values.map { value in
        CollectedObservation(
          id: ObservationID("process:\(scanID.rawValue):\(value.pid)"),
          scanID: scanID,
          collectorID: Self.id,
          schemaVersion: Self.version,
          observedAt: startedAt,
          subject: SubjectIdentity(
            primary: IdentityClaim(
              kind: .processInstance,
              value: "\(scanID.rawValue):\(value.pid)"
            ),
            aliases: value.executablePath.map {
              [IdentityClaim(kind: .executable, value: $0)]
            } ?? []
          ),
          sensitivity: .privateMetadata,
          sourceReference: value.executablePath,
          value: value
        )
      }
      return CollectorOutput(
        run: CollectorRun(
          collectorID: Self.id,
          collectorVersion: Self.version,
          availability: .available,
          state: .complete,
          startedAt: startedAt,
          completedAt: clock.now(),
          scope: ["point-in-time"],
          issues: values.isEmpty
            ? [
              CollectionIssue(
                id: "empty-process-snapshot",
                severity: .warning,
                summary: "The point-in-time process snapshot was empty."
              )
            ] : []
        ),
        observations: observations
      )
    } catch {
      return CollectorOutput(
        run: CollectorRun(
          collectorID: Self.id,
          collectorVersion: Self.version,
          availability: .unavailable,
          state: .failed,
          startedAt: startedAt,
          completedAt: clock.now(),
          scope: ["point-in-time"],
          issues: [
            CollectionIssue(
              id: "process-snapshot-failed",
              severity: .error,
              summary:
                "\(AppBrand.displayName) could not collect the point-in-time process snapshot."
            )
          ]
        ),
        observations: []
      )
    }
  }
}

public enum ProcessCollectorError: Error, Equatable, Sendable {
  case samplerFailed(String)
}
