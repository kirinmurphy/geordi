import Foundation
import GeordiDomain

/// Typed projection of find-dupe-files' `--json` document (schema v1).
/// Field list mirrors cli/USAGE.md's contract; unknown keys are ignored
/// on decode but a schema_version mismatch is a hard error so the GUI
/// never renders a contract it does not understand.
struct DupeScanDocument: Equatable, Sendable {
  static let supportedSchemaVersion = 1

  struct FileEntry: Equatable, Identifiable, Sendable, Decodable {
    let path: String
    let size: Int?
    let mtime: Int?
    let temp: Bool

    var id: String { path }
    var fileName: String { (path as NSString).lastPathComponent }
  }

  struct Group: Equatable, Identifiable, Sendable {
    let tier: String
    let groupKey: String
    let files: [FileEntry]

    var id: String { groupKey }
    var count: Int { files.count }
  }

  let schemaVersion: Int
  let scanRoot: String
  let groups: [Group]

  var tiersOrdered: [(tier: String, groups: [Group])] {
    let order = ["byte-identical", "same-audio-payload", "same-name-different-bytes"]
    return order.compactMap { tier in
      let matching = groups.filter { $0.tier == tier }
      return matching.isEmpty ? nil : (tier, matching)
    }
  }
}

private struct RawGroup: Decodable {
  let tier: String
  let groupKey: String
  let files: [DupeScanDocument.FileEntry]

  enum CodingKeys: String, CodingKey {
    case tier
    case groupKey = "group_key"
    case files
  }
}

extension DupeScanDocument: Decodable {
  private enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case scanRoot = "scan_root"
    case groups
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    guard schemaVersion == Self.supportedSchemaVersion else {
      throw DecodingError.dataCorruptedError(
        forKey: .schemaVersion, in: container,
        debugDescription: "unsupported find-dupe-files JSON schema version \(schemaVersion)")
    }
    scanRoot = try container.decode(String.self, forKey: .scanRoot)
    let rawGroups = try container.decode([RawGroup].self, forKey: .groups)
    groups = rawGroups.map { Group(tier: $0.tier, groupKey: $0.groupKey, files: $0.files) }
  }
}

/// Running state for the read-only dupe view (plan slice B).
enum DupeScanState: Equatable, Sendable {
  case idle
  case running
  case loaded(DupeScanDocument)
  case failed(String)
}

/// Invokes the bundled find-dupe-files sidekick in --json mode.
/// Read-only: no destructive flags are ever passed here; deletion is a
/// separately designed app-side surface (plan decision).
struct CLIInvocation: Sendable {
  /// Bundled layout (from bundle-layout.json): Contents/Resources/geordi/…
  /// with a repository-checkout fallback for development runs.
  static func sidekickURL(bundle: Bundle = .main) -> URL? {
    let staged = bundle.bundleURL
      .appendingPathComponent("Contents/Resources/geordi/cli/bin/sidekicks/find-dupe-files")
    if FileManager.default.isExecutableFile(atPath: staged.path) {
      return staged
    }
    // development fallback: walk up from this source file to the repo root
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { url.deleteLastPathComponent() }
    let repo = url.appendingPathComponent("cli/bin/sidekicks/find-dupe-files")
    return FileManager.default.isExecutableFile(atPath: repo.path) ? repo : nil
  }

  func runJSONScan(at directory: String? = nil) async throws -> DupeScanDocument {
    guard let sidekick = Self.sidekickURL() else {
      throw CLIBridgeError.sidekickUnavailable
    }
    let scanRoot = directory ?? FileManager.default.homeDirectoryForCurrentUser.path
    let (code, stdout, stderr) = try await run(
      executable: "/usr/bin/python3", arguments: [sidekick.path, scanRoot, "--json"])
    guard code == 0 else {
      throw CLIBridgeError.scanFailed(
        "find-dupe-files exited \(code): \(stderr.prefix(400))")
    }
    guard let data = stdout.data(using: .utf8) else {
      throw CLIBridgeError.scanFailed("non-UTF8 output")
    }
    do {
      return try JSONDecoder().decode(DupeScanDocument.self, from: data)
    } catch {
      throw CLIBridgeError.scanFailed("could not decode JSON report: \(error)")
    }
  }

  private func run(executable: String, arguments: [String]) async throws
    -> (Int32, String, String)
  {
    try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: executable)
      process.arguments = arguments
      let stdout = Pipe()
      let stderr = Pipe()
      process.standardOutput = stdout
      process.standardError = stderr
      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
        return
      }
      process.terminationHandler = { _ in
        let out =
          String(
            data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err =
          String(
            data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        continuation.resume(returning: (process.terminationStatus, out, err))
      }
    }
  }
}

enum CLIBridgeError: LocalizedError {
  case sidekickUnavailable
  case scanFailed(String)

  var errorDescription: String? {
    switch self {
    case .sidekickUnavailable:
      return "The \(AppBrand.cliCommand) duplicate scanner is not available in this installation."
    case .scanFailed(let message):
      return message
    }
  }
}
