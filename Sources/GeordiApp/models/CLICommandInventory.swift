import Foundation
import GeordiDomain

/// Manifest-driven inventory of the commands the bundled CLI exposes.
/// Decoded from the staged command registry (`commands.json`) — never a
/// hardcoded list — so new commands appear without editing Swift.
public struct CLICommandInventory: Equatable, Sendable {
  public struct Entry: Equatable, Identifiable, Sendable {
    public let id: String
    public let tokens: [String]
    public let summary: String

    public var usage: String {
      ([AppBrand.cliCommand] + tokens).joined(separator: " ")
    }
  }

  public let entries: [Entry]

  /// Locate the staged registry inside the app bundle:
  /// Contents/Resources/geordi/cli/resources/commands.json (per
  /// cli/resources/bundle-layout.json). Falls back to the repository
  /// checkout for development runs outside a bundle.
  public static func bundled(bundle: Bundle = .main) -> CLICommandInventory? {
    if let url = bundleRegistryURL(bundle: bundle) {
      return decoded(from: url)
    }
    return repositoryFallback()
  }

  static func bundleRegistryURL(bundle: Bundle) -> URL? {
    let url = bundle.bundleURL
      .appendingPathComponent("Contents/Resources/geordi/cli/resources/commands.json")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  static func repositoryFallback() -> CLICommandInventory? {
    var url = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { url.deleteLastPathComponent() }  // Sources/GeordiApp/models -> repo root
    url.appendPathComponent("cli/resources/commands.json")
    return FileManager.default.fileExists(atPath: url.path)
      ? decoded(from: url) : nil
  }

  static func decoded(from url: URL) -> CLICommandInventory? {
    guard let data = try? Data(contentsOf: url),
      let document = try? JSONDecoder().decode(
        CommandRegistryDocument.self, from: data),
      document.schemaVersion == 1
    else { return nil }
    let entries = document.commands.map { command in
      Entry(
        id: command.command.joined(separator: "-"), tokens: command.command,
        summary: command.description)
    }
    return CLICommandInventory(entries: entries)
  }
}

private struct CommandRegistryDocument: Decodable {
  let schemaVersion: Int
  let commands: [CommandEntry]

  struct CommandEntry: Decodable {
    let command: [String]
    let description: String
  }
}
