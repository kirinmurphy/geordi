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
- Test harness: 41 deterministic tests plus fixture and bundle validation
- Profile schema: canonical declarative Draft 2020-12 version 1 JSON Schema,
  with generic Swift validation plus typed semantic endpoint and evidence
  checks
- Manifest migration: simple-application and helper-rich-application fixtures
  migrated end-to-end; remaining synthetic profiles still require migration
- Real-data preparation: typed observations, scan and collector outcomes,
  capability and freshness states, versioned finding evidence, and an injected
  graph-snapshot provider boundary
- SQLite schema: not created
- Real collectors: bounded read-only application-bundle inventory implemented
  with static code-signing validation behind an explicit live snapshot provider;
  search roots are selected through a validated declarative manifest, and the
  provider is not yet selected by the application
- Visualization: stable semantic Phase 0 canvas created
- Signing and distribution: not configured

The app still runs exclusively through the deterministic synthetic provider, so
launching HAL does not inspect the real Mac. The application collector is
available only through explicit dependency injection and currently reads bundle
metadata and static code-signing facts from caller-provided roots. Process
inventory, provenance adapters, SQLite, and distribution remain unimplemented.
Their sequencing is documented in `REAL_DATA_ASSESSMENT.md`.

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

Run the revised evaluation below. Do not begin Phase 1 until the contextual
synthetic interaction is directionally useful.

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

## Known issues and limitations

- The first interface failed product validation. The contextual-atlas revision
  has not yet been evaluated by the product owner.
- Phase 0 visual design is intentionally provisional.
- Dense scenarios may require panning or zooming on smaller windows.
- The UI automation foundation currently verifies native app packaging; product
  interactions are covered at the model layer and by the manual evaluation
  checklist rather than a full XCUITest runner.
- The app has no persistence, export, collector, notification, or action layer.

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
