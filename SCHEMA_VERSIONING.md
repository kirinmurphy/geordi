# System Profile Schema Versioning

This document defines compatibility and migration rules for HAL's normalized
system-profile manifests. The canonical contract is
`Sources/HALProfileSchema/Resources/system-profile.schema.json`.

Collector and composition manifests have their own adjacent schemas and
independent version fields. They follow the same strict compatibility and
same-change test rules, but changing a collector manifest does not change the
normalized system-profile version unless its emitted data contract changes.

## Compatibility contract

`schemaVersion` is an integer major version. A profile is accepted only when
its version equals the version supported by the running application. HAL does
not silently reinterpret an older or newer profile.

Changes that do not alter the accepted document shape do not require a schema
version change. Examples include clearer descriptions, test coverage, generic
validator improvements, or stronger semantic checks for invariants that were
already required by the documented model.

A new schema version is required when a change:

- adds, removes, or renames a required property;
- changes a property's type or meaning;
- removes an enum value or changes its meaning;
- changes identity, relationship, evidence, or ownership semantics;
- changes whether unknown properties are accepted;
- makes a previously valid profile structurally invalid.

Adding an optional property or enum case is still treated as a versioned
change while HAL uses strict decoding and exact Swift enum parity. This avoids
profiles that validate in one component but cannot be decoded in another.

## Change procedure

Every schema change must update, in the same commit:

1. the canonical JSON Schema and its `$id`;
2. `SystemProfileSchema.currentVersion` and typed Swift projections;
3. schema/domain parity and invalid-document tests;
4. every committed synthetic profile, including negative and unavailable
   states affected by the change;
5. fixture validation and any profile-generation utilities;
6. the field matrix, assessment, configuration guide, or backlog when product
   semantics change.

Build verification must fail if any committed profile is stale, invalid, or
not decodable into the typed domain projection.

## Migration rules

Migrations are explicit, deterministic transformations from one complete
document version to the next. A migration:

- operates on an exported or synthetic profile, never by rescanning the Mac;
- preserves source observations, evidence, confidence, timestamps, and unknown
  or unavailable states;
- must not promote inferred facts to observed facts;
- must not invent evidence to satisfy a newer schema;
- is covered by golden input/output tests and is safe to run repeatedly;
- fails with a field path and actionable explanation when lossless conversion
  is impossible.

System-profile version 2 adds optional, schema-validated entity presentation
metadata and moves all committed synthetic profiles to version 2. Version 1
documents are rejected rather than silently reinterpreted. No persisted
version-1 system-profile documents shipped as user data, so an automated
migration registry is not warranted yet; any future persisted-format migration
must follow the rules above.

## Persisted live data

Collector output is normalized into a versioned profile before domain or
presentation use. Persisted scans retain the schema version used when they were
created. Application startup must not mutate historical scans in place.

When migrations exist, HAL should migrate into a new record or cache and retain
the original until the replacement validates. A failed migration leaves the
original untouched and presents it as unavailable due to version mismatch.

## Fixture and export policy

Synthetic fixtures, diagnostic exports, backups, and normalized live scans use
the same schema and validator. Generators must emit stable ordering and
deterministic identifiers so changes remain reviewable.

Exports identify their schema version but must not include secrets or private
paths by default. Redaction is a separate explicit transformation and must not
change evidence or confidence semantics.
