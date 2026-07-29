# Real Data and Profile Refactor Backlog

This is the persistent implementation checklist for replacing Phase 0's
code-defined fixtures with schema-validated profiles and adding explicit real
Mac linking. Architectural rationale lives in `REAL_DATA_ASSESSMENT.md`;
field availability lives in `REAL_DATA_FIELD_MATRIX.md`.

Status: implementation history and deferred engineering backlog. It is no
longer the source of truth for the immediate product priority.

Current user-facing work: `NEXT_PRODUCT_VALIDATION_PLAN.md`
Completed implementation index: `COMPLETED_PHASES.md`
Deferred work: `FUTURE_PHASE_PLANS.md`

## Historical test-drive stabilization

These items were recorded from the first linked-Mac product test on
2026-07-27. Complete them before expanding collection breadth.

### Relational relevance and progressive disclosure

- [x] Treat the primary graph as a curated explanation of important current
  relationships, not a complete inventory visualization.
- [x] Add a schema-validated display-policy manifest with per-context node
  budgets, relationship priorities, confidence floors, and grouping rules.
  Presentation thresholds must not become Swift literals.
- [x] Prioritize relationships that answer:
  **What is active? Why is it active? What data is meaningfully associated?
  What changed or deserves attention?**
- [x] Keep observed facts even when they are omitted from the primary graph.
  Filtering presentation must never discard collector output or evidence.
- [ ] Put complete signing, provenance, entitlement, component, and path
  metadata behind an accessible **Technical details** disclosure.
- [x] Summarize repetitive relationships as groups such as “5 support
  locations” or “8 helper components,” expanding them only on request.
- [x] Surface low-confidence or unmatched records when they affect the
  explanation, but avoid scattering ordinary uncertain candidates across the
  default map.
- [x] Never rank an application as noteworthy without an observed signal.
  Installation alone is not a warning, and a large component count is not a
  problem.
- [ ] Keep “actionable” read-only for this milestone: provide a clear next
  investigation or explanation, not cleanup, termination, disabling, or other
  machine-changing controls.

#### Collector order under this policy

1. [x] Point-in-time processes and deterministic application resolution:
   explain what is running now, helper/parent relationships, unmatched
   processes, memory, and observation limitations.
2. [x] Persistence declarations and application correlation:
   explain why something starts automatically or remains active.
3. [x] Associated-location relevance:
   promote strong containers and meaningful support/configuration locations;
   group ordinary cache/log candidates and hide weak absent candidates.
4. [ ] Resource sampling and incident qualification:
   identify observed outliers only after sampling semantics and overhead are
   tested.
5. [ ] Installer-package and Homebrew provenance:
   explain how software arrived and connect external helpers when evidence is
   useful.
6. [ ] Embedded component inventory:
   collect helpers, XPC services, login items, plug-ins, and frameworks, but
   promote only components that are running, persistent, separately signed, or
   otherwise explanatory.
7. [ ] Entitlements and declared capabilities:
   use them to resolve containers and explain specific relationships; keep the
   complete entitlement list in technical details.

### Initial linking flow

- [x] Replace the banner-only `Linking…` state with a focused setup overlay
  that explains HAL is performing read-only collection.
- [x] Disable controls whose meaning depends on the selected data source while
  the initial link is unresolved.
- [x] Keep unlink, destructive reset, and ordinary refresh unavailable during
  initial linking.
- [x] Offer **Cancel and keep exploring the fictional Mac**, not **Undo**:
  linked mode is not persisted until collection succeeds, so there is no
  committed change to undo.
- [x] Make initial collection cooperatively cancellable and ignore late results
  from a cancelled link.
- [x] Show a compact stage indicator:
  **Connect → Observe applications → Build your atlas → Ready**.
- [x] Describe which facts are being read and reiterate that no applications or
  machine data are changed.
- [x] On success, land on a clear completion state with a primary
  **Explore installed applications** action.
- [x] On failure, remain synthetic and show a retryable, field-path-aware or
  collector-aware explanation.

### Linked completion and refresh

- [x] Replace the green “Read-only application inventory” notification with a
  completion/coverage panel that answers:
  what finished, what HAL learned, what remains unavailable, and what the user
  can explore next.
- [x] Remove **Refresh Now** as the primary post-link action. It is not the next
  step in setup and currently suggests that missing capabilities will be
  collected.
- [x] Rename manual refresh to **Check this Mac again** and explain that it
  reruns the same enabled read-only collectors.
- [x] Keep an existing linked snapshot interactive during manual refresh; use
  inline progress rather than a blocking overlay.
- [x] Show an explicit completion acknowledgement even when refreshed data is
  unchanged, including “Checked just now,” duration, and collector coverage.
- [x] Show whether a refresh changed the displayed snapshot.
- [x] Add model tests for initial-link progress, cancellation, successful
  handoff, unchanged refresh, changed refresh, retry, and refresh failure with
  retained data.
- [ ] Add native UI automation for the same link and refresh state transitions
  once the interaction runner extends beyond packaging verification.

### Useful application scope

- [x] Default the linked application list to **User Installed**, with visible
  options for bundled software, system utilities, unclassified records, and
  all applications.
- [x] Define the classification through a versioned manifest using multiple
  evidence fields such as protected system location and platform signature;
  the initial location rules are now manifest-driven, but platform-signature
  evidence still needs to be incorporated.
- [x] Label uncertain cases honestly. Folder location alone does not become an
  assertion about who installed an application, and unmatched locations have
  an explicit **Other / Unclassified** category.
- [x] Add counts for visible, hidden-by-scope, and uncertain applications.
- [x] Show the visible and total application counts beside the scope filter.
- [x] Preserve global search access to applications hidden by the homepage
  scope filter.
- [ ] Later add a separate **Noteworthy activity** section only after process,
  storage, or incident observations exist; do not rank applications using
  synthetic or unsupported metrics in live mode.

### Evidence and navigation discoverability

- [x] Surface a compact signing and provenance summary on each selected
  application before the technical detail grid.
- [x] Explain unavailable provenance as an evidence state rather than silently
  presenting repeated “Not retained” rows.
- [x] Show collector coverage and evidence counts in the application list or
  application header so users can tell that signing/provenance collection ran.
- [x] Add direct **Return to fictional Mac…** navigation beside the linked-data
  status. Do not hide the only return path inside an unlabeled ellipsis menu.
- [x] Keep the existing backup/delete/cancel confirmation after that action;
  returning to the fictional profile still unlinks the live data source.
- [x] Rename technical **Unlink this Mac** copy in user-facing navigation when
  the user’s goal is to return to the demo, while retaining “unlink” in the
  confirmation explanation.

### First useful live relationships: application-associated files

- [x] Add a bounded, read-only associated-file collector before expanding to
  broad storage scanning.
- [x] Select conventional candidate locations and match strategies through
  versioned manifests rather than Swift path arrays. Initial candidates should
  cover application support, caches, preferences, logs, saved state, sandbox
  containers, HTTP storage, and WebKit data.
- [x] Add group-container candidates only after team/group identifiers are
  collected; bundle identifiers alone are not sufficient to claim a match.
- [x] Match exact bundle identifiers and authoritative bundle/container
  metadata first. Treat normalized application-name/path matches as weaker
  evidence.
- [x] Create file/location entities for observed candidates and connect them to
  applications with evidence-bearing confidence. Use **may belong to** for
  convention or name matches; do not claim runtime reads/writes without file
  activity observations.
- [x] Preserve permission-denied paths, unreadable metadata, absent candidates,
  and applications with no discovered associations in collector output.
- [x] Add bounded root enumeration to preserve unmatched locations and
  shared/group-container ambiguity without turning the collector into a broad
  home-directory scan.
- [x] Collect metadata only in the first pass. Do not read file contents or
  calculate recursive directory sizes until bounded traversal, cancellation,
  privacy, and performance tests exist.
- [x] Project observed file associations into the same live relationship map
  and inspector used by synthetic profiles.
- [x] Add deterministic tests for exact bundle-ID, weaker name, absent,
  permission-denied, unreadable, and unsafe-path states.
- [x] Add shared, unmatched, and group-container association fixtures when
  bounded root enumeration is implemented.

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
- [x] Define rebuildable-data detector manifests, including locations,
  classification, exclusions, and evidence rules.
- [x] Wire rebuildable-data detectors into metadata-only linked-Mac collection
  without descendant enumeration, size calculation, or deletion.
- [x] Replace synthetic storage, application, and incident claims in linked
  atlas destinations with summaries of the observations actually collected.
- [x] Define a versioned bounded size-measurement contract covering entry,
  depth, duration, and cancellation budgets; filesystem and symlink boundaries;
  hard-link deduplication; and APFS clone disclosure.
- [x] Keep nonconfigurable security invariants in code.

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
- [x] Add schema fixtures for partial, unavailable, permission-denied,
  ambiguous, stale, and negative states.
- [x] Add a deterministic fixture-generation/export format based on the same
  schema.
- [x] Remove entity-instance switches and hardcoded entity presentation behavior
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
- [x] Add point-in-time process collection.
- [x] Add deterministic process-to-application resolution.
- [x] Preserve unmatched and inaccessible process records.
- [x] Add explicit manual refresh.
- [x] Add redacted diagnostic export.

## Priority 5: history, storage, and incidents

- [ ] Add SQLite only after the normalized profile and observation schema settle.
- [ ] Store immutable scans, collector runs, observations, evidence, findings,
  decisions, and retention state.
- [ ] Load storage-detector resources from manifests.
- [ ] Add bounded read-only size observation and growth history.
- [ ] Keep reclaimability as a versioned finding, not collector output.
- [ ] Add resource time series and incidents only after sampling overhead and
  retention semantics are tested.

## Deferred next engineering step

Do not begin the bounded measurement engine yet. Complete the Application Story
and Guided Proof product-validation phase first. Reconsider measurement only if
evaluation shows that observed size is necessary to prove the reclaimable-data
experience.
