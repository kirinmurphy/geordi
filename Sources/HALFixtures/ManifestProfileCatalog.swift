import Foundation
import HALDomain
import HALProfileSchema

enum ManifestProfileCatalog {
  static func loadRequired(_ name: String) -> SystemGraph {
    do {
      guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
        preconditionFailure("Missing required synthetic profile manifest: \(name).json")
      }
      let document = try SystemProfileSchema.decode(Data(contentsOf: url))
      return document.graph()
    } catch {
      preconditionFailure("Invalid synthetic profile manifest \(name).json: \(error)")
    }
  }

  static func validateAll() throws -> [SystemProfileDocument] {
    let urls =
      Bundle.module.urls(
        forResourcesWithExtension: "json",
        subdirectory: nil
      ) ?? []
    return try urls.sorted { $0.lastPathComponent < $1.lastPathComponent }.map {
      try SystemProfileSchema.decode(Data(contentsOf: $0))
    }
  }
}
