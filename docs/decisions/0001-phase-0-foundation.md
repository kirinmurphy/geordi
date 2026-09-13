# Decision 0001: Phase 0 foundation

## Status

Accepted on July 26, 2026.

## Context

Phase 0 must validate geordi's interaction model without real collection,
persistence, mutation, permissions, or privileged components.

## Decisions

- Use one Swift package with cohesive `GeordiDomain`, `GeordiFixtures`,
  `GeordiVisualization`, and `GeordiApp` targets. Xcode opens `Package.swift`
  directly and exposes the app scheme, avoiding generated project metadata.
- Use SwiftUI for the native application shell and a custom SwiftUI
  `Canvas`-backed relationship view.
- Place nodes in stable columns by semantic entity type, with stable ID sorting
  within columns. No force simulation or random seed is involved.
- Keep relationship explanation, evidence, confidence, and direction in the
  domain model so the canvas and inspector cannot diverge.
- Model selection independently from type filters. A hidden selection is
  preserved, and search restores its type before focusing it.
- Represent observed facts and geordi inferences as distinct evidence kinds.
  Ambiguous relationships use an explicit unresolved confidence and dashed
  orange presentation.
- Use native Swift Testing and `swift-format` to avoid third-party dependencies.
  A launch smoke harness establishes the UI-test boundary; interaction-level
  XCUITest should be added if the app gains a conventional Xcode project in a
  later milestone.

## Consequences

The prototype is deterministic, synthetic-only, and easy to open from either
the command line or Xcode. Phase 0 intentionally has no collector, database,
action, helper, telemetry, network, or permission boundary.
