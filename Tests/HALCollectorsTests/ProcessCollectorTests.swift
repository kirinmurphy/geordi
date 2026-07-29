import Foundation
import HALCollectors
import HALDomain
import Testing

@Suite("Point-in-time process collector")
struct ProcessCollectorTests {
  private let timestamp = Date(timeIntervalSince1970: 1_753_545_600)

  @Test("Collector preserves accessible, unmatched, and inaccessible records")
  func collectorStates() {
    let output = ProcessCollector(
      sampler: StubProcessSampler(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(output.run.state == .complete)
    #expect(output.observations.count == 3)
    #expect(
      output.observations.map(\.value.accessibility) == [
        .accessible, .limited, .inaccessible,
      ])
  }

  @Test("Resolver prefers exact executable, preserves helper and unmatched states")
  func deterministicResolution() throws {
    let configuration = ProcessCollectorConfiguration(
      maxProcessesPerApplication: 8,
      strategies: [
        ProcessResolutionStrategy(
          id: "exact",
          kind: .exactMainExecutable,
          confidence: .confirmed,
          priority: 100
        ),
        ProcessResolutionStrategy(
          id: "contained",
          kind: .containedInApplicationBundle,
          confidence: .high,
          priority: 80
        ),
      ]
    )
    let processes = ProcessCollector(
      sampler: StubProcessSampler(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")
    let output = ProcessApplicationResolver(
      configuration: configuration,
      clock: FixedClock(timestamp)
    ).resolve(
      scanID: "scan",
      processes: processes,
      applications: [application()]
    )

    #expect(output.observations.map(\.value.state) == [.matched, .matched, .inaccessible])
    #expect(output.observations[0].value.strategyID == "exact")
    #expect(output.observations[0].value.confidence == .confirmed)
    #expect(output.observations[1].value.strategyID == "contained")
    #expect(output.observations[1].value.confidence == .high)
    #expect(output.observations[2].value.applicationPaths.isEmpty)
  }

  @Test("Sampler failure is an unavailable collector result")
  func failure() {
    let output = ProcessCollector(
      sampler: FailingProcessSampler(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")

    #expect(output.run.state == .failed)
    #expect(output.run.availability == .unavailable)
    #expect(output.observations.isEmpty)
    #expect(output.run.issues.count == 1)
  }

  @Test("Native sampler returns a bounded point-in-time record set")
  func nativeSampler() throws {
    let values = try PSProcessSampler().sample()
    #expect(!values.isEmpty)
    #expect(values.allSatisfy { $0.pid > 0 && !$0.name.isEmpty })
  }

  @Test("Projection shows matched processes within the manifest budget")
  func projectionBudget() throws {
    let configuration = ProcessCollectorConfiguration(
      maxProcessesPerApplication: 1,
      strategies: [
        ProcessResolutionStrategy(
          id: "exact",
          kind: .exactMainExecutable,
          confidence: .confirmed,
          priority: 100
        ),
        ProcessResolutionStrategy(
          id: "contained",
          kind: .containedInApplicationBundle,
          confidence: .high,
          priority: 80
        ),
      ]
    )
    let application = application()
    let processOutput = ProcessCollector(
      sampler: StubProcessSampler(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")
    let resolutions = ProcessApplicationResolver(
      configuration: configuration,
      clock: FixedClock(timestamp)
    ).resolve(
      scanID: "scan",
      processes: processOutput,
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
      processes: processOutput,
      processResolutions: resolutions,
      maxProcessesPerApplication: configuration.maxProcessesPerApplication,
      maxUnmatchedProcesses: 1
    )

    try snapshot.graph.validate()
    #expect(snapshot.graph.entities.filter { $0.type == .process }.count == 2)
    #expect(snapshot.graph.relationships.count == 1)
    #expect(
      snapshot.graph.entity(snapshot.graph.relationships.first?.target ?? "")?.name == "Helper"
    )
    #expect(snapshot.graph.relationships.first?.evidence.count == 2)
    #expect(
      snapshot.graph.entities.first { $0.name == "Restricted" }?.details.contains {
        $0.label == "Application resolution" && $0.value == "Inaccessible"
      } == true)
  }

  @Test("Projection collapses identical executables and retains varying instance fields")
  func projectionGroupsProcessInstances() throws {
    let configuration = ProcessCollectorConfiguration(
      maxProcessesPerApplication: 8,
      strategies: [
        ProcessResolutionStrategy(
          id: "exact",
          kind: .exactMainExecutable,
          confidence: .confirmed,
          priority: 100
        )
      ]
    )
    let application = application()
    let processOutput = ProcessCollector(
      sampler: DuplicateProcessSampler(),
      clock: FixedClock(timestamp)
    ).collect(scanID: "scan")
    let resolutions = ProcessApplicationResolver(
      configuration: configuration,
      clock: FixedClock(timestamp)
    ).resolve(
      scanID: "scan",
      processes: processOutput,
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

    let graph = ApplicationGraphProjector().snapshot(
      scanID: "scan",
      output: applications,
      processes: processOutput,
      processResolutions: resolutions
    ).graph

    let process = try #require(graph.entities.first { $0.type == .process })
    #expect(graph.entities.filter { $0.type == .process }.count == 1)
    #expect(process.instances.count == 2)
    #expect(
      process.details.contains {
        $0.label == "Executable"
          && $0.value == "/Applications/Example.app/Contents/MacOS/Example"
      })
    #expect(
      process.instances.allSatisfy {
        $0.details.contains { $0.label == "PID" }
          && $0.details.contains { $0.label == "Memory at observation" }
      })
    #expect(graph.relationships.count == 1)
    #expect(graph.relationships[0].evidence.filter { $0.kind == .observed }.count == 2)
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
        bundleIdentifier: "com.example.application",
        executableName: "Example"
      )
    )
  }
}

private struct StubProcessSampler: ProcessSampling {
  func sample() throws -> [ProcessValue] {
    [
      ProcessValue(
        pid: 100,
        parentPID: 1,
        name: "Example",
        executablePath: "/Applications/Example.app/Contents/MacOS/Example",
        residentMemoryBytes: 10_000,
        accessibility: .accessible
      ),
      ProcessValue(
        pid: 101,
        parentPID: 100,
        name: "Helper",
        executablePath: "/Applications/Example.app/Contents/Helpers/Helper",
        residentMemoryBytes: 20_000,
        accessibility: .limited
      ),
      ProcessValue(
        pid: 102,
        name: "Restricted",
        accessibility: .inaccessible
      ),
    ]
  }
}

private struct FailingProcessSampler: ProcessSampling {
  func sample() throws -> [ProcessValue] {
    throw ProcessCollectorError.samplerFailed("Test")
  }
}

private struct DuplicateProcessSampler: ProcessSampling {
  func sample() throws -> [ProcessValue] {
    [
      ProcessValue(
        pid: 1_307,
        name: "Example",
        executablePath: "/Applications/Example.app/Contents/MacOS/Example",
        residentMemoryBytes: 137_000_000,
        accessibility: .accessible
      ),
      ProcessValue(
        pid: 1_310,
        name: "Example",
        executablePath: "/Applications/Example.app/Contents/MacOS/Example",
        residentMemoryBytes: 95_000_000,
        accessibility: .accessible
      ),
    ]
  }
}
