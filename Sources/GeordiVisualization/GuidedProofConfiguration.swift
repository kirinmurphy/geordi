import Foundation
import GeordiManifestKit

public struct GuidedProofConfiguration: Codable, Sendable {
  public static let currentVersion = 1
  public let schemaVersion: Int
  public let title: String
  public let storyEntityID: String
  public let steps: [GuidedProofStep]

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(forResource: "guided-proof", withExtension: "json"),
      let schema = Bundle.module.url(forResource: "guided-proof.schema", withExtension: "json")
    else { throw GuidedProofConfigurationError.resourceUnavailable }
    let brand = ProductBrand.current
    return try decode(
      try brand.expandingTokens(in: Data(contentsOf: manifest)), schema: Data(contentsOf: schema))
  }

  public static func decode(_ data: Data, schema: Data) throws -> Self {
    do {
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let value = try JSONDecoder().decode(Self.self, from: data)
      guard value.schemaVersion == currentVersion else {
        throw GuidedProofConfigurationError.unsupportedVersion(value.schemaVersion)
      }
      guard Set(value.steps.map(\.id)).count == value.steps.count else {
        throw GuidedProofConfigurationError.duplicateStepID
      }
      return value
    } catch let error as GuidedProofConfigurationError {
      throw error
    } catch {
      throw GuidedProofConfigurationError.invalid(String(describing: error))
    }
  }
}

public struct GuidedProofStep: Codable, Identifiable, Hashable, Sendable {
  public let id: String
  public let title: String
  public let summary: String
  public let symbol: String
  public let takeaway: String
}

public enum GuidedProofConfigurationError: Error, Equatable {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case duplicateStepID
  case invalid(String)
}
