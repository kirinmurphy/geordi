# geordi Status

## Current phase

Product discovery and exploration phases 1–5 are implemented and verified.
The **Application Story and Guided Proof** interface is implemented. The
current phase is representative product evaluation and revision based on
observed user behavior.

Future Phase 6, Observation History, is deliberately parked.

The July 29 product-refinement backlog is implemented: hierarchical Software
Sources, setup-time application grouping, shared relationship previews,
question-specific exploration routes, high-fan-out grouping, glossary-aware
prose, and the deterministic paste-only shell/PATH visualizer.

## Current milestone

Run at least three Application Story evaluation sessions and make a go, revise,
or stop decision before adding more collection, history, measurement, or
persistence infrastructure.

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
- Generic **How geordi fits together** reference with a hierarchical conceptual
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
- Expandable observed-fact and geordi-inference evidence
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
- Concise linked-success card with persisted dismissal and compact Collection
  Health status
- Reusable Copy Path, Reveal in Finder, and manifest-driven terminal actions
- Manifest-driven inspector organization and contextual glossary
- Searchable and aggregated command-line inventory with package ownership and
  copy-only removal guidance
- A separate sparse Filesystem Map with deterministic hierarchy, breadcrumbs,
  observed-entity associations, and explicit not-enumerated/unavailable states
- Task-oriented home entry points and an application-first narrative explaining
  activity, source, startup behavior, associations, uncertainty, and next steps
- A replayable, keyboard-accessible fictional walkthrough driven by a validated
  presentation manifest
- Expanded Software Sources with separately clickable managers, application
  and package strips, nested managed items, and an App Store application source
- Bundled versus User-installed classification derived from bounded bundle
  creation and Mac setup-marker evidence, with an explicit unknown category
- Read-only application mini-maps rendered by the same canvas as the full node
  explorer
- Manifest-driven relationship grouping for dense, high-fan-out entity maps
- Glossary-aware prose rendering plus a domain-language audit
- A schema-backed, deterministic shell/PATH analyzer and paste-only visualizer
  that does not implicitly read shell configuration

## Implementation state

- Native application: runnable Debug concept
- Swift packages: domain, fixtures, visualization, app, validator
- Test harness: 140 deterministic tests plus fixture and bundle validation
- Profile schema: canonical declarative Draft 2020-12 version 3 JSON Schema,
  with generic Swift validation plus typed semantic endpoint and evidence
  checks
- Manifest migration: all seven synthetic profiles are schema-backed and selected
  through a separately schema-validated profile catalog
- Real-data preparation: typed observations, scan and collector outcomes,
  capability and freshness states, versioned finding evidence, and an injected
  graph-snapshot provider boundary
- SQLite/history schema: intentionally not created
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
  arguments; a versioned, user-home-scoped shell-framework collector retains
  only bounded identity, sanitized repository-host, and declared configuration
  reference states; and the provider is selected only after explicit linking
- Data-source lifecycle: first launch is synthetic; linking, cached live
  startup, manual refresh, timestamp/freshness presentation, atomic snapshot
  backup, guarded unlink/reset, and return to the fictional profile are
  implemented
- Visualization: stable relationship canvas plus a separate sparse Filesystem
  Map prototype
- Signing and distribution: not configured

The app launches with the deterministic synthetic provider and performs no
machine collection until the user explicitly links the Mac. Linked mode reads
manifest-scoped application bundle metadata, static code-signing facts, App
Store receipt presence, redacted download-origin hosts, and conventional
associated-location metadata, Homebrew/package/runtime/command-line metadata,
point-in-time processes, selected persistence declarations, and bounded
shell-framework identity/configuration-reference states, then persists and
refreshes the normalized snapshot. Installer-package provenance,
persistence approval/loaded state, process history, SQLite, and distribution
remain unimplemented. Their sequencing is conditional on product validation.

## How to run

```bash
make run
```

Or open `Package.swift` in Xcode and run the `GeordiApp` scheme.

## How to test

```bash
make test
make verify
```

## Recommended next task

Use `PRODUCT_EVALUATION_GUIDE.md` to run at least three representative sessions,
record each with `PRODUCT_EVALUATION_SESSION_TEMPLATE.md`, and revise the
highest-frequency user-facing friction.

The three hands-on gaps in `USER_FACING_TODO.md` are implemented. The focused
linked evidence pass is recorded in `LINKED_MAC_ACCEPTANCE_RECORD.md`;
representative participant sessions and the remaining lifecycle checks are
still required.

Do not start Observation History, recursive measurement, telemetry, cleanup, or
privileged collection yet.

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
8. Confirm geordi describes event correlation without overstating causation.
9. Search for `render cache` and confirm the result retains whole-machine
   context.
10. Decide whether the map adds understanding beyond the summary and inspector.
11. Open **How this map works**, select several concepts, and confirm their
    explanations appear without changing the current page.

## Linked-Mac test-drive checklist

Historical findings from the first linked-Mac test drive use `[x]`; a checked
negative statement records the problem that was observed, not its current
implementation status. Completed fixes are summarized in
`COMPLETED_PHASES.md`. Unchecked lifecycle checks remain useful regression
evaluation.

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
- [ ] Relaunch geordi and confirm the cached linked snapshot appears before the
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
- geordi currently persists and exports only its compiled live snapshot; it has no
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
- geordi could become another information dump unless explanation remains central.
- Apple entitlements may constrain advanced V2 monitoring.

## Product-owner involvement needed next

Recruit representative participants for the Application Story evaluation. No
permission, privacy, signing, history, or destructive decision is required.

## Documentation map

- Completed phases: `COMPLETED_PHASES.md`
- Current product phase: `NEXT_PRODUCT_VALIDATION_PLAN.md`
- Future and parked phases: `FUTURE_PHASE_PLANS.md`
- Parked Observation History: `FUTURE_PHASE_6_OBSERVATION_HISTORY.md`
- User-facing product gaps: `USER_FACING_TODO.md`
