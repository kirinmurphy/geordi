# HAL Incremental Roadmap

Every milestone must produce a useful, runnable artifact. Work should be safe to
pause after any milestone.

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
