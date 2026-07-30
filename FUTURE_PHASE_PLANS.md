# HAL Future Phase Plans

Status: prioritized parking lot  
Current phase: `NEXT_PRODUCT_VALIDATION_PLAN.md`

Hands-on user-facing gaps and acceptance criteria are tracked in
`USER_FACING_TODO.md`.

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

The first concrete provenance gap is reliable Homebrew cask ownership for
applications placed in `/Applications`; see `USER_FACING_TODO.md`.

## Candidate product phase — Portable Mac profiles and guided bootstrap

Companion prototype: sibling repository `../hal-bootstrap`

Potential outcome:

- upload, import, edit, validate, and export a versioned desired-machine
  profile;
- describe applications, command-line tools, bundles, dependencies,
  installation adapters, shell-environment requirements, and verification
  checks;
- compare a captured HAL profile with the desired profile;
- preview a deterministic, dependency-ordered migration plan;
- move a reviewed laptop profile to another Mac without treating the source
  machine's incidental state as universally desired; and
- generate or execute an auditable bootstrap plan only after explicit review.

The existing `hal-bootstrap` starter validates the separation between
detection and installation and uses a stub installer by default. Preserve that
separation if the projects converge: HAL observations are evidence about what
exists, while a portable profile is an explicit user-authored decision about
what should be installed.

The profile format must be versioned and schema validated. Growable
applications, tools, bundles, dependencies, install adapters, PATH
contributions, and verification checks belong in manifests rather than
hardcoded application logic.

Shell configuration is part of the desired-machine plan. For example,
installing Go on macOS does not itself make `$HOME/go/bin` discoverable. A
default-tools profile should be able to declare that PATH contribution,
explain why it is needed, detect an equivalent existing entry, preview an
idempotent `.zshrc` change, distinguish persistent configuration from the
current shell process, and provide rollback for HAL-managed edits.

Safety boundary:

- importing or comparing a profile is read-only;
- uploaded profiles are untrusted data and cannot introduce arbitrary shell
  commands;
- installation behavior uses reviewed, typed adapters with constrained
  arguments;
- every filesystem or shell-profile change is previewed and explicitly
  approved;
- secrets and machine-specific paths are excluded or represented by validated
  placeholders;
- destructive replacement and cleanup are outside the first phase; and
- bootstrap execution remains a separate authorization boundary from HAL's
  ordinary synthetic or linked read-only collection.

Entry signal: users want to reproduce an understood machine configuration on a
new Mac, and the `hal-bootstrap` prototype demonstrates deterministic planning,
idempotent environment changes, verification, and rollback without arbitrary
command execution.

Priority: after daemon explanation and representative Application Story
validation; before installation-footprint automation or destructive reclaim
work.

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
