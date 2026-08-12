import HALCollectors
import HALDomain
import HALVisualization

enum AppBootstrap {
  static func applicationProfile() -> AppConfiguration {
    required("application profile") {
      try AppConfiguration.bundled()
    }
  }

  static func applicationClassifications() -> ApplicationClassificationConfiguration {
    required("application classification profile") {
      try ApplicationClassificationConfiguration.bundled()
    }
  }

  static func displayPolicy() -> DisplayPolicy {
    required("display policy") {
      try DisplayPolicy.bundled()
    }
  }

  static func explorationContexts() -> ExplorationContextConfiguration {
    required("exploration contexts") {
      try ExplorationContextConfiguration.bundled()
    }
  }

  static func filesystemLocations() -> FilesystemLocationCatalog {
    required("filesystem location catalog") {
      try FilesystemLocationCatalog.bundled()
    }
  }

  private static func required<Value>(
    _ name: String,
    load: () throws -> Value
  ) -> Value {
    do {
      return try load()
    } catch {
      preconditionFailure("Required \(name) failed validation: \(error.localizedDescription)")
    }
  }
}
