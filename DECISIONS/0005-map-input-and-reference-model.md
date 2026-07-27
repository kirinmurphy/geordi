# Decision 0005: Native map input and generic reference model

## Status

Accepted on July 26, 2026.

## Context

The relationship map needs familiar macOS navigation and users need a durable
conceptual reference that is not tied to one application.

## Decision

- Support click-drag and two-finger/scroll-wheel panning.
- Support pinch and Command-scroll zoom, visible zoom controls, reset, and
  double-click focus.
- Keep interaction hints visible but visually secondary.
- Add a generic “How HAL fits together” reference:
  installation source → software → runtime/persistence/data →
  resources/events/incidents.
- Keep important data distinctions visible: user data, configuration,
  rebuildable cache, logs, and shared or ambiguous data.

## Entity vocabulary

Current first-class concepts:

- Application
- Package manager
- Shell framework
- Package
- Process
- Persistence
- File/data
- Resource
- Event
- Incident

Useful candidates when a real workflow requires them:

- Runtime container or virtual machine
- Extension or plugin
- Project or workspace
- Installation record or package receipt
- Volume or storage device
- Network listener or connection, subject to separate privacy review

Do not add a type merely because it exists technically. Promote it when users
need to select it, trace relationships through it, or make a decision about it.
