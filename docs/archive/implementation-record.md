# Product Discovery and Exploration Implementation Record

Status: completed implementation record
Specification: `PRODUCT_DISCOVERY_AND_EXPLORATION_PLAN.md`

## Completed work

- Phase 1: manifest-projected rebuildable-data display names, **Reclaimable
  Data** presentation, concise linked-success card, persisted dismissal,
  compact footer status, and a selectable Collection Health panel.
- Phase 2: reusable path menu with copy, Finder, and terminal choices;
  manifest-driven terminal adapters; manifest-driven inspector grouping;
  evidence-derived Explore further actions; and a validated glossary with
  delayed, cancellable hover plus immediate button/keyboard activation.
- Phase 3: visible zoom percentage, bounded/disabled zoom controls,
  Command-plus/minus shortcuts, larger readable labels, selectable inspector
  and diagnostic text, and copy-name context actions.
- Phase 4: open-ended bounded executable inventory, runtime and package
  enrichment, Homebrew ownership relationships, default suppression of
  package-owned alias rows, grouped macOS command count, command search, and
  copy-only validated Homebrew removal guidance.
- Phase 5: a separate top-level Filesystem Map, validated curated-location
  catalog, deterministic sparse projection, breadcrumbs, drill-in/back,
  simulated depth that respects Reduce Motion, typed observation states,
  entity associations, and path actions. The projection performs no filesystem
  traversal.
- Future Phase 6 remains deferred. No observation-history or parser-feedback
  store was added.

## Decisions

### Path actions

Options considered were implicit Finder activation, a single default action,
and an explicit menu. The explicit menu was selected because it is predictable,
keyboard accessible, exposes Copy Path everywhere, and avoids surprising
external application launches. Terminal support uses validated bundle adapters
and `NSWorkspace`; no discovered executable is run and no Accessibility
permission is requested.

### Filesystem representation

Options considered were adding folder entities to the relationship graph,
enumerating the live filesystem, and deriving a separate sparse projection.
The separate projection was selected because it preserves graph semantics,
keeps collection bounded and read-only, and can distinguish “not enumerated”
from observed states. Curated locations and budgets live in a versioned
manifest; user paths remain observations.

### Command-line presentation

Options considered were listing every executable, hiding unclassified tools,
and aggregating low-value/system and package-owned aliases. Aggregation was
selected because it preserves search and graph evidence while preventing
hundreds of peer homepage rows. Removal guidance is copied only after a
conservative package-name validation and is never executed.

### Collection issues

Parser limitations remain discoverable in Collection Health but are described
as geordi limitations rather than Mac faults. Permission-denied states retain
action-oriented language. Persistent local issue history was not introduced.

## Verification

- Baseline: 113 tests passed before the new exploration layers.
- Targeted integrated suite: 117 tests passed after adding the glossary,
  terminal adapters, filesystem catalog/projection, and UI integration.
- New tests cover unknown manifest keys, exact glossary aliases, unsafe path
  traversal, deterministic sparse projection, and terminal-adapter validation.
- `make verify` passed: strict formatting, 117 tests, all seven canonical
  synthetic fixtures, Debug build, application packaging, and native bundle
  smoke validation.
- The development build was installed at `~/Applications/geordi.app` and launched.
  Automated screenshot capture was unavailable in the execution environment,
  so no claim is made for pixel-level visual verification.

## Remaining work

- No work remains within the completed phases 1–5 boundary.
- Product validation continues in `NEXT_PRODUCT_VALIDATION_PLAN.md`.
- Deferred phases are tracked in `FUTURE_PHASE_PLANS.md`.

## Commits

- `d99a298` — complete the five-phase product discovery and exploration
  implementation, schemas, manifests, fixtures, and tests.
