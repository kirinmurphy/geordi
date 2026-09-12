# Real Machine Data Assessment

Status: historical assessment. Its initial domain and read-only collection
recommendations have been implemented. Current priority is defined in
`NEXT_PRODUCT_VALIDATION_PLAN.md`; remaining engineering work is tracked in
`FUTURE_PHASE_PLANS.md`.

## Decision

geordi should take a hybrid approach:

1. Complete a focused domain and collection-boundary preparation.
2. Immediately follow it with a narrow, manually refreshed, read-only application
   and process atlas.
3. Preserve synthetic fixtures as a first-class mode for tests, demonstrations,
   product evaluation, and failure simulation.

geordi is ready to begin real observation, but the current Phase 0 Swift model is
not yet able to represent real data honestly. `Entity.details` is an untyped
array of display strings, evidence has no collection time or stable observation
reference, and the graph has no scan, capability, freshness, or lifecycle model.
Real collectors should not be forced into those presentation-oriented types.

The first real-data milestone should remain the real application atlas described
in `ROADMAP.md`: application bundles, durable identity, version, signing
identity, basic provenance evidence, a point-in-time process snapshot, and
explicitly unresolved processes.

## Repository evidence

This assessment is based on the implementation and the wider repository
documentation, not only the README:

- `ARCHITECTURE.md` defines collectors, immutable observations, normalization,
  evidence-scored resolution, findings, SQLite history, presentation, and
  explicit actions as separate layers.
- `PHASE_0.md` explicitly limits Phase 0 to deterministic synthetic data and
  excludes real scanning, persistence, cleanup, background agents, privileged
  access, and Endpoint Security.
- `PRIVACY.md` requires local-first operation, contextual permissions, minimal
  retention, redaction, no routine file-content inspection, no V1 network
  destinations, and no V1 active-window history.
- `ROADMAP.md` defines Milestone 1 as a read-only explorer of real installed
  applications and running processes.
- `V1.md`, `V2.md`, and `FEATURES.md` distinguish observed state, identity,
  trust, provenance, persistence, history, reclaimability, and user decisions.
- `TESTING.md` calls for deterministic clocks, capability simulation, recorded
  collector responses, partial-data tests, and opt-in read-only live tests.
- `Sources/GeordiDomain/Entity.swift` currently stores all domain-specific
  properties as `Detail(label, value)` strings.
- `Sources/GeordiDomain/Relationship.swift` preserves direction, confidence, and
  observed-versus-inferred evidence, but not observation timestamps, source
  identity, raw references, or resolver versions.
- `Sources/GeordiDomain/SystemGraph.swift` is a fixture-shaped current graph without
  scan or freshness context.
- `Sources/GeordiFixtures/FamiliarMac.swift` and
  `Sources/GeordiFixtures/FixtureCatalog.swift` contain all current values,
  explanations, incidents, and relationships as authored fixture data.
- `Sources/GeordiApp/GeordiApp.swift` initializes the app directly from
  `FixtureCatalog`.
- `Tests/GeordiFixturesTests/FixtureTests.swift` verifies fictional labeling,
  ambiguity, protected data, and noncausal incident wording.
- `STATUS.md` confirms there is no SQLite schema, real collector, persistence,
  export, notification, or action layer.

## Realism of the current fixtures

The fixtures have:

- High product realism: recognizable applications and comprehensible user
  narratives.
- Medium structural realism: applications, processes, files, persistence,
  packages, resources, events, incidents, and ambiguous many-to-many edges.
- Low observational realism: no value is produced by a real sampling method,
  real system record, or captured machine snapshot.

They model useful shapes:

- Multi-process applications.
- Package managers and shell frameworks.
- Helpers and persistence.
- Caches, logs, configuration, application data, and user data.
- Resource contributors and temporally nearby events.
- Ambiguous ownership and protected shared data.
- Evidence-bearing relationships with confidence.

They do not model the full difficulty of a real Mac:

- Partial permissions and inaccessible records.
- Processes disappearing during enumeration.
- Multiple apps with the same bundle identifier.
- Missing or malformed metadata.
- Multiple package-manager installations and prefixes.
- File aliases, symlinks, hard links, sparse files, APFS clones, and volume
  boundaries.
- Collector failures and incomplete scan scope.
- Observation age and historical gaps.
- Identity changes and entity lifecycle.
- Large unresolved populations and real graph density.

Every current size, CPU percentage, memory value, time, duration, state,
provenance label, event, incident, relationship explanation, confidence, and
reclaim recommendation is hardcoded demo content. Descriptions such as
“Synthetic process record,” “Synthetic file activity,” and “Synthetic storage
snapshot” are fixture evidence labels, not captured evidence.

## Field availability reference

The classification legend and complete field-by-field availability matrix now
live in `REAL_DATA_FIELD_MATRIX.md`. Keeping that reference separate allows the
implementation plan in this document and the platform-source matrix to evolve
independently.

## Architectural preparation

### Typed observations

Collectors should return typed, immutable observations. They should not create
UI strings, findings, reclaim recommendations, or ownership conclusions.

Each observation needs:

- A stable observation identifier.
- A collector and schema identifier.
- The scan identifier.
- The observation time.
- The observed subject identity.
- Typed payload.
- Optional source record reference.
- Redaction classification.

### Scan and capability context

Each collection run needs:

- Scan identifier.
- Start and completion times.
- Declared scope.
- Collector versions.
- Complete, partial, failed, permission-denied, unsupported, and unavailable
  states.
- Structured issues and omitted scope.

### Freshness

Presentation should distinguish:

- Fresh.
- Aging.
- Stale.
- Partial.
- Unavailable.
- Permission denied.
- Never collected.

Freshness policy is collector-specific. Current process state may become stale
within seconds, while a static signature can remain useful until the file
changes.

### Identity and lifecycle

Stable entities and ephemeral observations must be distinct:

- An application identity can outlive versions and paths.
- A process instance is identified by at least PID and start time.
- A process sample belongs to a process instance and interval.
- A path observation belongs to a scan and filesystem identity where available.
- Missing, removed, and unavailable are different states.

Use namespaced identity claims and aliases rather than treating one arbitrary
string as universal identity.

### Evidence and findings

Evidence should reference observations and include:

- Evidence type: observation, deterministic derivation, or heuristic inference.
- Source and observation time.
- Resolver or rule identifier and version.
- Human-readable explanation generated from structured facts.
- Quality, ambiguity, and competing evidence where relevant.

Findings must be distinct from relationships and observations. Reclaim
recommendations, performance alerts, and orphaned persistence are findings, not
collected facts.

### Provider boundary

The application should consume a graph or workspace provider rather than import
`FixtureCatalog` as its data source. Synthetic and live read-only providers
should implement the same application-facing boundary.

The stable presentation projection may remain `SystemGraph`, but it must carry
source context, freshness, and evidence references when used for live data.

## Phased implementation plan

### Phase A: domain and collection contracts

Build before machine collection:

1. Typed scan, capability, freshness, observation, and issue models.
2. Typed subject identities and aliases.
3. Stronger evidence records and versioned resolution metadata.
4. A separate finding model.
5. A provider boundary for presentation snapshots.
6. Synthetic and live-read-only environment modes.
7. A deterministic clock.
8. Capability, partial-result, and failure simulation in fixtures.
9. UI states for observed time, stale data, partial data, and unavailable data.

### Phase B: first real-data milestone

On explicit manual refresh, collect:

1. Applications from bounded standard locations.
2. Name, bundle ID, version, build, path, executable, and icon.
3. Static signing identity, Team ID, and validation.
4. App Store receipt, quarantine, package, and Homebrew evidence when available.
5. One process snapshot with PID/start time, PPID, executable path, CPU, and
   memory.
6. Deterministic process-to-bundle correlations.
7. First-class unmatched and inaccessible process records.
8. Scan duration, scope, errors, capabilities, and timestamp.
9. An explicit, redacted diagnostic export.

Exit criterion: geordi explains representative real applications, including one
with helpers, more clearly than a raw process list while clearly marking
unresolved and stale information.

### Phase C: read-only persistence snapshot

- Inventory user and system LaunchAgents and LaunchDaemons.
- Inventory embedded login items, XPC services, and helpers.
- Record declaration, approval, loaded, and running state independently.
- Correlate executable paths, containment, bundle IDs, receipts, and signatures.
- Preserve unresolved persistence.
- Add no enable, disable, register, unregister, or removal controls.

### Phase D: persistence and history storage

Introduce SQLite and migrations for:

- Scans and collector runs.
- Immutable observations.
- Identities and aliases.
- Relationship assertions and evidence.
- Application, process, persistence, and storage snapshots.
- Findings and user decisions.
- Retention and aggregation.
- First seen, last seen, changed, and removed state.

### Phase E: storage investigation

- Scan bounded conventional application support, cache, log, and
  package-manager paths.
- Record logical and allocated sizes.
- Apply detector-specific category and rebuildability rules.
- Preserve growth history.
- Resolve application associations with evidence and confidence.
- Default user, shared, symlinked, inaccessible, and ambiguous data to
  protected.
- Produce review-only findings.

Do not add cleanup.

### Phase F: resource history and incidents

- Low-rate CPU, memory pressure, swap, and disk-I/O history.
- Per-process contribution.
- Versioned incident state machines.
- Nearby events expressed only as temporal correlation.
- Adaptive sampling only after geordi's own overhead is measured.

## Test and fixture strategy

Keep all existing authored fixtures. Add:

1. Recorded, redacted platform-response fixtures.
2. Typed observation fixtures after platform parsing.
3. Expected normalized graph and finding fixtures.
4. Permission-denied, unavailable, malformed, partial, and stale cases.
5. A deterministic clock for all time-dependent tests.
6. Opt-in, read-only live tests that never inspect private content.
7. Performance tests for collector duration, traversal limits, memory, and idle
   overhead.

A fixture-export tool may generate a candidate fixture from a real scan only
after explicit user action. It must:

- Replace usernames and home paths.
- Remap PIDs and unstable identifiers.
- Strip arguments, destinations, document names, project names, and secrets.
- Quantize or replace sensitive timestamps.
- Preserve relationship shapes, capability failures, and uncertainty.
- Require human review before committing generated output.

## Explicit deferrals

Defer:

- Cleanup and all destructive actions.
- Complete-footprint claims.
- Automatic safe-to-remove decisions.
- Precise process-to-file read/write attribution.
- Continuous process monitoring.
- Endpoint Security and system extensions.
- Privileged helpers.
- Network destinations and per-process network attribution.
- Process arguments except a separately consented diagnostic mode.
- Active-window and user-interaction history.
- Other users' private data.
- File-content inspection.
- Causal incident claims.
- Automatic trust or malware judgments.
- Background collection until manual scans prove value and acceptable overhead.

## Final recommendation

Complete the focused Phase A preparation, then wire real data immediately
through the manually refreshed application/process atlas.

Do not wait for every future persistence or SQLite concern to be solved, but do
not push real values into the current display-string model. First make
provenance, time, freshness, capability, identity, lifecycle, and uncertainty
representable. Then ship the smallest useful read-only collector slice while
keeping deterministic synthetic mode unchanged.
