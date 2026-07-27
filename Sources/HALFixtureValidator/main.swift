import Darwin
import Foundation
import HALFixtures
import HALProfileSchema

do {
  if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--export" {
    let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    for fixture in FixtureCatalog.all {
      let document = SystemProfileDocument(graph: fixture)
      try document.validate()
      var data = try encoder.encode(document)
      data.append(0x0A)
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
