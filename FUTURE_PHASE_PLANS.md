# HAL Future Phase Plans

Status: prioritized parking lot  
Current phase: `NEXT_PRODUCT_VALIDATION_PLAN.md`

This file separates future work from completed implementation records. Sequence
is intentionally conditional on product evidence; phase numbers do not imply
automatic execution.

## Parked Phase 6 — Observation History

Purpose: explain noteworthy changes and recurring collection issues over time.

Status: deliberately parked until users demonstrate that “what changed?” is a
top question.

Detailed plan: `FUTURE_PHASE_6_OBSERVATION_HISTORY.md`

## Candidate user-facing phase — Dedicated command-line explorer

Potential outcome:

- browse user-local, package-owned, classified, active, and system commands;
- search and filter without exposing a thousand-row homepage;
- understand package ownership, aliases, paths, activity, and capability;
- copy validated package-manager guidance without executing removal.

Entry signal: users find command ownership valuable during the next product
evaluation.

## Candidate user-facing phase — Filesystem story refinement

Potential outcome:

- clearer nested hierarchy and branch transitions;
- stronger explanation of why a location matters;
- entity badges grouped by role;
- polished unavailable, unreadable, empty, and not-enumerated states;
- reliable navigation from an Application Story into location context.

Entry signal: users understand application stories but repeatedly ask where
associated components live.

## Candidate engineering phase — Bounded storage measurement

Potential outcome:

- cancellable size observations under the existing measurement contract;
- measured reclaimable candidates without implying deletion safety;
- deterministic partial, budget, filesystem-boundary, symlink, and hard-link
  behavior.

Status: not next. Measurement is plumbing-heavy and should begin only when user
testing shows reclaimable size is necessary to validate the product.

## Candidate engineering phase — Installation provenance

Potential outcome:

- installer receipt correlation;
- clearer package/application ownership;
- richer application-origin explanation.

Entry signal: current signing, receipt, download, and package evidence fails to
answer “where did this come from?” in representative evaluations.

## Later milestones

- Reclaim planning and recoverable cleanup
- Persistence and software-change history
- Resource incident recording and explanation
- Installation footprint observation
- Advanced observation or privileged helpers

These retain the safety and entry requirements in `ROADMAP.md`, `SECURITY.md`,
`PRIVACY.md`, `V1.md`, and `V2.md`.

## Prioritization rule

Prefer the smallest phase that makes a user question materially easier to
answer with existing data. Add collection or persistence only when a validated
user-facing experience is blocked by missing evidence.
