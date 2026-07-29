# HAL Completed Phases

Status: historical record  
Updated: July 29, 2026

This file is the concise index of product and engineering phases that have
reached a verified implementation boundary. Detailed decisions remain in the
linked source documents and decision records.

## Phase 0 — Native contextual atlas

Completed:

- Native SwiftUI macOS application and deterministic synthetic mode
- Inventory-first homepage and application-centered relationship maps
- Search, filters, selection, inspector, evidence, confidence, zoom, and pan
- Versioned synthetic fixtures and canonical system-profile schema
- Explicit read-only linking, refresh, cached startup, backup, and unlink
- Bounded application, signing, provenance, associated-location, process,
  persistence, rebuildable-root, Homebrew, runtime, package, and command-line
  observation

Historical brief: `PHASE_0.md`  
Architecture decisions: `DECISIONS/0001-phase-0-foundation.md` through
`DECISIONS/0009-complete-interactive-reference.md`

## Product discovery and exploration phases 1–5

Completed:

1. Homepage clarity, Reclaimable Data, linked-success lifecycle, compact
   status, and collection-health explanations
2. Path actions, inspector organization, per-node exploration, and glossary
3. Zoom, typography, selection, copying, and relationship-map usability
4. Command-line aggregation, ownership, classification, search, and copy-only
   removal guidance
5. Separate sparse Filesystem Map with deterministic hierarchy, breadcrumbs,
   path actions, entity associations, and distinct observation states

Detailed completed specification:
`PRODUCT_DISCOVERY_AND_EXPLORATION_PLAN.md`  
Implementation and verification: `IMPLEMENTATION_RECORD.md`

## Verification boundary

The completion boundary recorded on July 29, 2026 passed:

- strict Swift formatting;
- 117 tests across 24 suites;
- validation of all seven committed synthetic profiles;
- Debug build and native application-bundle smoke validation; and
- development installation and launch.

The primary implementation commit is `d99a298`.

## Application Story implementation

The user-facing Application Story, task-oriented homepage, manifest-driven
fictional walkthrough, and evaluation materials are implemented. Product
evaluation remains open and is not counted as completed merely because the UI
exists.

Implementation details: `APPLICATION_STORY_IMPLEMENTATION_RECORD.md`

## Intentionally not completed

Completion of a prototype phase does not claim product-market validation or
final visual quality. HAL still needs user evaluation to prove that its
explanations are clearer than existing macOS tools.

The following are not part of the completed boundary:

- local Observation History or parser-feedback storage;
- recursive size measurement and growth history;
- cleanup execution;
- background resource telemetry and incident recording;
- privileged helpers or Endpoint Security;
- release signing and distribution.

Current work is defined in `NEXT_PRODUCT_VALIDATION_PLAN.md`. Longer-term work
is separated in `FUTURE_PHASE_PLANS.md`.
