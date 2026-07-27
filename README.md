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

Open `Package.swift` in Xcode and select the `HALApp` scheme for Xcode builds
and debugging. The prototype never reads system inventory, requests
permissions, mutates the machine, or connects to a remote service.

## Documentation

Read these before implementation:

1. [Product vision](VISION.md)
2. [Complete feature catalog](FEATURES.md)
3. [Incremental roadmap](ROADMAP.md)
4. [Engineering operating agreement](ENGINEERING.md)
5. [Current status and next task](STATUS.md)
6. [Phase 0 implementation brief](PHASE_0.md)
7. [Development environment](DEVELOPMENT.md)
8. [Testing strategy](TESTING.md)
9. [Configuration model](CONFIGURATION.md)
10. [Architecture](ARCHITECTURE.md)
11. [Technology decision](TECHNOLOGY.md)
12. [Privacy requirements](PRIVACY.md)
13. [Security and safety requirements](SECURITY.md)
14. [V1 detail](V1.md)
15. [V2 feasibility](V2.md)

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

1. Read every Markdown file in this directory.
2. Follow `ENGINEERING.md`.
3. Begin with Milestone 0 in `ROADMAP.md` unless `STATUS.md` says otherwise.
4. Keep product-level questions separate from low-level implementation.
5. Update status, tests, documentation, and evaluation instructions with every
   completed increment.

V2 documents feasibility and later direction; it is not authorization to add a
privileged agent or collect privacy-sensitive telemetry.
