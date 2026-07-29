# Phase 0 Implementation Brief

Status: completed historical brief. See `COMPLETED_PHASES.md`.

## Objective

Deliver a runnable native macOS concept that proves HAL's core interaction:

> A user can select a synthetic application and understand how it relates to
> processes, files, resource use, and a persistent helper.

Phase 0 uses deterministic synthetic data. It does not inspect or modify the
real Mac.

## Deliverable

A Debug application that provides:

- A native macOS window
- A custom zoomable and pannable 2D/2.5D relationship canvas
- Stable semantic node placement
- Application, process, file, persistence, resource, and incident entities
- Directional, typed relationships
- Selection and highlighted relationship paths
- Search and type filters
- A detail inspector
- A plain-language explanation
- An expandable evidence section
- At least four deterministic fixture scenarios
- A visible `SYNTHETIC DATA` environment indicator

## Required fixture scenarios

### Simple application

One application, one process, support files, and ordinary resource use.

### Helper-rich application

One application with child processes, a login helper, caches, logs, and a
shared support relationship.

### Resource incident

A memory-pressure incident involving multiple contributing processes and nearby
events.

### Ambiguous ownership

A folder or helper with two plausible owners and evidence that cannot support a
confident conclusion.

The ambiguous scenario is essential: HAL must make uncertainty understandable,
not merely draw confident-looking connections.

## Interaction acceptance criteria

- The map remains legible at launch without manual rearrangement.
- Selecting a node highlights its directly relevant relationships.
- Selecting a relationship explains its direction, type, confidence, and
  evidence.
- Search moves focus to a result.
- Filters do not destroy the user's current context.
- Zoom and pan behave naturally with trackpad and mouse.
- The inspector works without requiring the map for users who prefer text.
- No raw identifier appears without a human-readable label.
- Synthetic mode cannot invoke system mutation.

## Engineering acceptance criteria

- The repository builds from documented commands.
- Unit and UI tests run without access to real system data.
- Fixtures are deterministic and versioned.
- Domain, visualization, and fixture concerns are separate.
- Configuration is typed and external to feature logic.
- There is no duplicated relationship or explanation logic.
- Formatting and static checks are automated.
- The Debug application stores data separately from future Release data.
- `STATUS.md` is updated at handoff.

## Non-goals

- Real application scanning
- Process enumeration
- Filesystem scanning
- SQLite production schema
- Cleanup
- Background agents
- Notifications
- Signing for distribution
- Privileged access
- Endpoint Security
- Final visual design

## Product evaluation

The product owner should evaluate:

1. Can I tell what the selected application owns and launches?
2. Can I distinguish observed facts from HAL's inferences?
3. Does uncertainty feel honest and comprehensible?
4. Is navigation calmer and clearer than reading several tables?
5. Does the map add understanding beyond the inspector?
6. Which information feels distracting or unexplained?

Phase 1 begins only after this interaction is directionally useful.
