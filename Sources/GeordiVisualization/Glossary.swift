import Foundation
import GeordiManifestKit

public struct Glossary: Codable, Sendable {
  public static let currentVersion = 1
  public let schemaVersion: Int
  public let hoverDelayMilliseconds: Int
  public let terms: [GlossaryTerm]

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "glossary", withExtension: "json"),
      let schema = Bundle.module.url(forResource: "glossary.schema", withExtension: "json")
    else { throw GlossaryError.resourceUnavailable }
    let brand = ProductBrand.current
    return try decode(
      try brand.expandingTokens(in: Data(contentsOf: manifest)), schema: Data(contentsOf: schema))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let glossary = try JSONDecoder().decode(Self.self, from: data)
      guard glossary.schemaVersion == currentVersion else {
        throw GlossaryError.unsupportedVersion(glossary.schemaVersion)
      }
      guard Set(glossary.terms.map(\.id)).count == glossary.terms.count else {
        throw GlossaryError.duplicateID
      }
      let aliases = glossary.terms.flatMap {
        [$0.displayTerm.lowercased()]
          + $0.aliases.map {
            $0.lowercased()
          }
      }
      guard Set(aliases).count == aliases.count else { throw GlossaryError.duplicateAlias }
      return glossary
    } catch let error as GlossaryError {
      throw error
    } catch {
      throw GlossaryError.invalid(String(describing: error))
    }
  }

  public func term(id: String) -> GlossaryTerm? { terms.first { $0.id == id } }

  public func term(matchingExactAlias value: String) -> GlossaryTerm? {
    let key = value.lowercased()
    return terms.first {
      $0.displayTerm.lowercased() == key || $0.aliases.map { $0.lowercased() }.contains(key)
    }
  }

  public func tokens(in text: String, context: String) -> [GlossaryToken] {
    let candidates =
      terms
      .filter { $0.contexts.contains(context) || $0.contexts.contains("all") }
      .flatMap { term in ([term.displayTerm] + term.aliases).map { ($0, term) } }
      .sorted { $0.0.count > $1.0.count }
    var output: [GlossaryToken] = []
    var cursor = text.startIndex
    while cursor < text.endIndex {
      let remainder = text[cursor...]
      let match = candidates.compactMap { alias, term -> (Range<String.Index>, GlossaryTerm)? in
        guard
          let range = remainder.range(
            of: alias,
            options: [.caseInsensitive, .diacriticInsensitive]
          ),
          isWordBoundary(range.lowerBound, in: text),
          isWordBoundary(range.upperBound, in: text)
        else { return nil }
        return (range, term)
      }.min { $0.0.lowerBound < $1.0.lowerBound }
      guard let match else {
        output.append(.text(String(remainder)))
        break
      }
      if cursor < match.0.lowerBound {
        output.append(.text(String(text[cursor..<match.0.lowerBound])))
      }
      output.append(.term(String(text[match.0]), match.1))
      cursor = match.0.upperBound
    }
    return output
  }

  private func isWordBoundary(_ index: String.Index, in text: String) -> Bool {
    guard index > text.startIndex && index < text.endIndex else { return true }
    let before = text[text.index(before: index)]
    let after = text[index]
    return !before.isLetter && !before.isNumber || !after.isLetter && !after.isNumber
  }
}

public enum GlossaryToken: Hashable, Sendable {
  case text(String)
  case term(String, GlossaryTerm)
}

public struct GlossaryTerm: Codable, Identifiable, Hashable, Sendable {
  public let id: String
  public let displayTerm: String
  public let description: String
  public let explanation: String?
  public let aliases: [String]
  public let contexts: [String]
}

public enum GlossaryError: Error, Equatable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateID
  case duplicateAlias
  case invalid(String)
}
