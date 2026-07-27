# Real Data and Profile Refactor Backlog

This is the persistent implementation checklist for replacing Phase 0's
code-defined fixtures with schema-validated profiles and adding explicit real
Mac linking. Architectural rationale lives in `REAL_DATA_ASSESSMENT.md`;
field availability lives in `REAL_DATA_FIELD_MATRIX.md`.

## Test-drive stabilization: current priority

These items were recorded from the first linked-Mac product test on
2026-07-27. Complete them before expanding collection breadth.

### Initial linking flow

- [ ] Replace the banner-only `Linking…` state with a focused setup overlay
  that explains HAL is performing read-only collection.
- [ ] Disable controls whose meaning depends on the selected data source while
  the initial link is unresolved.
- [ ] Keep unlink, destructive reset, and ordinary refresh unavailable during
  initial linking.
- [ ] Offer **Cancel and keep exploring the fictional Mac**, not **Undo**:
  linked mode is not persisted until collection succeeds, so there is no
  committed change to undo.
- [ ] Make initial collection cooperatively cancellable and ignore late results
  from a cancelled link.
- [ ] Show a compact stage indicator:
  **Connect → Observe applications → Build your atlas → Ready**.
- [ ] Describe which facts are being read and reiterate that no applications or
  machine data are changed.
- [ ] On success, land on a clear completion state with a primary
  **Explore installed applications** action.
- [ ] On failure, remain synthetic and show a retryable, field-path-aware or
  collector-aware explanation.

### Linked completion and refresh

- [ ] Replace the green “Read-only application inventory” notification with a
  completion/coverage panel that answers:
  what finished, what HAL learned, what remains unavailable, and what the user
  can explore next.
- [ ] Remove **Refresh Now** as the primary post-link action. It is not the next
  step in setup and currently suggests that missing capabilities will be
  collected.
- [ ] Rename manual refresh to **Check this Mac again** and explain that it
  reruns the same enabled read-only collectors.
- [ ] Keep an existing linked snapshot interactive during manual refresh; use
  inline progress rather than a blocking overlay.
- [ ] Show an explicit completion acknowledgement even when refreshed data is
  unchanged, including “Checked just now,” duration, and collector coverage.
- [ ] Show whether a refresh changed the displayed snapshot.
- [ ] Add model/UI tests for initial-link progress, cancellation, successful
  handoff, unchanged refresh, changed refresh, and refresh failure with retained
  data.

### Useful application scope

- [ ] Default the linked application list to **Apps outside macOS**, with a
  visible option to include system applications.
- [ ] Define the classification through a versioned manifest using multiple
  evidence fields such as protected system location and platform signature;
  do not hardcode application instances or paths in presentation code.
- [ ] Label uncertain cases honestly. Folder location alone must not become an
  “installed by you” claim.
- [ ] Add counts for visible, hidden system, and uncertain applications.
- [ ] Preserve search access to hidden system applications when the user
  explicitly includes them.
- [ ] Later add a separate **Noteworthy activity** section only after process,
  storage, or incident observations exist; do not rank applications using
  synthetic or unsupported metrics in live mode.

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
- [x] Add a manifest catalog for profile composition.
- [ ] Add per-resource manifests for independently discoverable complex items.
- [ ] Add collection manifests for small resource sets.
- [x] Move application collector search roots out of Swift defaults and into a
  validated manifest.
- [ ] Define rebuildable-data detector manifests, including locations,
  classification, exclusions, and evidence rules.
- [ ] Keep nonconfigurable security invariants in code.

## Priority 1: synthetic/live schema parity

- [x] Convert the familiar fictional Mac from Swift entity construction to a
  schema-validated profile manifest.
- [x] Convert the simple-application fixture end-to-end as the schema reference
  profile.
- [x] Convert the remaining focused fixture scenarios.
- [x] Make `HALFixtures` load manifests through the centralized decoder.
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
  - [x] Observe App Store receipt presence without retaining receipt contents.
  - [x] Observe retained download origins with URL paths redacted to hostnames.
  - [ ] Add installer-package receipt correlation.
  - [ ] Add Homebrew provenance.
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

Stabilize the initial linked-Mac workflow and default application scope using
the test-drive checklist above. Fix the dead-end completion and no-feedback
refresh behavior before adding process collection. Then add the point-in-time
process collector and deterministic application resolution without expanding
live UI claims beyond collected evidence.
