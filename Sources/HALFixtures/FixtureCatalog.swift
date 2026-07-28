import HALDomain

public enum FixtureCatalog {
  public static let all = ManifestProfileCatalog.loadRequiredCatalog()

  public static let familiarMac = required("familiar-mac")
  public static let atlasMac = required("atlas-mac")
  public static let simpleApplication = required("simple-application")
  public static let helperRichApplication = required("helper-rich-application")
  public static let resourceIncident = required("resource-incident")
  public static let ambiguousOwnership = required("ambiguous-ownership")
  public static let observationStates = required("observation-states")

  public static func fixture(id: String) -> SystemGraph? {
    all.first { $0.metadata.id == id }
  }

  public static func validateManifestProfiles() throws -> Int {
    try ManifestProfileCatalog.validateCatalog().count
  }

  private static func required(_ id: String) -> SystemGraph {
    guard let graph = fixture(id: id) else {
      preconditionFailure("Required synthetic profile \(id) is absent from the profile catalog.")
    }
    return graph
  }
}
