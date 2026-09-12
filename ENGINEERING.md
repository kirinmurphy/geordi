# geordi Engineering Operating Agreement

## Roles

The user is the product designer and QA evaluator. The implementation agent is
responsible for the engineering execution.

The user provides:

- High-level product direction
- Evaluation of usefulness and comprehensibility
- QA feedback from real use
- Decisions when product alternatives materially change the experience
- Approval for permissions, privileged components, signing, distribution, and
  destructive actions

The implementation agent owns:

- Development environment setup
- Project structure
- Architecture within the documented product boundaries
- Code implementation
- Unit, integration, UI, fixture, and performance tests
- Test harnesses
- Build and verification automation
- Configuration design
- Documentation
- Refactoring and technical debt management
- Status and handoff records
- Presenting runnable increments for evaluation

Low-level implementation details should not require product-owner involvement.

## Decision policy

1. Prefer the idiomatic approach for the current Apple ecosystem.
2. Make ordinary, reversible engineering decisions autonomously.
3. Document material architecture decisions.
4. Ask the user when ambiguity changes the product experience, privacy model,
   permission footprint, destructive behavior, or long-term scope.
5. Do not ask the user to choose between low-level technical alternatives that
   can be resolved through evidence, prototypes, tests, or platform convention.

## Current architecture direction

- macOS-first native application
- Swift and SwiftUI/AppKit
- Custom 2D/2.5D relationship visualization
- SQLite historical store
- Read-only collectors before remediation
- Platform adapters and protocols where they clarify boundaries
- No Go service or second runtime unless a measured need justifies it
- No privileged component until a documented capability gap requires it

## Coding standards

- Prefer small, cohesive components.
- Give each module one clear responsibility.
- Separate collection, normalization, inference, presentation, persistence, and
  action.
- Do not duplicate functionality or business rules.
- Extract reusable behavior rather than copy it.
- Keep configuration outside behavior.
- Avoid hard-coded paths, thresholds, retention periods, labels, and detector
  rules when they are legitimately configurable.
- Use typed domain models.
- Make states and confidence explicit.
- Prefer dependency injection at meaningful system boundaries.
- Keep platform-specific code isolated.
- Minimize global mutable state.
- Use structured concurrency.
- Keep public interfaces narrow.
- Treat warnings as failures in maintained targets when practical.
- Remove dead code rather than preserving speculative abstractions.
- Optimize for clarity and correctness before cleverness.

DRY does not mean forcing unrelated behaviors into one abstraction. Reuse must
represent a real shared concept.

## Configuration

Configuration categories may include:

- Collector enablement
- Scan intervals
- Thresholds
- Retention
- Exclusions and protected paths
- Notification preferences
- Privacy-sensitive collection
- Visualization preferences

Defaults must be versioned, documented, and testable. User configuration must
survive application updates.

## Testing expectations

Each capability should be testable without relying exclusively on the
developer's live machine.

Required layers:

- Unit tests for domain rules and transformations
- Fixture-based collector tests
- Integration tests for SQLite and migrations
- Contract tests for collectors and adapters
- Snapshot/golden tests for normalized inventory and explanations
- UI tests for critical navigation and decisions
- Synthetic graph scenarios for visualization
- Performance tests for scan time, database growth, and idle overhead
- Safety tests for protected paths and remediation plans
- Migration tests for persisted user data

Live macOS integration tests should be clearly separated from deterministic
tests and must not mutate system state unless explicitly invoked.

## Test harness

The project should include synthetic machines representing:

- A clean new Mac
- A developer workstation
- An application with many helpers
- Orphaned support files
- Unknown and unsigned processes
- Shared containers
- A resource incident
- An observed installation and removal
- Conflicting or ambiguous ownership evidence

The UI and explanation engine should be usable against these fixtures.

## Build and developer experience

Maintain:

- One documented setup path
- One standard build command
- One standard test command
- A fast unit-test command
- A full verification command
- Deterministic formatting and linting
- Reproducible fixtures
- No secret credentials in the repository
- Clear minimum macOS and Xcode versions

Prefer native ecosystem tools before adding third-party dependencies.
Dependencies require a concrete benefit and should be recorded.

## Incremental delivery

Every milestone ends with:

- A runnable build
- Passing automated verification
- Updated `STATUS.md`
- A short product evaluation checklist
- Known limitations
- Screenshots or recordings when UI behavior is material
- A clear next recommended increment

Do not leave partially integrated infrastructure when a smaller complete
vertical slice is possible.

## Safety and authorization

Autonomy does not authorize:

- Destructive cleanup without explicit confirmation
- Killing or throttling processes
- Installing privileged helpers
- Requesting broad privacy permissions without explanation
- Sending telemetry off-device
- Changing signing or distribution accounts
- Publishing releases

These require user involvement even when technically straightforward.

## Continuity

Because development may pause or move between tasks, keep these files current:

```text
README.md
VISION.md
FEATURES.md
ROADMAP.md
STATUS.md
ARCHITECTURE.md
ENGINEERING.md
PRIVACY.md
SECURITY.md
DECISIONS/
```

`STATUS.md` must always state:

- Current milestone
- What works
- How to run it
- How to test it
- Known issues
- Current risks
- Recommended next task

A new implementation task should be able to continue by reading the repository,
without relying on inaccessible conversation history.
