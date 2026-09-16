import Darwin
import Foundation
import GeordiDomain

/// Bounded size walk honoring the versioned measurement policy: entry and
/// depth caps, a wall-clock budget checked at the policy's interval, no
/// symlink descent, allocated bytes counted once per file ID, and staying
/// on the root's own file system. Read-only: every call is lstat/readdir.
struct RebuildableDataSizeScanner: Sendable {
  let policy: RebuildableDataMeasurementPolicy
  let clock: any TimeSource

  /// Returns nil only when the root itself cannot be lstat'd; callers
  /// have already established presence via the inspector.
  func measure(
    at root: URL,
    excludedDescendantNames: Set<String>
  ) -> RebuildableDataSizeMeasurement? {
    guard let rootAttributes = lstatAttributes(root.path) else { return nil }
    let rootDevice = rootAttributes.st_dev
    let deadline = Date(
      timeIntervalSince: clock.now(),
      by: TimeInterval(policy.maxDurationMilliseconds) / 1_000)

    var allocatedBytes = Int64(0)
    var entryCount = 0
    var isTruncated = false
    var seenFileIDs = Set<FileID>()
    var pending: [(path: String, depth: Int)] = [(root.path, 0)]

    outer: while let current = pending.popLast() {
      let names: [String]
      do {
        names = try FileManager.default.contentsOfDirectory(atPath: current.path)
      } catch {
        // An unreadable subdirectory means the total is a lower bound.
        isTruncated = true
        continue
      }
      for name in names {
        if entryCount >= policy.maxEntriesPerLocation {
          isTruncated = true
          break outer
        }
        entryCount += 1
        if entryCount % policy.cancellationCheckIntervalEntries == 0, clock.now() >= deadline {
          isTruncated = true
          break outer
        }
        if excludedDescendantNames.contains(name) { continue }

        let childPath = current.path + "/" + name
        guard let attributes = lstatAttributes(childPath) else { continue }
        if policy.stayOnFileSystem, attributes.st_dev != rootDevice { continue }

        let kind = attributes.st_mode & S_IFMT
        if kind == S_IFLNK { continue }  // symbolicLinkPolicy: doNotFollow
        if kind == S_IFDIR {
          if current.depth + 1 < policy.maxDepth {
            pending.append((childPath, current.depth + 1))
          } else {
            isTruncated = true
          }
          continue
        }
        guard kind == S_IFREG else { continue }

        if policy.hardLinkPolicy == .countAllocatedBytesOncePerFileID {
          let fileID = FileID(device: attributes.st_dev, inode: attributes.st_ino)
          guard seenFileIDs.insert(fileID).inserted else { continue }
        }
        allocatedBytes += Int64(attributes.st_blocks) * 512
      }
    }

    return RebuildableDataSizeMeasurement(
      allocatedBytes: allocatedBytes,
      entryCount: entryCount,
      isTruncated: isTruncated
    )
  }

  private func lstatAttributes(_ path: String) -> stat? {
    var information = stat()
    guard lstat(path, &information) == 0 else { return nil }
    return information
  }

  private struct FileID: Hashable {
    let device: dev_t
    let inode: ino_t
  }
}

extension Date {
  fileprivate init(timeIntervalSince date: Date, by interval: TimeInterval) {
    self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate + interval)
  }
}
