import Foundation
import GeordiDomain
import Testing

@testable import GeordiApp

@Suite("CLI command inventory")
struct CLICommandInventoryTests {
  @Test("Decodes the committed command registry with brand-prefixed usage")
  func decodesCommittedRegistry() throws {
    let inventory = try #require(CLICommandInventory.repositoryFallback())
    #expect(!inventory.entries.isEmpty)
    #expect(inventory.entries.contains { $0.tokens == ["find-dupe-files"] })
    #expect(inventory.entries.contains { $0.tokens == ["repair-cli"] })
    for entry in inventory.entries {
      #expect(entry.usage.hasPrefix("\(AppBrand.cliCommand) "))
      #expect(!entry.summary.isEmpty)
    }
  }

  @Test("Wrong schema version is rejected, not silently rendered")
  func rejectsUnknownSchemaVersion() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "commands.json")
    try Data(#"{"schemaVersion": 99, "commands": []}"#.utf8).write(to: url)

    #expect(CLICommandInventory.decoded(from: url) == nil)
  }

  @Test("Bundle lookup misses fall back to the repository checkout")
  func bundleMissFallsBack() throws {
    let empty = Bundle(path: Bundle.main.bundlePath) ?? .main
    // In tests Bundle.main has no staged CLI; either resolution path may
    // win on a dev machine, but the result must be identical.
    let viaBundle =
      CLICommandInventory.bundleRegistryURL(bundle: empty) != nil
      ? CLICommandInventory.bundled(bundle: empty)
      : CLICommandInventory.bundled(bundle: empty)
    let direct = CLICommandInventory.repositoryFallback()
    #expect(viaBundle?.entries.count == direct?.entries.count)
  }
}

@Suite("CLI link classification")
@MainActor
struct CLILinkClassificationTests {
  private func temporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test("Absent path reports notInstalled")
  func notInstalled() {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let status = CLIEnablementModel.classify(
      linkDirectory: directory.path, command: "geordi")
    #expect(status == .notInstalled)
  }

  @Test("Dangling symlink is distinguished from absent")
  func dangling() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let target = directory.appending(path: "geordi")
    try FileManager.default.createSymbolicLink(
      at: target, withDestinationURL: URL(fileURLWithPath: "/nonexistent/bundle"))
    let status = CLIEnablementModel.classify(
      linkDirectory: directory.path, command: "geordi")
    guard case .dangling(let previous) = status else {
      Issue.record("expected dangling, got \(status)")
      return
    }
    #expect(previous == "/nonexistent/bundle")
  }

  @Test("Bundle-path symlink counts as installed")
  func installed() throws {
    let directory = temporaryDirectory()
    let bundleContents = directory.appending(path: "geordi.app/Contents/MacOS")
    try FileManager.default.createDirectory(
      at: bundleContents, withIntermediateDirectories: true)
    let executable = bundleContents.appending(path: "geordi")
    try Data("#!/bin/sh\n".utf8).write(to: executable)
    let linkDirectory = temporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: directory)
      try? FileManager.default.removeItem(at: linkDirectory)
    }
    try FileManager.default.createSymbolicLink(
      at: linkDirectory.appending(path: "geordi"), withDestinationURL: executable)
    let status = CLIEnablementModel.classify(
      linkDirectory: linkDirectory.path, command: "geordi")
    guard case .installed = status else {
      Issue.record("expected installed, got \(status)")
      return
    }
  }

  @Test("Symlink to an unrelated checkout is wrongTarget, never overwritten")
  func wrongTarget() throws {
    let directory = temporaryDirectory()
    let other = directory.appending(path: "other-tool")
    try Data("#!/bin/sh\n".utf8).write(to: other)
    let linkDirectory = temporaryDirectory()
    defer {
      try? FileManager.default.removeItem(at: directory)
      try? FileManager.default.removeItem(at: linkDirectory)
    }
    try FileManager.default.createSymbolicLink(
      at: linkDirectory.appending(path: "geordi"), withDestinationURL: other)
    let status = CLIEnablementModel.classify(
      linkDirectory: linkDirectory.path, command: "geordi")
    guard case .wrongTarget = status else {
      Issue.record("expected wrongTarget, got \(status)")
      return
    }
  }

  @Test("A real file at the target is occupied")
  func occupied() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try Data("not a link".utf8).write(to: directory.appending(path: "geordi"))
    let status = CLIEnablementModel.classify(
      linkDirectory: directory.path, command: "geordi")
    guard case .occupied = status else {
      Issue.record("expected occupied, got \(status)")
      return
    }
  }
}

@Suite("Dupe scan document decoding")
struct DupeScanDecodingTests {
  private let json = """
    {
      "schema_version": 1,
      "scan_root": "/tmp/scan",
      "generated": "2026-09-13T19:00:00",
      "group_count": 2,
      "groups": [
        {"tier": "byte-identical", "group_key": "/tmp/scan/a|/tmp/scan/b",
         "count": 2, "files": [
           {"path": "/tmp/scan/a", "size": 10, "mtime": 1, "temp": false},
           {"path": "/tmp/scan/b", "size": 10, "mtime": 2, "temp": true}]},
        {"tier": "same-name-different-bytes", "group_key": "/tmp/scan/c|/tmp/scan/d",
         "count": 2, "files": [
           {"path": "/tmp/scan/c", "size": 1, "mtime": 3, "temp": false},
           {"path": "/tmp/scan/d", "size": 2, "mtime": 4, "temp": false}]}
      ]
    }
    """

  @Test("v1 document decodes and tiers order by confidence")
  func decodesAndOrders() throws {
    let document = try JSONDecoder().decode(
      DupeScanDocument.self, from: Data(json.utf8))
    #expect(document.groups.count == 2)
    let tiers = document.tiersOrdered.map(\.tier)
    #expect(tiers == ["byte-identical", "same-name-different-bytes"])
    let first = document.groups[0]
    #expect(first.files[1].temp)
    #expect(first.files[0].fileName == "a")
  }

  @Test("Schema-version mismatch is a hard decode error")
  func rejectsWrongSchemaVersion() {
    let mutated = json.replacingOccurrences(
      of: "\"schema_version\": 1", with: "\"schema_version\": 2")
    #expect(throws: DecodingError.self) {
      _ = try JSONDecoder().decode(DupeScanDocument.self, from: Data(mutated.utf8))
    }
  }
}
