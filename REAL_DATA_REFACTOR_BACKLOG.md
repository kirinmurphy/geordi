# Real Data and Profile Refactor Backlog

This is the persistent implementation checklist for replacing Phase 0's
code-defined fixtures with schema-validated profiles and adding explicit real
Mac linking. Architectural rationale lives in `REAL_DATA_ASSESSMENT.md`;
field availability lives in `REAL_DATA_FIELD_MATRIX.md`.

## Priority 0: composition and schema foundation

- [x] Add repository rules for manifest-driven composition and synthetic/live
  parity.
- [x] Create one versioned `SystemProfile` schema for normalized synthetic and
  live snapshots.
- [x] Make declarative JSON Schema the canonical structural contract; keep
  Swift limited to generic validation, typed decoding, semantic integrity, and
  projection.
- [x] Define strict decoding, unknown-key rejection, semantic validation, and
  field-path diagnostics.
- [x] Define schema migration/version policy in `SCHEMA_VERSIONING.md`.
- [ ] Add a manifest catalog for profile composition.
- [ ] Add per-resource manifests for independently discoverable complex items.
- [ ] Add collection manifests for small resource sets.
- [x] Move application collector search roots out of Swift defaults and into a
  validated manifest.
- [ ] Define rebuildable-data detector manifests, including locations,
  classification, exclusions, and evidence rules.
- [ ] Keep nonconfigurable security invariants in code.

## Priority 1: synthetic/live schema parity

- [ ] Convert the familiar fictional Mac from Swift entity construction to a
  schema-validated profile manifest.
- [x] Convert the simple-application fixture end-to-end as the schema reference
  profile.
- [ ] Convert the remaining focused fixture scenarios.
- [ ] Make `HALFixtures` load manifests through the centralized decoder.
- [x] Validate every manifest-backed synthetic profile in unit tests and the
  fixture validator.
- [x] Make build verification fail when a committed profile is invalid or uses
  an unsupported schema version.
- [ ] Add schema fixtures for partial, unavailable, permission-denied,
  ambiguous, stale, and negative states.
- [ ] Add a deterministic fixture-generation/export format based on the same
  schema.
- [ ] Remove entity-instance switches and hardcoded entity presentation behavior
  from Swift once equivalent manifest fields exist.

## Priority 2: data-source lifecycle

- [x] Persist `synthetic` versus `linkedMac` as a user preference.
- [x] Keep first launch synthetic and guarantee it performs no real collection.
- [x] Add **Link to your Mac** to the fictional-data banner.
- [x] Add a homepage welcome prompt above alerts explaining HAL and the fictional
  profile.
- [x] Allow both onboarding prompts to be dismissed while remaining synthetic.
- [x] Add an obscure but discoverable data-source control in the sidebar footer.
- [x] When linked, label collection time, freshness, partial coverage, and
  permissions.
- [x] Define refresh and error behavior without silently falling back from live
  to synthetic data.

## Priority 3: unlink, backup, and reset

- [x] Inventory every persisted user-data location before implementing reset.
- [x] Define an export/backup format and explicit destination selection.
- [x] Define what preferences survive unlinking, if anything.
- [x] Add **Unlink this Mac** in the sidebar footer when linked.
- [x] Offer backup, delete, or cancel before unlinking.
- [x] Revalidate exact reset targets and refuse broad or unexpected paths.
- [x] Add temporary-root integration tests for atomic backup, symlinks,
  target replacement, and complete reset.
- [x] After confirmed unlink, remove compiled user data and return to the
  deterministic first-launch profile.
- [x] Do not add real deletion until storage, backup, and safety tests are
  complete.

## Priority 4: real application atlas

- [x] Add typed scan, observation, capability, issue, and freshness models.
- [x] Add a graph snapshot provider boundary.
- [x] Add bounded read-only application bundle enumeration.
- [x] Add static signing observation and validation.
- [x] Select application collector roots from manifests.
- [ ] Add receipt and provenance adapters selected through manifests.
- [ ] Add point-in-time process collection.
- [ ] Add deterministic process-to-application resolution.
- [ ] Preserve unmatched and inaccessible process records.
- [x] Add explicit manual refresh.
- [ ] Add redacted diagnostic export.

## Priority 5: history, storage, and incidents

- [ ] Add SQLite only after the normalized profile and observation schema settle.
- [ ] Store immutable scans, collector runs, observations, evidence, findings,
  decisions, and retention state.
- [ ] Load storage-detector resources from manifests.
- [ ] Add bounded read-only size observation and growth history.
- [ ] Keep reclaimability as a versioned finding, not collector output.
- [ ] Add resource time series and incidents only after sampling overhead and
  retention semantics are tested.

## Current next step

Complete the schema-validated synthetic profile catalog and remaining fixture
migration. Then add receipt/provenance and process collectors without expanding
live UI claims beyond the evidence collected.
