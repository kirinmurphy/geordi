import Foundation
import HALManifestKit

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
    return try decode(Data(contentsOf: manifest), schema: Data(contentsOf: schema))
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
