# HAL Status

## Current phase

Phase 0 contextual-atlas revision implemented on July 26, 2026 after the first
product evaluation failed. The revised build is installed and awaiting a
second product evaluation.

## Current milestone

Milestone 0 — repository and interactive concept.

## What exists

- Product vision
- Complete feature catalog
- Incremental roadmap
- Swift-first technology decision
- Engineering operating agreement
- V1 feature detail
- V2 feasibility analysis
- Privacy and security requirements
- An earlier macOS shell prototype for reclaim-oriented scanning
- Phase 0 implementation brief
- Development environment and mode definitions
- Test strategy and harness requirements
- Configuration model
- Repository ignore rules and bootstrap script

## What works

- Whole-machine orientation organized around Storage, Installed Software, and
  Performance
- Inventory-first homepage with recent alerts, user-installed applications,
  and reclaimable storage candidates
- Linked application inventory defaults to a manifest-classified User
  Installed scope, with filters for bundled software, system utilities,
  unclassified records, and all applications
- Initial link completion leads to installed applications; subsequent
  **Check this Mac again** runs keep the snapshot interactive and report
  changed versus unchanged results with timing
- Initial linking uses a focused read-only setup overlay with stage context and
  a cancellable return to the unchanged fictional profile
- Distinct warning treatment for recent performance and storage alerts
- Relationship maps appear after selecting an inventory item rather than at
  launch
- Map supports drag and two-finger panning, pinch and Command-scroll zoom,
  double-click focus, reset controls, and an interaction legend
- Generic **How HAL fits together** reference with a hierarchical conceptual
  model and important safety distinctions
- Reference is contextual map help presented in a same-window closable sheet;
  it is not a sidebar destination or breadcrumb namespace
- Responsive inspector: right of the map when wide, below it when horizontal
  space is constrained
- Bounded category projections instead of rendering the full compatible graph
- Five labeled graph regions: Context & Sources, Software, Runtime & Startup,
  Data, and Impact
- Minimum readable graph scale with overflow panning instead of tiny labels
- No breadcrumb on Home; detail breadcrumbs use a clickable Home item without a
  redundant back control
- Progressive relationship labels: quiet arrow markers by default, full text
  on hover, strong outline only for explicit relationship selection
- Synthetic Current Activity metrics for CPU, memory, running apps, and
  background processes below Alerts
- One coherent fictional Mac with realistic applications and connected events
- Recognizable synthetic shapes for Docker Desktop, Visual Studio Code, cmux,
  ChatGPT, Brave Browser, Homebrew, Oh My Zsh, and an npm-installed package
- Distinct application, package-manager, shell-framework, and package concepts
- Stable breadcrumb and sidebar context while drilling in and back out
- Plain-language summaries before technical relationship evidence
- Application-centered maps spanning installation origin, processes, files,
  startup behavior, resource impact, and incidents
- Native SwiftUI macOS window
- Stable semantic relationship layout
- Trackpad/mouse pan and zoom with visible controls
- Node selection and directly relevant relationship highlighting
- Clickable directional relationships with confidence and evidence
- Search that moves focus to a matching entity
- Type filters that preserve selection and context
- Complete text navigator independent of the map
- Detail inspector and plain-language explanations
- Expandable observed-fact and HAL-inference evidence
- Six deterministic versioned fixtures, including the familiar fictional Mac and
  honest ambiguity
- Visible `FICTIONAL MAC` environment label
- Native top-row trailing search beside the macOS sidebar control, followed by
  a toggleable full-width fictional-environment banner; all scrolling content
  begins below these fixed controls
- An interactive, same-window reference spanning the complete user-facing
  model from Mac context and software provenance through findings and decisions;
  selected concepts expand over the diagram and collapse back in place
- The reference retains persistence as a first-class concept and explicitly
  explains evidence-bearing relationships between observations and findings
- Strict formatting, graph validation, unit tests, and application-bundle validation

## Implementation state

- Native application: runnable Debug concept
- Swift packages: domain, fixtures, visualization, app, validator
- Test harness: 73 deterministic tests plus fixture and bundle validation
- Profile schema: canonical declarative Draft 2020-12 version 1 JSON Schema,
  with generic Swift validation plus typed semantic endpoint and evidence
  checks
- Manifest migration: all six synthetic profiles are schema-backed and selected
  through a separately schema-validated profile catalog
- Real-data preparation: typed observations, scan and collector outcomes,
  capability and freshness states, versioned finding evidence, and an injected
  graph-snapshot provider boundary
- SQLite schema: not created
- Real collectors: bounded read-only application-bundle inventory implemented
  with static code-signing validation behind an explicit live snapshot provider;
  search roots and provenance adapters are selected through validated
  declarative manifests; App Store receipt presence and redacted download-origin
  hosts are projected into the live atlas; a bounded manifest-selected
  associated-location collector adds evidence-bearing application/file
  relationships without reading contents or calculating sizes; point-in-time
  processes are resolved through manifest-selected exact-executable and bundle
  containment strategies with a relevance budget; matched user/local launchd
  declarations add evidence-bearing startup relationships without retaining
  arguments; and the provider is selected only after explicit linking
- Data-source lifecycle: first launch is synthetic; linking, cached live
  startup, manual refresh, timestamp/freshness presentation, atomic snapshot
  backup, guarded unlink/reset, and return to the fictional profile are
  implemented
- Visualization: stable semantic Phase 0 canvas created
- Signing and distribution: not configured

The app launches with the deterministic synthetic provider and performs no
machine collection until the user explicitly links the Mac. Linked mode reads
manifest-scoped application bundle metadata, static code-signing facts, App
Store receipt presence, redacted download-origin hosts, and conventional
associated-location metadata, then persists and refreshes the normalized
snapshot. Installer-package and Homebrew provenance, group-container
association, persistence approval/loaded state, process history, SQLite, and
distribution remain unimplemented. Their sequencing is documented in
`REAL_DATA_ASSESSMENT.md`.

## How to run

```bash
make run
```

Or open `Package.swift` in Xcode and run the `HALApp` scheme.

## How to test

```bash
make test
make verify
```

## Recommended next task

Improve retryable, collector-aware initial-link failure diagnostics, then add
application-scope and collector-coverage counts. Model coverage now verifies
initial-link progress, cancellation, success, retry, unchanged and changed
refreshes, and retained-data failure. Native UI automation remains deferred
until the interaction runner extends beyond packaging verification.

## Product evaluation checklist

1. At launch, identify the recent alerts, installed applications, and reclaim
   summary without opening a relationship map.
2. Open the reclaimable-storage alert and distinguish rebuildable data from
   protected work.
3. Return to **Home** without losing orientation.
4. Open **Installed software**, then select Cutline Video.
5. Trace Cutline to its process, render worker, files, and update helper.
6. Select a relationship and expand the supporting evidence.
7. Open **Performance** and explain what happened during the memory incident.
8. Confirm HAL describes event correlation without overstating causation.
9. Search for `render cache` and confirm the result retains whole-machine
   context.
10. Decide whether the map adds understanding beyond the summary and inspector.
11. Open **How this map works**, select several concepts, and confirm their
    explanations appear without changing the current page.

## Linked-Mac test-drive checklist

Recorded outcomes use `[x]`; unchecked items still need evaluation.

- [x] First launch stayed on the fictional profile until **Link to your Mac**
  was selected.
- [x] The link action exposed a `Linking…` pending state.
- [x] Linking completed and displayed a read-only application inventory.
- [x] The completion notice did not provide a clear next step.
- [x] **Refresh Now** was ambiguous about whether it repeated collection or
  enabled missing associated-data capabilities.
- [x] An unchanged refresh appeared to do nothing.
- [x] The linked list mixed system and non-system applications.
- [x] Signing and provenance collection had no obvious visible effect without
  finding and using the application inspector.
- [x] Returning to fictional data was not discoverable; the action was hidden
  as **Unlink this Mac…** inside an unlabeled sidebar menu.
- [x] Live applications had no associated file, process, event, or other
  relationship nodes, leaving the live atlas substantially empty compared with
  the fictional profile.
- [ ] Inspect several application details and confirm paths, signing facts,
  App Store receipt presence, and redacted download origins are understandable.
- [ ] Relaunch HAL and confirm the cached linked snapshot appears before the
  background refresh completes.
- [ ] Disconnect the network and confirm collection remains local and usable.
- [ ] Exercise refresh failure and confirm the last successful snapshot remains
  visible.
- [ ] Exercise unlink cancel, export-and-unlink, and delete-and-unlink.
- [ ] Confirm unlink restores the deterministic fictional profile and does not
  modify applications or unrelated files.
- [ ] Record representative system, non-system, and uncertain applications for
  classification-rule tests without committing private machine paths.

## Known issues and limitations

- The first interface failed product validation. The contextual-atlas revision
  has not yet been evaluated by the product owner.
- Phase 0 visual design is intentionally provisional.
- Dense scenarios may require panning or zooming on smaller windows.
- The UI automation foundation currently verifies native app packaging; product
  interactions are covered at the model layer and by the manual evaluation
  checklist rather than a full XCUITest runner.
- HAL currently persists and exports only its compiled live snapshot; it has no
  historical database, notification layer, or machine cleanup actions.
- Associated application support, cache, preference, log, saved-state, sandbox,
  process, and persistence relationships are collected conservatively and
  relevance-grouped for live application details, but still need product
  evaluation.

## Known risks

- The relationship visualization still requires product evaluation to prove it
  is clearer than a textual inspector.
- Native collection permissions may reduce evidence quality.
- Ownership inference must expose uncertainty.
- Background telemetry may impose unacceptable overhead.
- HAL could become another information dump unless explanation remains central.
- Apple entitlements may constrain advanced V2 monitoring.

## Product-owner involvement needed next

Evaluate the contextual-atlas revision. No permission, privacy, signing, or
destructive decisions are requested.
