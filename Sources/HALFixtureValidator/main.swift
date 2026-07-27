import Darwin
import HALFixtures

do {
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
