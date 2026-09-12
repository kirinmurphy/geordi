import Foundation
import GeordiDomain
import GeordiManifestKit
import GeordiProfileSchema

enum ManifestProfileCatalog {
  private static let catalogResource = "profile-catalog"
  private static let schemaResource = "profile-catalog.schema"

  static func loadRequiredCatalog() -> [SystemGraph] {
    do {
      return try validateCatalog().map(\.graph)
    } catch {
      preconditionFailure("Invalid synthetic profile catalog: \(error)")
    }
  }

  static func validateCatalog() throws -> [CatalogProfile] {
    let catalogData = try resourceData(named: catalogResource)
    try DeclarativeManifestValidator.validate(
      instance: catalogData,
      against: resourceData(named: schemaResource)
    )

    let catalog = try JSONDecoder().decode(ProfileCatalogDocument.self, from: catalogData)
    guard catalog.schemaVersion == 1 else {
      throw ProfileCatalogError.unsupportedVersion(catalog.schemaVersion)
    }

    let entryIDs = catalog.profiles.map(\.id)
    guard Set(entryIDs).count == entryIDs.count else {
      throw ProfileCatalogError.duplicateProfileID
    }
    let resources = catalog.profiles.map(\.resource)
    guard Set(resources).count == resources.count else {
      throw ProfileCatalogError.duplicateResource
    }

    let profiles = try catalog.profiles.map { entry in
      let document = try SystemProfileSchema.decode(resourceData(named: entry.resource))
      guard document.id == entry.id else {
        throw ProfileCatalogError.identifierMismatch(
          catalogID: entry.id,
          profileID: document.id
        )
      }
      return CatalogProfile(entry: entry, graph: document.graph())
    }

    let committedProfiles = Set(
      (Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
        .map { $0.deletingPathExtension().lastPathComponent }
        .filter { $0 != catalogResource && !$0.hasSuffix(".schema") }
    )
    let catalogResources = Set(resources)
    guard committedProfiles == catalogResources else {
      throw ProfileCatalogError.resourceSetMismatch(
        missingFromCatalog: committedProfiles.subtracting(catalogResources).sorted(),
        missingFromBundle: catalogResources.subtracting(committedProfiles).sorted()
      )
    }
    return profiles
  }

  private static func resourceData(named name: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
      throw ProfileCatalogError.missingResource("\(name).json")
    }
    return try Data(contentsOf: url)
  }
}

struct CatalogProfile {
  let entry: ProfileCatalogEntry
  let graph: SystemGraph
}

private struct ProfileCatalogDocument: Decodable {
  let schemaVersion: Int
  let profiles: [ProfileCatalogEntry]
}

struct ProfileCatalogEntry: Decodable {
  let id: String
  let resource: String
}

enum ProfileCatalogError: Error, CustomStringConvertible {
  case duplicateProfileID
  case duplicateResource
  case identifierMismatch(catalogID: String, profileID: String)
  case missingResource(String)
  case resourceSetMismatch(missingFromCatalog: [String], missingFromBundle: [String])
  case unsupportedVersion(Int)

  var description: String {
    switch self {
    case .duplicateProfileID:
      "Profile catalog contains a duplicate profile identifier."
    case .duplicateResource:
      "Profile catalog contains a duplicate resource."
    case .identifierMismatch(let catalogID, let profileID):
      "Catalog profile \(catalogID) resolved to document \(profileID)."
    case .missingResource(let resource):
      "Profile catalog resource is missing: \(resource)."
    case .resourceSetMismatch(let missingFromCatalog, let missingFromBundle):
      "Profile catalog resource mismatch; uncataloged: \(missingFromCatalog), missing: \(missingFromBundle)."
    case .unsupportedVersion(let version):
      "Unsupported profile catalog schema version \(version)."
    }
  }
}
