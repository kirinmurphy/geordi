import Foundation
import HALManifestKit

public struct InspectorDisplayProfile: Codable, Sendable {
  public static let currentVersion = 1
  public let schemaVersion: Int
  public let groups: [InspectorDetailGroup]
  public let fallbackGroupID: String

  public static func bundled() throws -> Self {
    guard
      let manifest = Bundle.module.url(
        forResource: "inspector-display-profile", withExtension: "json"),
      let schema = Bundle.module.url(
        forResource: "inspector-display-profile.schema", withExtension: "json")
    else { throw InspectorDisplayProfileError.resourceUnavailable }
    do {
      try DeclarativeManifestValidator.validate(
        instance: Data(contentsOf: manifest),
        against: Data(contentsOf: schema)
      )
      let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: manifest))
      guard value.schemaVersion == currentVersion else {
        throw InspectorDisplayProfileError.unsupportedVersion(value.schemaVersion)
      }
      guard value.groups.contains(where: { $0.id == value.fallbackGroupID }) else {
        throw InspectorDisplayProfileError.missingFallback
      }
      return value
    } catch let error as InspectorDisplayProfileError {
      throw error
    } catch {
      throw InspectorDisplayProfileError.invalid(String(describing: error))
    }
  }

  public func group(for label: String) -> InspectorDetailGroup {
    groups.first { $0.detailLabels.contains(label) }
      ?? groups.first { $0.id == fallbackGroupID }!
  }
}

public struct InspectorDetailGroup: Codable, Identifiable, Hashable, Sendable {
  public let id: String
  public let label: String
  public let detailLabels: [String]

  public init(id: String, label: String, detailLabels: [String]) {
    self.id = id
    self.label = label
    self.detailLabels = detailLabels
  }
}

public enum InspectorDisplayProfileError: Error {
  case resourceUnavailable
  case unsupportedVersion(Int)
  case missingFallback
  case invalid(String)
}
