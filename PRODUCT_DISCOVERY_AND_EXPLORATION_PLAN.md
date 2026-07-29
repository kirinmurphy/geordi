# HAL Product Discovery and Exploration Plan

Status: Completed phases 1–5; retained as the authoritative historical specification
Scope: Homepage organization, actionable paths, glossary, map usability,
collection health, command-line software, and filesystem exploration  
Implementation rule: Preserve HAL's manifest-driven composition, central schema,
synthetic/live parity, and read-only-by-default collection model.

## 1. Purpose

HAL currently proves that collected system facts can be represented as entities
and evidence-bearing relationships. The next product step is to turn that atlas
into a clear explanation and a useful jumping-off point.

This plan addresses two related goals:

1. Make the current inventory and monitoring experience understandable,
   actionable, and quiet by default.
2. Add a complementary filesystem-oriented view that explains where observed
   entities live without pretending HAL has indexed the entire filesystem.

The guiding principle is:

> HAL should first show what matters, explain why it matters, and provide a safe
> path to investigate further. Raw collector output remains available, but it
> should not define the primary user experience.

## 2. Product model

The homepage currently mixes several kinds of information:

- relatively stable inventory, such as applications, package managers, and
  installed packages;
- capabilities, such as interpreters, runtimes, SDKs, and toolchains;
- changing observations, such as processes and rebuildable caches;
- collection-health and setup messaging;
- low-level evidence and diagnostics.

These should not have equal visual weight.

### 2.1 Proposed information hierarchy

1. **Attention and recent change**
   - actionable collection failures;
   - reclaimable or growing data;
   - newly installed, removed, or changed software once history exists.
2. **Installed software**
   - applications;
   - package managers;
   - installed packages.
3. **Developer capabilities**
   - execution runtimes and interpreters;
   - compilers, SDKs, and toolchains;
   - capability classifications backed by explicit evidence.
4. **Explore**
   - relationship atlas;
   - filesystem map;
   - raw/unclassified command-line inventory.
5. **Status and diagnostics**
   - last successful observation;
   - collector coverage;
   - non-actionable warnings;
   - redacted diagnostic export.

This hierarchy separates “what is installed” from “what changed or needs
attention” and from “how HAL gathered the information.”

## 3. Homepage and Reclaimable Manager Data

### 3.1 Current behavior

`OverviewView` in `Sources/HALApp/ContentView.swift` builds homepage sections
directly from graph entities. Rebuildable roots are file entities connected to
package-manager entities with `owns` relationships. The row title currently
comes from the final path component. Manager provenance is placed in the
subtitle by `managerSummary(for:)`.

For the observed paths in the bundled detector manifest, this can produce names
that are too similar to their manager names and fails to make the cache/data
identity obvious.

### 3.2 Proposed terminology

Use explicit artifact names:

- `.npm cache`
- `Homebrew cache`

The entity remains a file/data entity. “Managed by npm” or “Managed by
Homebrew” remains provenance, not the title.

Names should come from the versioned rebuildable-data detector manifest, not
from Swift conditionals or path-specific code. Extend each detector location
with a required or optional `displayName`, validate it centrally, and project
that value into the entity.

### 3.3 Proposed placement and visual treatment

Rename the section to **Reclaimable Data**. Add the explanation:

> Caches and generated files that their owning tools can recreate.

Keep the current section order for the initial implementation. Do not move
Reclaimable Data to the top yet.

In a later iteration, consider moving the section near the top only when it has
meaningful dynamic information:

- a measured size;
- growth since the previous scan;
- a threshold finding;
- a new or materially changed candidate.

Until size/history collection exists, keep it below inventory and describe it
as “known rebuildable locations”; do not imply urgency without measurements.

Use a subtly tinted section container to distinguish observations/reporting
from inventory. The tint must supplement, not replace, text and icon semantics
for accessibility. Avoid making every row green, which could imply “safe to
delete now.”

### 3.4 Safe-action boundary

No deletion action is authorized by this plan. Reclaim actions require:

- measured scope;
- ownership and rebuildability evidence;
- target revalidation immediately before action;
- recoverable Trash behavior where possible;
- a preview;
- safety tests.

## 4. Runtimes and developer tools

### 4.1 Current behavior and limitation

`RuntimeCollector` uses `runtimes.json` as a known-capability probe catalog.
Node.js, Python, Java, and Go are present because they are declared there.
Executable presence and version responses are real observations. The coverage
is not open-ended.

`CommandLineSoftwareCollector` now enumerates configured executable directories
without running unknown binaries. This is open-ended inventory, but not
open-ended semantic classification. The latest observed graph has 1,159
entities, demonstrating that exposing every command as a homepage row is noisy.

### 4.2 Proposed model

Keep two separate concepts:

1. **Observed command-line software**
   - executable path;
   - resolved path;
   - aliases;
   - package or system ownership where derivable;
   - no claim about capability.
2. **Derived capabilities**
   - interpreter/runtime;
   - compiler;
   - SDK;
   - toolchain;
   - package manager;
   - classification rule and evidence.

Known definitions enrich inventory; they must not gate inclusion.

### 4.3 Capability discovery

Evolve `runtimes.json` into a more general, versioned capability-definition
manifest. Each definition should contain:

- stable capability identifier;
- human-readable label;
- capability kind;
- package identities;
- safe executable/path probes;
- optional bounded version probe;
- classification rule identifier and version;
- concise explanation;
- confidence requirements.

Examples:

- `node` executable plus successful bounded version probe → JavaScript runtime;
- `python3` executable plus successful bounded version probe → Python
  interpreter;
- `java` executable → JVM capability;
- `javac` executable → Java compiler capability;
- `go` executable plus Go SDK/compiler evidence → Go toolchain;
- `php` executable plus safe version probe → PHP interpreter.

Do not execute arbitrary newly discovered binaries. Only manifest-declared,
security-reviewed probes may run.

### 4.4 User experience

Use three levels:

- **Developer capabilities**: evidence-backed, classified items.
- **Installed packages**: packages with package-manager ownership.
- **Other command-line software**: aggregated exploration surface, not a
  thousand-row homepage section.

The “Other” surface should offer search, filters, grouping, and useful context:

- source: macOS, Homebrew, local, user-local;
- owning package;
- aliases;
- path;
- classified/unclassified;
- active/inactive when process evidence exists.

System commands should be grouped behind a single “macOS system commands”
summary by default, with search available inside the group. They are generally
not independently removable and have little value as hundreds of peer rows.

Prioritize user-relevant command-line software:

- user-local executables;
- commands owned by Homebrew or another package manager;
- downloaded or otherwise provenance-bearing executables;
- currently active commands;
- commands with a derived developer capability;
- commands that changed since the previous observation.

Homebrew commands should normally be reached from their owning package rather
than duplicated as peer rows.

Interacting with a command-line item should answer:

- What package or system source owns it?
- Where is it?
- Is it currently active?
- What capability, if any, did HAL derive?
- What aliases resolve to the same executable?
- How would the owning package manager describe or remove it?

HAL may display or copy a package-manager removal command after validating the
ownership relationship. This phase must not execute removal commands.

## 5. Paths as actions

### 5.1 Use cases

From any path shown by HAL, a user should be able to:

- reveal the item in Finder;
- open a new Terminal window at the folder or containing folder;
- copy the exact path;
- understand what the path represents;
- move from the entity atlas to the filesystem map at that location.

### 5.2 Proposed interaction

Replace plain path strings with a reusable `PathActionMenu`:

- primary label: shortened but unambiguous path;
- full path available through selection and accessibility;
- menu actions:
  1. Copy Path
  2. Reveal in Finder
  3. Open in Terminal

For a file, Terminal opens its containing folder. For a directory, Terminal
opens that directory.

Every path click opens this options menu. “Show in Filesystem Map” may be added
after the filesystem prototype has a stable navigation contract.

The menu should identify the terminal target when known, for example “Open in
Ghostty.” If HAL cannot identify a suitable terminal, use “Open in Terminal…”
and allow the user to choose.

### 5.2.1 Terminal selection policy

HAL should support terminal applications through versioned terminal adapters,
not one hardcoded application.

When the user opens the path menu:

1. Find running applications that match validated terminal adapters.
2. If one is running, use it.
3. If several are running, prefer the terminal most recently activated while
   HAL has been running.
4. Show a chooser or submenu so the user can override that selection.
5. If none is running, use the user's saved terminal preference.
6. If there is no preference, present a chooser and remember the selection only
   with the user's consent.

HAL can track activation through
`NSWorkspace.didActivateApplicationNotification`. It should not request
Accessibility permission or inspect terminal windows merely to guess which
terminal is preferred.

The terminal-adapter manifest defines bundle identity, display name, and the
supported open-directory strategy. Executable behavior and target validation
remain in Swift.

### 5.3 Implementation

Create generic path semantics rather than matching labels such as `"Path"`:

- add typed detail presentation metadata or a typed `EntityAction`;
- represent action kind, target, availability, and provenance in the canonical
  schema;
- keep user-local absolute paths out of ordinary manifests;
- validate the target at action time;
- use `NSWorkspace` for Finder;
- use a bounded macOS Terminal integration for Terminal;
- use `NSPasteboard` for copy.

Security invariants remain in Swift. Manifests may select presentation and
known-safe action adapters but cannot enable arbitrary command execution.

### 5.4 Inspector organization

Replace the current flat detail grid with groups:

- Identity
- Installation and ownership
- Location
- Current observation
- Resource use
- Provenance and evidence
- Technical details

Grouping rules belong in a versioned display-profile manifest. Unknown details
fall into Technical details and are never silently dropped.

## 6. Every node as a jumping-off point

Each entity detail view should provide a small **Explore further** section. The
available actions depend on evidence:

- reveal/open/copy a path;
- open owning package manager;
- open related application;
- view active process instances;
- show upstream/downstream relationships;
- show in filesystem map;
- show raw observation/evidence;
- open an appropriate system preference or management UI only when a safe,
  explicit adapter exists.

Actions must be derived from graph relationships, typed details, and validated
adapters. Do not hardcode product instances in Swift.

An entity with no external action should still offer graph and evidence
navigation. HAL should not manufacture a path or action merely to fill the
section.

## 7. Glossary and contextual terminology

### 7.1 Goal

Explain technical terms in context without turning every screen into
documentation.

Initial terms should include:

- Shared attributes
- Observed instance
- PID
- Parent PID
- Resident memory / Memory at observation
- Package manager
- Runtime
- Toolchain
- Rebuildable
- Persistence / Startup declaration
- Observed, derived, inferred, and user-decided evidence

### 7.2 Manifest

Add `glossary.json` and `glossary.schema.json` with:

- schema version;
- stable term ID;
- display term;
- concise description;
- optional longer explanation;
- aliases/detail-label matches;
- optional “learn more” reference ID;
- applicability/context.

Reject duplicate IDs, aliases, and unknown keys.

### 7.3 Widget

Create a reusable SwiftUI `GlossaryTermToggle`:

- visually subtle affordance on recognized labels;
- delayed hover presentation, default 700 ms;
- cancel pending presentation if hover ends before the threshold;
- immediate presentation on click or keyboard activation;
- popover containing term and concise description;
- accessibility label, hint, and keyboard focus;
- selectable text inside the explanation;
- only one glossary popover active at a time.

The hover delay should be centralized as presentation configuration rather than
copied into each view.

Wire the initial terms into inspector detail labels, instance-table headers,
relationship vocabulary, and section headings. Matching should use stable term
IDs or configured aliases, not fuzzy runtime string guessing.

## 8. Zoom, text size, and text selection

### 8.1 Current behavior

`RelationshipCanvas` includes:

- zoom buttons;
- `MagnifyGesture`;
- scroll-wheel capture;
- a canvas-wide `DragGesture`;
- fit-to-graph behavior.

The map's drag gesture and button/node gestures can compete with selection and
ordinary text interaction. Map node text is rendered inside buttons and is not
selectable. Inspector values are selectable, but banners and many summary
strings are not.

The linked banner uses caption text for collection coverage, which is too small
for information currently given persistent prominence.

### 8.2 Plan

- Add explicit zoom percentage and disabled states at min/max.
- Add tests for plus, minus, pinch, and Command-plus/minus keyboard shortcuts.
- Verify scroll-wheel zoom behavior and preserve the pointer-relative focal
  point.
- Avoid resetting zoom on unrelated state changes.
- Increase node and banner typography; respect Dynamic Type.
- Make informational text selectable where selection does not conflict with
  map gestures.
- Provide copy actions for node names, paths, values, and diagnostics.
- Keep map labels optimized for navigation; detailed copying belongs primarily
  in the inspector.

## 9. Link banner and collection health

### 9.1 Current behavior

`LiveCoverageNotice` always shows a large linked-state card with:

- setup explanation;
- collector completion count;
- limited count;
- application evidence fact count;
- unresolved process counts;
- grouped collection issues;
- refresh and export controls.

Before the parser correction, a saved snapshot had 13 collectors with twelve
complete. The limited collector was `persistence-declarations`, caused by two
Dropbox launch-agent property lists:

- `com.dropbox.dropboxmacupdate.agent.plist`
- `com.dropbox.dropboxmacupdate.xpcservice.plist`

Both were valid empty plist dictionaries. HAL had parsed them but incorrectly
treated the absence of launchd fields as a decode failure. Collector version 2
now records them as informational placeholders without limiting collection.
This historical example demonstrates why non-actionable parser diagnostics
should not be presented as Mac health warnings.

### 9.2 Proposed lifecycle

Use three states:

1. **Completion card** after initial linking
   - punchy success message;
   - one-sentence next step;
   - concise read-only reassurance behind “More info”;
   - clear “Explore installed software” action;
   - retains Check This Mac Again and Export Redacted Diagnostics;
   - includes a future Observation History link;
   - dismissible;
   - dismissal persisted as a user preference.
2. **Compact footer status** on later launches
   - last checked time;
   - refresh action;
   - health indicator only when attention is warranted;
   - click opens an upward-expanding status panel.
3. **Collection Health sheet**
   - one row per collector;
   - collected scope;
   - state and availability;
   - issue count;
   - plain-language impact;
   - recommended action, if any;
   - raw diagnostic detail behind disclosure.

The footer panel should explain each incomplete observation in user language,
state whether the user can do anything, and offer any applicable action.

Remove the application evidence-fact count from the persistent homepage. It is
diagnostic/provenance metadata, not a user goal.

In this document, a **collector limitation** means HAL observed a source but
could not completely interpret or access it. It does not automatically mean
the Mac or the observed software is malfunctioning. Examples include:

- a startup property list whose structure HAL does not yet parse;
- a protected location HAL cannot read;
- a configured root that exceeds a bounded observation budget;
- a platform capability unavailable on this macOS version.

The UI should avoid exposing “collector limitation” without an explanation.
Prefer a concrete sentence such as “HAL could not interpret two Dropbox startup
files.”

### 9.2.1 Completion-card content

Recommended hierarchy:

**Success:** “This Mac is linked”

**Next step:** “HAL found your installed software and built a read-only map.
Start exploring, or check the observation details.”

Primary action:

- Explore installed software

Secondary actions and links:

- Check This Mac Again
- Export Redacted Diagnostics…
- More Info
- Observation History (introduced by the deferred history phase)

“More Info” contains the longer explanation of sources, collection boundaries,
and what HAL did not collect. Keep the primary card brief. Buttons already
available in the linked experience should remain available rather than being
removed during the redesign.

### 9.3 Actionability policy

Classify issues:

- **Action required**: user permission or configuration can resolve it.
- **Retry suggested**: transient collection problem.
- **HAL limitation**: parser/coverage gap; user cannot fix it.
- **Informational**: incomplete evidence with no meaningful product impact.

For the Dropbox declarations, show:

> HAL could not interpret two Dropbox startup declarations. Other startup items
> were collected normally. This is a HAL parser limitation; no Mac repair is
> required.

Non-actionable parser gaps do not need a cluster of homepage actions. Represent
them subtly:

> 2 issues logged for future updates

The disclosure or future Observation History may show technical details and
diagnostic-export controls. Only show direct actions in the primary status UI
when the user can meaningfully resolve the condition.

Do not repeatedly show this as a warning banner after acknowledgment unless the
impact changes.

### 9.4 Parser-gap dogfooding loop

HAL should turn collection gaps into privacy-preserving engineering inputs:

1. Classify the failure precisely: unreadable bytes, invalid plist, unexpected
   root type, missing required launchd field, empty placeholder, or unsupported
   value shape.
2. Record a stable reason code, collector version, and structural fingerprint.
3. Never retain arbitrary plist values or command arguments merely to diagnose
   the parser.
4. Include redacted reason counts in diagnostic export.
5. Convert each confirmed new structure into the smallest synthetic fixture
   that reproduces it.
6. Add a regression test before changing parsing behavior.
7. Prefer a generic structural rule over an application-name exception.
8. Increment the collector version when interpretation changes.

The two observed Dropbox files are valid empty plist dictionaries. They should
be classified as empty persistence placeholders, logged informationally, and
excluded from launchd declaration observations. They should not make the
persistence collector partial. A non-empty plist missing `Label` remains a
structurally incomplete declaration, while undecodable bytes remain a genuine
decode warning.

### 9.5 Deferred local observation history and parser feedback

This future phase is deliberately separated from this completed specification.
Its scope, privacy constraints, entry requirements, and acceptance criteria now
live in `FUTURE_PHASE_6_OBSERVATION_HISTORY.md`.

## 10. Filesystem map

### 10.1 Product concept

Add a second, independently entered visualization experience alongside the
entity relationship atlas:

- **Relationship Map** answers “what is connected to what?”
- **Filesystem Map** answers “where does this observed thing live?”

The initial filesystem explorer has its own top-level entry point. Do not
present it as a mode toggle inside the relationship-map explorer. The two
experiences may share models later, after their interactions have matured.

The filesystem map is a curated, sparse hierarchy. It is not a Finder
replacement and not an exhaustive disk index.

### 10.2 Initial demonstration scope

Start with a few explanatory branches:

```text
/
├── Applications
├── System
│   └── Applications
├── Library
├── Users
│   └── <current user>
│       ├── Applications
│       ├── Library
│       │   ├── Application Support
│       │   ├── Caches
│       │   └── LaunchAgents
│       └── .local
│           └── bin
├── opt
│   └── homebrew
│       ├── Cellar
│       └── bin
└── usr
    └── local
        └── bin
```

Only include branches that are:

- declared as explanatory system locations; or
- ancestors of observed entity paths.

### 10.3 Folder semantics

Each curated location definition includes:

- stable ID;
- path template;
- display label;
- concise purpose;
- scope and sensitivity;
- icon/presentation;
- expected child definitions;
- applicable entity types;
- whether direct enumeration is allowed;
- maximum enumeration depth and entry budget.

Store these in a versioned `filesystem-locations` manifest with schema
validation. User-specific observed paths remain observations, not manifest
instances.

### 10.4 Visualization and interaction

Use a spatial node visualization that preserves a readable nested-tree
structure. A restrained simulated-depth treatment may make hierarchy and
branching more legible:

- depth-aware scale, shadow, and parallax;
- clear parent-child connectors;
- branch planes or layered depth bands;
- smooth drill-in and back transitions;
- an always-visible breadcrumb to prevent disorientation.

The simulated 3D treatment must not compromise text size, hit targets,
keyboard navigation, reduced-motion support, or deterministic layout. Every
depth cue should communicate folder nesting rather than serve as decoration.

- Expand/collapse branches.
- Click a folder to see its purpose and observed contents.
- Drill into a branch without loading the entire filesystem.
- Show badges for applications, packages, persistence declarations, caches, and
  executables associated with that path.
- Select an entity badge to open the existing entity inspector.
- Defer cross-navigation and preserved selection until both explorers work
  independently. Keep stable entity and path identifiers so future integration
  remains possible.
- Offer Finder, Terminal, and Copy Path actions.
- Clearly mark “HAL has not enumerated this folder” versus “observed empty.”

### 10.5 Data model

Do not turn every ancestor folder into an ordinary software entity. Introduce a
filesystem projection model derived from:

- typed entity paths;
- curated system-location definitions;
- bounded directory observations where explicitly allowed.

The canonical profile schema may need typed locations or path references.
Schema changes require versioning, fixture migration, and parity tests.

### 10.6 Privacy and performance

- Avoid recursive home-directory indexing.
- Do not read file contents.
- Do not follow symlinks outside validated scope.
- Preserve unreadable, not-enumerated, empty, and unavailable as distinct
  states.
- Redact user names and local paths in diagnostics.
- Make all enumeration budgets manifest-declared and code-enforced.

## 11. Implementation phases

### Phase 1 — Clarity and status

1. Add detector display names for `.npm cache` and `Homebrew cache`.
2. Reorganize homepage hierarchy and rename sections.
3. Add a visually distinct Reclaimable Data container.
4. Add persisted dismissal for the link completion card.
5. Add compact linked status and Collection Health sheet.
6. Classify parser warnings by user actionability.
7. Remove evidence-fact counts from persistent homepage presentation.

Acceptance criteria:

- A user can distinguish managers from their caches.
- Every limited collector has an impact explanation.
- Non-actionable Dropbox parser gaps do not look like Mac problems.
- Link completion messaging does not permanently consume homepage space.

### Phase 2 — Actionable inspector and glossary

1. Introduce typed path/action semantics.
2. Add `PathActionMenu`.
3. Group inspector details by display-profile configuration.
4. Add Explore further actions.
5. Add glossary schema, loader, validation, and initial terms.
6. Add delayed `GlossaryTermToggle`.
7. Add accessibility and interaction tests.

Acceptance criteria:

- Every rendered filesystem path supports Copy Path.
- Valid local paths support Finder and Terminal actions.
- Initial glossary terms work by hover, click, keyboard, and VoiceOver.
- Unknown details remain visible.

### Phase 3 — Map usability

1. Diagnose and test zoom event handling.
2. Add pointer-relative zoom and keyboard controls.
3. Improve node and linked-status typography.
4. Add copy affordances without breaking canvas navigation.
5. Add automated interaction and snapshot coverage where practical.

Acceptance criteria:

- Zoom buttons, pinch, and keyboard shortcuts change scale predictably.
- Zoom state is visible.
- No primary banner uses caption-sized body copy.
- Inspector text and diagnostics are selectable/copyable.

### Phase 4 — Command-line software refinement

1. Aggregate system commands and package-owned executable aliases.
2. Add search and filters.
3. Expand capability definitions beyond the initial user examples.
4. Add package-to-capability evidence rules.
5. Suppress duplicate representations while preserving graph relationships.
6. Add actionable ownership/removal guidance without performing removal.

Acceptance criteria:

- Open-ended discovery remains intact.
- The homepage does not list hundreds of undifferentiated commands.
- PHP or another newly discovered tool remains visible even before
  classification.
- Classification always exposes its rule and evidence.

### Phase 5 — Filesystem map prototype

1. Define and validate filesystem-location manifests.
2. Add sparse hierarchy projection.
3. Implement a spatial, simulated-depth tree/drill-down UI for the
   demonstration branches as a separate top-level destination.
4. Associate existing entities through typed paths.
5. Preserve stable identifiers needed for future cross-navigation, but do not
   add an in-explorer relationship/filesystem toggle yet.
6. Add Finder/Terminal/Copy actions.
7. Update synthetic profiles with unavailable, partial, and ambiguous examples.

Acceptance criteria:

- The map explains several key macOS locations.
- Observed entities appear at their correct path branches.
- Not-enumerated and empty states are never conflated.
- No unbounded filesystem traversal occurs.

### Future Phase 6 — separated and parked

Phase 6 was not implemented. See
`FUTURE_PHASE_6_OBSERVATION_HISTORY.md`. The current next phase is
`NEXT_PRODUCT_VALIDATION_PLAN.md`.

## 12. Engineering guidelines

- Add instances through manifests, not Swift arrays or switches.
- Version and validate every new manifest.
- Keep security boundaries and target validation in code.
- Separate observed facts, derived classifications, inferred relationships, and
  user decisions.
- Do not execute arbitrary discovered software.
- Keep first launch synthetic and non-collecting.
- Maintain synthetic/live schema parity.
- Update every committed synthetic profile for structural schema changes.
- Add tests for unknown keys, invalid enum values, unsafe paths, traversal,
  budgets, and partial states.
- Preserve user work and avoid destructive cleanup implementation.
- Prefer generic projectors, action factories, glossary loaders, and display
  policies over entity-specific UI branches.
- Implement all five phases in the overnight execution, with quality gates
  between phases.
- Commit frequently at stable, tested boundaries. Each commit should represent
  one coherent capability or safe refactor and leave the repository buildable.
- Do not commit broken intermediate schema migrations. Pair schema changes with
  migrations, synthetic fixture updates, and validation tests in the same
  commit.

## 13. Current code touchpoints

- Homepage and linked coverage:
  `Sources/HALApp/ContentView.swift`
- App state, collector counts, refresh lifecycle:
  `Sources/HALApp/HALApp.swift`
- Inspector details, instances, relationships:
  `Sources/HALApp/InspectorView.swift`
- Zoom, pan, node interaction:
  `Sources/HALVisualization/RelationshipCanvas.swift`
- Graph projection:
  `Sources/HALCollectors/ApplicationGraphProjector.swift`
- Rebuildable detectors:
  `Sources/HALCollectors/Resources/rebuildable-data-detectors.json`
- Known capabilities:
  `Sources/HALCollectors/Resources/runtimes.json`
- Open-ended executable roots:
  `Sources/HALCollectors/Resources/command-line-software.json`
- Persistence parsing:
  `Sources/HALCollectors/PersistenceCollector.swift`
- Canonical graph schema:
  `Sources/HALProfileSchema/Resources/system-profile.schema.json`
- Display policy:
  `Sources/HALVisualization/Resources/display-policy.json`

## 14. Confirmed product decisions

1. Path clicks always expose an options menu containing Copy Path, Reveal in
   Finder, and Open in Terminal.
2. HAL supports multiple terminal applications and prefers a running terminal,
   using the most recently activated supported terminal when several are open.
   The user can override the choice.
3. Keep the current homepage section ordering for now.
4. Replace the persistent linked card with compact footer status that can open
   an upward-expanding explanation and action panel.
5. Explain incomplete collection in concrete product language rather than
   assuming users understand collector terminology.
6. Group noisy macOS commands by default and prioritize package-owned,
   user-local, active, changed, or classified command-line software.
7. The filesystem explorer uses a spatial node visualization with a readable
   nested-tree structure and restrained simulated depth.
8. Start the filesystem explorer as a separate top-level experience. Defer map
   toggling and shared selection until both visualizations mature.
9. Keep the section label **Runtimes & Developer Tools**.
10. The overnight implementation should pursue all five phases and commit
    frequently at stable, tested boundaries.
11. Non-actionable parser and collection issues should be logged quietly rather
    than presented as warnings that imply the user must act.
12. Persistent run history and parser-feedback telemetry are deferred to a
    future phase. Storage is local by default and sharing is explicit.
13. The linked-success card should be concise and action-oriented, retain its
    existing buttons, and add More Info plus a future Observation History link.

## 15. Remaining implementation judgment

No additional product answer is required before generating the implementation
prompt. The implementing agent should use these defaults:

- Non-actionable, acknowledged observation gaps leave the homepage and remain
  discoverable through footer status/history.
- Actionable or newly changed issues may raise the footer's visual emphasis.
- The filesystem prototype prioritizes hierarchy legibility over visual
  novelty and supports Reduce Motion.
- If all five phases cannot be completed safely in one run, finish the current
  phase at a tested, committed boundary, update status documentation, and leave
  the next phase explicitly queued. Do not trade schema integrity or safety for
  nominal phase completion.
