import Foundation
import HALManifestKit

public struct ShellPathConfiguration: Codable, Hashable, Sendable {
  public static let currentVersion = 1
  public let schemaVersion: Int
  public let startupFiles: [ShellStartupFile]
  public let maximumLines: Int

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "shell-path", withExtension: "json"),
      let schema = Bundle.module.url(forResource: "shell-path.schema", withExtension: "json")
    else { throw ShellPathConfigurationError.resourceUnavailable }
    let data = try Data(contentsOf: manifest)
    try DeclarativeManifestValidator.validate(
      instance: data,
      against: Data(contentsOf: schema)
    )
    let configuration = try JSONDecoder().decode(Self.self, from: data)
    guard configuration.schemaVersion == currentVersion else {
      throw ShellPathConfigurationError.unsupportedVersion(configuration.schemaVersion)
    }
    return configuration
  }
}

public struct ShellStartupFile: Codable, Hashable, Sendable, Identifiable {
  public let id: String
  public let label: String
  public let path: String
  public let order: Int
}

public enum ShellPathConfigurationError: Error {
  case resourceUnavailable
  case unsupportedVersion(Int)
}

public struct ShellPathAnalysis: Hashable, Sendable {
  public let operations: [ShellPathOperation]
  public let resultingDirectories: [String]
  public let diagnostics: [String]
}

public struct ShellPathOperation: Identifiable, Hashable, Sendable {
  public enum Kind: String, Hashable, Sendable {
    case prepend
    case append
    case replace
    case source
    case unresolved
  }

  public let id: String
  public let line: Int
  public let kind: Kind
  public let value: String
}

public struct ShellPathAnalyzer: Sendable {
  public init() {}

  public func analyze(_ text: String, maximumLines: Int) -> ShellPathAnalysis {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    var path = ["Inherited system PATH"]
    var operations: [ShellPathOperation] = []
    var diagnostics: [String] = []
    if lines.count > maximumLines {
      diagnostics.append("Only the first \(maximumLines) lines were analyzed.")
    }

    for (offset, rawLine) in lines.prefix(maximumLines).enumerated() {
      let lineNumber = offset + 1
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      guard !line.isEmpty, !line.hasPrefix("#") else { continue }
      if let sourced = sourcedPath(in: line) {
        operations.append(
          ShellPathOperation(
            id: "source-\(lineNumber)",
            line: lineNumber,
            kind: .source,
            value: sourced
          ))
        continue
      }
      guard let assignment = pathAssignment(in: line) else { continue }
      let pieces = assignment.split(separator: ":", omittingEmptySubsequences: false).map(
        String.init)
      guard let inheritedIndex = pieces.firstIndex(where: { $0 == "$PATH" || $0 == "${PATH}" })
      else {
        path = pieces
        operations.append(
          ShellPathOperation(
            id: "replace-\(lineNumber)",
            line: lineNumber,
            kind: .replace,
            value: pieces.joined(separator: " → ")
          ))
        continue
      }
      let before = Array(pieces[..<inheritedIndex]).filter { !$0.isEmpty }
      let after = Array(pieces.dropFirst(inheritedIndex + 1)).filter { !$0.isEmpty }
      path = before + path + after
      if !before.isEmpty {
        operations.append(
          ShellPathOperation(
            id: "prepend-\(lineNumber)",
            line: lineNumber,
            kind: .prepend,
            value: before.joined(separator: " → ")
          ))
      }
      if !after.isEmpty {
        operations.append(
          ShellPathOperation(
            id: "append-\(lineNumber)",
            line: lineNumber,
            kind: .append,
            value: after.joined(separator: " → ")
          ))
      }
      if pieces.contains(where: { $0.contains("$") && $0 != "$PATH" && $0 != "${PATH}" }) {
        diagnostics.append(
          "Line \(lineNumber) contains a variable HAL did not expand; it remains literal."
        )
      }
    }
    return ShellPathAnalysis(
      operations: operations,
      resultingDirectories: path,
      diagnostics: diagnostics
    )
  }

  private func pathAssignment(in line: String) -> String? {
    var candidate = line
    if candidate.hasPrefix("export ") {
      candidate.removeFirst("export ".count)
    }
    guard candidate.hasPrefix("PATH=") else { return nil }
    var value = String(candidate.dropFirst("PATH=".count))
    if value.count >= 2,
      (value.first == "\"" && value.last == "\"")
        || (value.first == "'" && value.last == "'")
    {
      value.removeFirst()
      value.removeLast()
    }
    return value
  }

  private func sourcedPath(in line: String) -> String? {
    if line.hasPrefix("source ") {
      return String(line.dropFirst("source ".count))
    }
    if line.hasPrefix(". ") {
      return String(line.dropFirst(2))
    }
    return nil
  }
}
