# HAL

HAL is a macOS-first relational system visualizer. It connects applications,
processes, files, persistence, installations, resource use, and historical
events so users can understand what their computer is doing and why.

HAL is inspired by *2001: A Space Odyssey*. The name describes the product's
role as a system observer and explainer; it does not imply autonomous control.

## Product thesis

Existing macOS tools expose substantial information but present it across
separate tables, totals, and diagnostic surfaces. HAL builds a navigable system
atlas:

> Every important number should be connected to an owner, a history, an
> explanation, and—when appropriate—a safe action.

The initial validation target is one application shown in context: identity,
origin, current processes, files, footprint, helpers, persistence, and recent
activity.

## Current decisions

- Focus on macOS.
- Build a native desktop application.
- Use Swift with SwiftUI/AppKit.
- Use a custom 2D/2.5D relationship visualization.
- Use SQLite for local history.
- Keep collection local and read-only by default.
- Keep adapters around platform collectors without promising early
  cross-platform support.
- Build incrementally so every milestone remains useful if development pauses.
- Defer privileged monitoring until a demonstrated capability gap requires it.

## Phase 0 prototype

Phase 0 is a runnable native macOS concept using deterministic synthetic data.
It opens on one coherent fictional Mac organized around reclaimable storage,
installed software, and performance incidents. Users can drill from the whole
machine into an application and its processes, files, startup behavior,
resource impact, explanations, and evidence.

The default fixture uses recognizable software shapes—Docker Desktop, Visual
Studio Code, cmux, ChatGPT, Brave Browser, Homebrew, Oh My Zsh, and an
npm-installed TypeScript package. All sizes, processes, events, and findings
remain fictional; Phase 0 never scans the real Mac.

The primary screen is an inventory; relationship maps open as drill-down
context. A built-in **How HAL fits together** reference explains the generic
installation, software, runtime, persistence, data, resource, event, and
incident hierarchy.

Requirements:

- macOS 15 or later
- Xcode 26.6 or a compatible Swift 6.2+ toolchain

Run it:

```bash
make run
```

This creates `.build/debug/HALApp.app` and opens it through macOS
LaunchServices. It works from ordinary terminals and terminal multiplexers such
as cmux. Closing HAL's last window quits the Debug application, so the next
`make run` always presents a fresh window.

`make run` also refreshes the stable development installation at
`~/Applications/HAL.app`. Spotlight and Desktop shortcuts can therefore keep
pointing to one path across updates. Set up the Desktop shortcut once:

```bash
make install-shortcut
```

Afterward, every `make run` rebuilds and refreshes the installed development
app before opening it.

Verify it:

```bash
make verify
```

Export every cataloged synthetic profile through the canonical deterministic
encoder:

```bash
swift run hal-fixture-validator --export /tmp/hal-profile-export
```

The export validates each graph, sorts entities, relationships, details, and
evidence, emits stable JSON keys, and revalidates the encoded document against
the versioned system-profile schema.

Linked mode also provides **Export redacted diagnostics…**. Diagnostic export
preserves graph shape, collector states, timestamps, confidence, and evidence
kinds while replacing local identifiers, names, paths, scopes, observation
identifiers, and free-form values. This is intentionally different from the
explicit unredacted backup offered during unlink.

Open `Package.swift` in Xcode and select the `HALApp` scheme for Xcode builds
and debugging. First launch remains synthetic and non-collecting. Linking is
explicit and enables bounded local read-only observation; HAL does not mutate
the machine or connect to a remote service.

## Documentation

Read these before implementation:

1. [Product vision](VISION.md)
2. [Current status](STATUS.md)
3. [Next product-validation phase](NEXT_PRODUCT_VALIDATION_PLAN.md)
4. [Application Story evaluation guide](PRODUCT_EVALUATION_GUIDE.md)
5. [Completed phases](COMPLETED_PHASES.md)
6. [Future and parked phases](FUTURE_PHASE_PLANS.md)
7. [Incremental roadmap](ROADMAP.md)
8. [Complete feature catalog](FEATURES.md)
9. [Engineering operating agreement](ENGINEERING.md)
10. [Development environment](DEVELOPMENT.md)
11. [Testing strategy](TESTING.md)
12. [Configuration model](CONFIGURATION.md)
13. [Architecture](ARCHITECTURE.md)
14. [Technology decision](TECHNOLOGY.md)
15. [Privacy requirements](PRIVACY.md)
16. [Security and safety requirements](SECURITY.md)
17. [V1 detail](V1.md)
18. [V2 feasibility](V2.md)

## Product domains

- **Atlas:** relational visualization and explanation
- **Applications:** inventory, provenance, signatures, approvals, and changes
- **Processes:** ownership, activity, and resource contribution
- **Persistence:** login items, agents, daemons, helpers, and extensions
- **Reclaim:** data that may be safely reclaimable
- **Storage:** overall capacity and growth as a contextual lens
- **Incidents:** preserved and explained resource spikes
- **Footprints:** installation evidence and removal planning

## Proposed CLI companion

The desktop app is primary. A CLI supports automation and diagnostics:

```text
hal map
hal status
hal health
hal explain <entity>
hal changes

hal apps
hal processes
hal persistence
hal reclaim
hal incidents
hal doctor
```

This surface remains provisional until real workflows exist.

## Existing prototype

The original shell prototype validates a subset of the Reclaim workflow:

- Storage and growth reports
- Common rebuildable development folders
- Threshold checks and Notification Center alerts
- Interactive, Trash-based cleanup
- A `launchd` installer

Prototype files are stored beside this documentation:

- [`../disk-hygiene.sh`](../disk-hygiene.sh)
- [`../install-disk-hygiene.sh`](../install-disk-hygiene.sh)
- [`../uninstall-disk-hygiene.sh`](../uninstall-disk-hygiene.sh)

Treat the scripts as behavioral input, not the production architecture.

## Continuation instructions

A new implementation task should:

1. Read `STATUS.md`, `NEXT_PRODUCT_VALIDATION_PLAN.md`, `AGENTS.md`, and the
   directly relevant architecture and safety documents.
2. Follow `ENGINEERING.md`.
3. Treat `COMPLETED_PHASES.md` as history and `FUTURE_PHASE_PLANS.md` as
   conditional work, not automatic authorization.
4. Keep product-level questions separate from low-level implementation.
5. Update status, tests, documentation, and evaluation instructions with every
   completed increment.

V2 documents feasibility and later direction; it is not authorization to add a
privileged agent or collect privacy-sensitive telemetry.
