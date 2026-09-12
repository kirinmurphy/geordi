import Darwin
import Foundation
import GeordiFixtures
import GeordiProfileSchema

do {
  if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--export" {
    let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    for fixture in FixtureCatalog.all {
      let data = try SystemProfileSchema.encode(fixture)
      try data.write(
        to: directory.appendingPathComponent("\(fixture.metadata.id).json"),
        options: .atomic
      )
    }
    print("Exported \(FixtureCatalog.all.count) deterministic synthetic fixtures.")
    exit(EXIT_SUCCESS)
  }

  let manifestCount = try FixtureCatalog.validateManifestProfiles()
  print("✓ Validated \(manifestCount) schema-backed synthetic profile manifest(s).")
  for fixture in FixtureCatalog.all {
    try fixture.validate()
    print(
      "✓ \(fixture.metadata.id) v\(fixture.metadata.version): "
        + "\(fixture.entities.count) entities, \(fixture.relationships.count) relationships")
  }
  print("Validated \(FixtureCatalog.all.count) deterministic synthetic fixtures.")
} catch {
  fputs("Fixture validation failed: \(error)\n", stderr)
  exit(1)
}
