import Foundation
import Testing

@testable import HALCollectors

@Suite("Bounded collection scheduler")
struct BoundedCollectionSchedulerTests {
  @Test("Concurrency is bounded and results retain manifest order")
  func boundedAndDeterministic() async throws {
    let tracker = ConcurrencyTracker()
    let jobs: [@Sendable () throws -> Int] = (0..<8).map { index in
      {
        tracker.started()
        defer { tracker.finished() }
        Thread.sleep(forTimeInterval: Double(8 - index) * 0.002)
        return index
      }
    }

    let results = try await BoundedCollectionScheduler.run(jobs, limit: 3)

    #expect(results == Array(0..<8))
    #expect(tracker.maximumActive == 3)
  }

  @Test("Cancellation prevents queued stages from starting")
  func cancellationStopsQueuedStages() async throws {
    let tracker = ConcurrencyTracker()
    let gate = DispatchSemaphore(value: 0)
    let jobs: [@Sendable () throws -> Int] = (0..<6).map { index in
      {
        tracker.started()
        defer { tracker.finished() }
        gate.wait()
        return index
      }
    }
    let task = Task {
      try await BoundedCollectionScheduler.run(jobs, limit: 2)
    }
    while tracker.totalStarted < 2 {
      await Task.yield()
    }

    task.cancel()
    gate.signal()
    gate.signal()

    do {
      _ = try await task.value
      Issue.record("Cancelled collection unexpectedly completed.")
    } catch is CancellationError {
      #expect(tracker.totalStarted == 2)
    }
  }
}

private final class ConcurrencyTracker: @unchecked Sendable {
  private let lock = NSLock()
  private var active = 0
  private var maximum = 0
  private var startedCount = 0

  var maximumActive: Int { lock.withLock { maximum } }
  var totalStarted: Int { lock.withLock { startedCount } }

  func started() {
    lock.withLock {
      active += 1
      startedCount += 1
      maximum = max(maximum, active)
    }
  }

  func finished() {
    lock.withLock { active -= 1 }
  }
}
