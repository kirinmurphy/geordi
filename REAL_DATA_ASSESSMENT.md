# Real Machine Data Assessment

## Decision

HAL should take a hybrid approach:

1. Complete a focused domain and collection-boundary preparation.
2. Immediately follow it with a narrow, manually refreshed, read-only application
   and process atlas.
3. Preserve synthetic fixtures as a first-class mode for tests, demonstrations,
   product evaluation, and failure simulation.

HAL is ready to begin real observation, but the current Phase 0 Swift model is
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
- `Sources/HALDomain/Entity.swift` currently stores all domain-specific
  properties as `Detail(label, value)` strings.
- `Sources/HALDomain/Relationship.swift` preserves direction, confidence, and
  observed-versus-inferred evidence, but not observation timestamps, source
  identity, raw references, or resolver versions.
- `Sources/HALDomain/SystemGraph.swift` is a fixture-shaped current graph without
  scan or freshness context.
- `Sources/HALFixtures/FamiliarMac.swift` and
  `Sources/HALFixtures/FixtureCatalog.swift` contain all current values,
  explanations, incidents, and relationships as authored fixture data.
- `Sources/HALApp/HALApp.swift` initializes the app directly from
  `FixtureCatalog`.
- `Tests/HALFixturesTests/FixtureTests.swift` verifies fictional labeling,
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

## Classification legend

- **Directly observable**: a current platform fact available from an API,
  filesystem record, system database, or read-only command.
- **Deterministically derived**: reproducible from specified observations and a
  versioned rule without judgment.
- **Heuristically inferred**: plausible correlation that must preserve
  uncertainty and supporting evidence.
- **Requires historical collection**: unavailable from a single current
  snapshot.
- **Requires elevated permission or user consent**: gated by TCC, entitlements,
  privilege, sensitive-data policy, or explicit product consent.
- **Not realistically available**: cannot be complete or reliably established
  on an arbitrary Mac.
- **Currently hardcoded/demo-only**: authored in Phase 0 fixtures or UI.

## Field-by-field matrix

### Applications and installed software

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Bundle path and existence | Directly observable | `FileManager` enumeration of standard system, shared, and user application directories; Spotlight as supplemental discovery | User locations can be unavailable. Spotlight and `system_profiler` should not be canonical identity sources. |
| Name, icon, bundle identifier, version, build, executable | Directly observable | `Bundle`, `Info.plist`, `NSWorkspace` | Metadata can be absent, malformed, localized, or duplicated. |
| Logical and allocated bundle size | Deterministically derived | `URLResourceValues` and bounded filesystem traversal | Potentially expensive; APFS clones, sparse files, compression, and hard links require explicit size semantics. |
| Installed now | Directly observable | Successful current enumeration within a declared scope | Absence outside a complete scope does not mean removed. |
| Removed, new, or updated | Requires historical collection; deterministically derived | Compare durable identities and versions across completed scans | Requires scan completeness and history. |
| Running or stopped | Deterministically derived | Correlate process executable/bundle paths with current inventory | Point-in-time only; must carry an observation time. |
| Signing identifier, Team ID, authorities, signature validity | Directly observable | Security framework: `SecStaticCode`, `SecStaticCodeCheckValidity`, `SecCodeCopySigningInformation` | Signature identity is not user trust, application ownership, or safety. |
| Apple/system classification | Deterministically derived | Platform signature plus protected system location and metadata | Preserve the component facts; path alone is insufficient. |
| App Store provenance | Directly observable or deterministically derived | App receipt and bundle metadata | Receipt may be missing or invalid; do not retain account-related content. |
| Installer-package provenance | Directly observable or heuristically inferred | Installer receipts, package metadata, BOM records, `pkgutil` adapter | Package-to-app mapping can be ambiguous. |
| Homebrew provenance | Directly observable or deterministically derived | Homebrew JSON output and Caskroom/Cellar metadata | Multiple prefixes and versions are possible; prevent automatic updates. |
| Web download or disk-image provenance | Heuristically inferred; sometimes directly observable | Quarantine extended attributes and download-origin metadata | Frequently missing after copy, move, or metadata stripping. |
| User approval and trust | Not realistically available as observation | HAL decision history | Never infer from source, signature, or Gatekeeper status. |
| Current fixture footprint, source, state, and summaries | Currently hardcoded/demo-only | Fixture literals | Retain for demonstrations only. |

### Processes and runtime activity

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| PID, PPID, UID, executable path, start time | Directly observable | `libproc` and `sysctl` where needed | Processes can disappear during collection; PID alone is not identity. |
| Process name and current bundle association | Directly observable or deterministically derived | `libproc`, `NSRunningApplication`, executable-to-containing-bundle resolution | `NSWorkspace.runningApplications` does not cover every helper or non-GUI process. |
| Current parent/child relationship | Directly observable | PPID in a process snapshot | Parent may have exited; PID reuse must be handled. |
| Historical launch ancestry | Requires historical collection | Process event collection or sufficiently frequent snapshots | Snapshots miss short-lived processes. |
| CPU and memory now | Directly observable or deterministically derived | `proc_pid_rusage`, Mach host/task/process APIs | CPU requires a measurement interval; detailed records may be restricted. |
| Arguments | Directly observable where accessible; requires consent | Process APIs with strict filtering | Sensitive and incomplete. Disabled by default under `PRIVACY.md`. |
| Executable hash | Deterministically derived | Streaming CryptoKit hash | I/O cost; changes normally after updates and is not durable identity. |
| Every start and exit | Requires historical collection and elevated capability | Endpoint Security only if later justified | Do not require this for the initial atlas. |
| Current fixture processes and resource values | Currently hardcoded/demo-only | Fixture literals | Not measurements. |

### Login items, agents, daemons, helpers, and persistence

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| LaunchAgent or LaunchDaemon plist and declared fields | Directly observable | Property lists in user/system launch directories and embedded bundle locations | Parse malformed data safely; arguments can be sensitive. |
| Label, program, arguments, triggers, `KeepAlive` | Directly observable | Property list | Declaration is not current runtime state. |
| Enabled or approved status | Directly observable where supported; otherwise incomplete | `SMAppService` status and legacy status API; versioned `launchctl` adapter if needed | Service Management is not a universal enumerator for every third-party item. |
| Loaded and running state | Directly observable | Launchd domain inspection plus process correlation | Loaded, approved, scheduled, and running are different states. |
| Embedded login items, XPC services, and helpers | Directly observable | Bundle `Contents/Library` and helper directories | Containment supports association but not exclusive ownership. |
| Privileged helpers | Directly observable; sometimes permission-limited | `/Library/PrivilegedHelperTools`, launchd declarations, signatures | Complete state may be restricted. |
| Persists through | Directly observable or deterministically derived | Explicit persistence declaration naming an executable | App association can remain inferred. |
| Orphaned persistence | Requires historical collection; heuristically inferred | Complete previous app inventory plus current persistence | Missing app evidence is not automatically proof of orphaning. |
| Current fixture persistence explanations | Currently hardcoded/demo-only | Fixture relationships | Retain as narrative coverage. |

### Files, application data, caches, logs, configuration, and documents

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Path, type, permissions, owner, timestamps, flags, extended attributes | Directly observable | `FileManager`, `stat`/`lstat`, `getxattr`, `URLResourceValues` | TCC and Full Disk Access can block locations. Never follow symlinks silently. |
| Logical, allocated, and aggregate size | Directly observable or deterministically derived | Resource values and bounded traversal | Potentially expensive and affected by APFS semantics. |
| Cache, log, configuration, or support category | Deterministically derived or heuristically inferred | Known roots and versioned path rules | Arbitrary names are weak evidence. |
| User document or project classification | Heuristically inferred; sometimes directly observable by selected scope | User-selected roots, declared document types, conventional directories | File contents should not be inspected for ordinary classification. |
| Last modified | Directly observable | Filesystem metadata | Not the same as last used. |
| Recently used or stale | Requires historical collection; heuristically inferred | HAL observation history plus weak filesystem evidence | Access time is often unreliable. |
| Reads or writes relationship | Requires historical collection; often elevated | FSEvents for coarse changes; Endpoint Security for later high-fidelity attribution | FSEvents does not reliably identify the writing process. |
| Exact ownership | Deterministically derived for containment and authoritative package paths; otherwise inferred | Bundle containment, receipts, containers, bundle-ID conventions, historical writers | Shared support and documents often have multiple consumers. |
| Application footprint | Deterministically derived over qualified relationships, but incomplete | Sum explicitly associated items with deduplication rules | Present as “observed associated footprint,” not complete ownership. |
| Current fixture sizes, rebuildability, protection, and removal text | Currently hardcoded/demo-only | Fixture literals | These are demo findings, not machine facts. |

### Package managers, packages, and shell frameworks

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Homebrew prefixes, Cellar, Caskroom, cache | Directly observable or deterministically derived | Known roots and read-only Homebrew commands | Multiple installations and architectures are possible. |
| Installed formulae, casks, versions, dependencies | Directly observable | Homebrew JSON and metadata | Adapter must be versioned and time-bounded. |
| npm global packages | Directly observable | `npm root -g`, `npm ls -g --json`, package metadata | Version managers create multiple environments and roots. |
| Other ecosystems | Directly observable per manager | Manager-native read-only databases or JSON | “All packages” is not realistically complete. |
| Oh My Zsh installation, Git version, and plugins | Directly observable or deterministically derived | Framework directory, Git metadata, redacted `.zshrc` references | Shell configuration can contain secrets; do not retain full content. |
| Framework active in a shell | Heuristically inferred or requires history | Redacted configuration references; process environment only with consent | Often unavailable and sensitive. |
| Package launches or reads another package | Heuristically inferred or requires history | Executable provenance, dependency metadata, runtime observation | Install dependency does not prove runtime use. |
| Current fixture package footprints and edges | Currently hardcoded/demo-only | Fixture literals and authored relationships | Retain for deterministic UX tests. |

### CPU, memory, storage, and network resources

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Host CPU usage and load | Directly observable or deterministically derived | Mach host statistics | Percentage requires an interval. |
| Physical memory, pressure, and swap | Directly observable | Mach VM statistics and `sysctl` | A single reading does not define an incident. |
| Per-process CPU, memory, and I/O | Directly observable or deterministically derived | `libproc`, `proc_pid_rusage`, repeated samples | Permission and process-exit failures are normal. |
| Volume capacity and available space | Directly observable | Volume resource values and `statfs` | Raw free and available-for-important-usage are different. |
| Network interface totals | Directly observable or deterministically derived | Interface counters | Lower sensitivity at aggregate level. |
| Per-process destinations and sockets | Requires consent/elevated capability; incomplete | Later Network Extension or privileged inspection | Explicitly deferred by current privacy policy. |
| Baseline, peak, anomaly, and sustained pressure | Requires historical collection; derived or inferred | HAL time series and versioned rules | Requires retention, sampling intervals, gaps, and sleep handling. |
| Current activity and incident fixture values | Currently hardcoded/demo-only | Fixture/UI values | Not observations. |

### Events and incidents

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Scan start, completion, partial result, and failure | Directly observable | Collector orchestration clock and result | Must be first-class. |
| Wake and sleep | Requires historical collection | `NSWorkspace` notifications or IOKit while HAL runs | No complete retroactive history. |
| Application install, update, and removal | Requires historical collection; deterministically derived | Completed snapshot comparison; FSEvents as a trigger only | Scope and scan completeness matter. |
| Process start and exit | Requires historical collection | Snapshot observation initially; Endpoint Security later if justified | Say “first observed” when exact start was not seen. |
| File change and growth | Requires historical collection; deterministically derived | Size snapshots; FSEvents for rescan scheduling | Event streams can coalesce or drop events. |
| Incident start, duration, and peak | Requires historical collection; deterministically derived | Versioned threshold state machine | Threshold and rule version are evidence. |
| Contributing process ranking | Deterministically derived but incomplete | Time-aligned resource samples | Describe as largest observed contributor, not cause. |
| Occurred near | Deterministically derived from history | Versioned time-window rule | Temporal proximity does not imply causation. |
| Caused incident | Not realistically available in general | None | HAL should report correlation and possible triggers only. |
| Current events, incidents, times, and durations | Currently hardcoded/demo-only | Fixture literals | Useful scenario coverage, not history. |

### Signing, receipts, provenance, ownership, evidence, and confidence

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Static signature and Team ID | Directly observable | Security framework | Validate before relying on signature information. |
| Package receipt and claimed paths | Directly observable | Installer receipt database, BOM data, package adapter | Receipts can be stale or incomplete. |
| Download origin | Directly observable when retained; otherwise unavailable | Quarantine metadata | Not durable. |
| Durable application identity | Deterministically derived from multiple facts | Bundle ID, Team ID, path, receipt, optional version, hash for exact comparison | No single field is sufficient in every case. |
| Exclusive ownership | Not realistically available for arbitrary external files | Authoritative containment/receipt where possible | Otherwise preserve association and ambiguity. |
| Evidence | Directly observable or derived | Immutable observation references | Needs source, time, schema, quality, and redaction metadata. |
| Confidence | Deterministically computed or heuristically assigned | Versioned resolver over evidence | Must not be synonymous with observed versus inferred. |
| Current evidence summaries and confidence | Currently hardcoded/demo-only | Fixture relationships | Current tests verify presentation honesty, not real resolution quality. |

### Relationship matrix

| Relationship | Classification | Required interpretation |
|---|---|---|
| `owns` | Direct or deterministic only for authoritative containment; otherwise inferred | Prefer narrower assertions such as contains, installed path, or associated with. |
| `launches` | Direct when parent/exec was observed; otherwise historical or inferred | A declared helper means can launch, not observed launch. |
| `reads/writes` | Requires history; often elevated | Precise runtime attribution should be deferred. |
| `persists through` | Directly observable or deterministic | Keep persistence declaration separate from app ownership. |
| `consumes` | Directly observable or deterministic | Always interval-specific. |
| `contributes to` | Deterministic or inferred | Arithmetic storage contribution differs from incident correlation. |
| `occurred near` | Deterministically derived from historical timestamps | Never imply cause. |
| `may belong to` | Heuristically inferred | Preserve competing candidates and evidence. |
| `shares` | Deterministic with authoritative multiple references; otherwise inferred | Default shared or ambiguous targets to protected. |

### Reclaimability and safe-action decisions

| Concept or field | Classification | Constraints |
|---|---|---|
| Item size | Directly observable or deterministic | Does not imply reclaimability. |
| Rebuildable or redownloadable | Deterministic for manager-native caches; otherwise inferred | Requires detector-specific versioned rules. |
| User or shared data | Direct in limited authoritative locations; otherwise inferred | Uncertain data defaults to protected. |
| Current use | Direct at scan time; recent use requires history | Must show observation age. |
| Expected reclaimed bytes | Deterministically derived but approximate | Allocated size, clones, hard links, and concurrent changes matter. |
| Keep, review, removable, protected | Derived finding or policy decision | Never collector output. |
| Safe to remove | Not realistically available as an unconditional fact | Depends on intent, use, backup, sharing, app semantics, and fresh validation. |
| Cleanup | Explicitly deferred | No delete, trash, uninstall, or mutation in initial real-data phases. |
| Current reclaim totals and explanations | Currently hardcoded/demo-only | Retain only as fixture findings. |

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

Exit criterion: HAL explains representative real applications, including one
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
- Adaptive sampling only after HAL's own overhead is measured.

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
