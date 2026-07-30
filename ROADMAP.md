# HAL Incremental Roadmap

Every milestone must produce a useful, runnable artifact. Work should be safe to
pause after any milestone.

## Current roadmap state

- Completed implementation records: `COMPLETED_PHASES.md`
- Recommended next phase: `NEXT_PRODUCT_VALIDATION_PLAN.md`
- Parked and conditional work: `FUTURE_PHASE_PLANS.md`

The next investment is user-facing product proof, not automatic progression to
the next plumbing-heavy milestone. Milestone 0 and the current read-only
application-atlas prototype are implemented, but the central product thesis
still needs evaluation with representative users.

| Milestone | Implementation state | Product-validation state |
| --- | --- | --- |
| 0 — Interactive concept | Complete | Needs current-build evaluation |
| 1 — Real application atlas | Prototype implemented | Needs explanation-quality evaluation |
| 2 — Reclaim | Investigation UI only | Measurement and actions deferred |
| 3 — Persistence and changes | Point-in-time startup view only | History deferred |
| 4 — Incidents | Synthetic demonstration only | Telemetry deferred |
| 5 — Installation footprints | Early associations only | Observation plans deferred |
| 6 — Advanced observation | Not started | Entry requirements unmet |

## Immediate phase — Application Story and Guided Proof

Use existing observations to prove that HAL can explain one application more
clearly than existing tools. Build task-oriented entry points, a narrative
Application Story, and a guided fictional walkthrough. Do not add history,
measurement, telemetry, cleanup, or privileged collection in this phase.

Detailed plan: `NEXT_PRODUCT_VALIDATION_PLAN.md`

## Major roadmap initiative — Background services and daemons

### Outcome

A purpose-built explanation of which background services are configured on
this Mac, which are currently observed acting, what software owns them, why
macOS may start them, and where HAL lacks enough evidence to decide.

This extends Milestone 3 without waiting for full historical persistence
tracking. The first useful slice is point-in-time and read-only.

Detailed plan: `DAEMON_EXPLAINER_PLAN.md`

### Product questions

- What is the difference between a LaunchAgent, LaunchDaemon, login item,
  helper, and ordinary running process?
- Which declarations are configured for a user session versus the whole
  system?
- Which declaration fields ask for launch-at-load, restart, or another
  activation condition?
- Is a declared executable currently observed as a process?
- Which application, package, or signed software identity owns the declaration
  and executable?
- Which declarations are unresolved, unreadable, inactive, or ambiguous?

### Exit test

A user can choose an unfamiliar daemon and explain its configured role, current
observed activity, owner, evidence, and uncertainty without reading a raw
property list or mistaking configuration for proof that it is running.

### Safety boundary

The explainer is observational. It does not unload, disable, edit, delete, or
approve a service. Any future control requires a separately reviewed lifecycle,
authorization, recovery, and system-integrity plan.

## Milestone 0: repository and interactive concept

### Outcome

A native macOS application using synthetic data to validate HAL's visual
language.

### Scope

- Swift package and Xcode project
- Clean module boundaries
- Configuration separate from behavior
- Synthetic fixture generator
- Zoomable/pannable relationship canvas
- Stable node layout
- Selection, search, filtering, and inspector
- Evidence/explanation panel
- Unit and UI test foundations
- Repeatable build and test commands
- Architecture, privacy, and status documentation

### Exit test

A user can inspect a synthetic application, trace it to processes, files, and a
helper, and explain the relationships without coaching.

### Useful if paused

Interactive product prototype and reusable visualization test harness.

## Milestone 1: real application atlas

### Outcome

A read-only explorer of real installed applications and running processes.

### Scope

- Application inventory
- Bundle identity and version
- Signing identity
- Basic origin evidence
- Periodic process snapshots
- Process-to-application correlation
- Unresolved process representation
- Manual refresh
- Exportable diagnostic snapshot

### Exit test

HAL can explain several representative applications, including one with helper
processes, more clearly than a raw Activity Monitor listing.

### Useful if paused

Application/process atlas.

## Milestone 2: reclaim

### Outcome

A trustworthy investigator for application-associated and conventional
reclaimable data.

### Scope

- Storage snapshots and comparisons
- Major path categorization
- Growth history
- Application support, cache, and log correlation
- Rebuildability and risk classification
- Candidate explanations
- Dry-run cleanup plans
- Explicit, recoverable cleanup only after dry-run behavior is validated

### Exit test

For every candidate, HAL can explain ownership, evidence, risk, expected
consequence, and recovery before any action is offered.

### Useful if paused

Storage-growth and cleanup investigation tool.

## Milestone 3: persistence and changes

### Outcome

A comprehensible history of installed software and startup behavior.

### Scope

- Login items
- LaunchAgents and LaunchDaemons
- Privileged helper inventory
- Approval and disposition model
- Application installation, update, and removal changes
- Orphaned persistence findings
- Notification history
- Purpose-built background-services and daemon explanation
- Explicit separation of declared, loaded, and currently running states

### Exit test

A user can trace an unfamiliar persistent component to its likely application,
signature, installation source, and running process—or see clearly why the
relationship remains unresolved.

### Useful if paused

Software-change and startup audit.

## Milestone 4: incidents

### Outcome

An Activity Monitor companion that preserves and explains resource incidents.

### Scope

- Low-overhead adaptive telemetry
- CPU, memory pressure, swap, and disk-I/O incidents
- Per-process contribution
- Nearby process and system events
- Incident timeline
- Manual event markers
- Transparent recurring-correlation rules
- Configurable notifications and retention

### Exit test

HAL captures a controlled resource spike, identifies its leading contributors,
shows nearby events, and does not overstate causality.

### Useful if paused

Historical resource incident recorder.

## Milestone 5: installation footprints

### Outcome

Evidence-based application footprints and complete-removal plans.

### Scope

- Package receipt import
- Conventional support-path correlation
- Observed installation sessions
- Before/after filesystem snapshots
- First-launch observation
- Confidence-scored ownership
- Uninstall planning
- Shared and ambiguous file protection

### Exit test

HAL observes a test application installation, explains the resulting footprint,
and creates a safe removal plan that distinguishes owned, shared, and uncertain
files.

### Useful if paused

Installation accountability and uninstall planning.

## Milestone 6: advanced observation

### Outcome

Only if earlier milestones prove that ordinary collectors cannot provide enough
event fidelity.

### Possible scope

- System extension
- Endpoint Security events
- Privileged/native helper
- Higher-fidelity filesystem attribution
- Advanced pattern discovery

### Entry requirements

- A documented user problem that existing collection cannot solve
- Measured value exceeding the permission and maintenance cost
- Privacy and threat-model review
- Apple entitlement and distribution feasibility
- A nonprivileged fallback

## Stop and continue criteria

After every milestone ask:

- Is the result more understandable than Apple's existing surface?
- Does it answer a real question rather than expose more raw data?
- Is confidence/evidence clear?
- Is collection overhead acceptable?
- Can the project pause here while remaining useful?

If a milestone produces visual novelty without increased understanding, pause
and revise before adding more collectors.
