# HAL Testing Strategy

## Goals

- Make product behavior deterministic without depending on the live Mac.
- Test explanation and uncertainty as seriously as data collection.
- Prove cleanup safety before real cleanup exists.
- Measure HAL's own resource cost.
- Keep the fast test loop small enough to run continuously.

## Test layers

### Domain unit tests

Cover:

- Entity identity
- Relationship direction
- Confidence calculation
- Evidence aggregation
- Trust and presence dimensions
- Reclaimability and risk
- Findings
- Explanation generation
- Configuration validation

### Fixture contract tests

Every fixture must:

- Validate against the fixture schema
- Use stable identifiers and timestamps
- Produce an expected normalized graph
- Produce expected explanations and findings
- Include negative and ambiguous cases

### Visualization tests

- Deterministic layout snapshots
- Selection and highlighted paths
- Filtering
- Search focus
- Zoom bounds
- Empty, dense, and ambiguous states
- Accessibility labels
- Reduced-motion behavior

Visual snapshots should test semantic layout and important presentation states,
not every anti-aliased pixel.

### Persistence tests

Beginning when SQLite is introduced:

- In-memory or temporary databases
- Migrations from every supported schema
- Transaction behavior
- History comparisons
- Retention and aggregation
- Corruption/error handling

### Collector tests

Beginning in Phase 1:

- Recorded and synthetic command/API responses
- Malformed and partial data
- Permission-denied capability status
- Stable normalization
- Live tests opt-in and read-only

### Safety tests

Before any action feature:

- Broad path refusal
- Symlink behavior
- Shared ownership
- Missing target
- Target replacement after planning
- Protected paths
- Interrupted action
- Recovery information
- Audit records

All action tests operate inside unique temporary fixture roots.

### UI tests

Cover a small number of critical user journeys:

- Open fixture
- Search for an application
- Trace application to process and files
- Inspect evidence
- Understand ambiguous ownership
- Switch fixture scenarios

### Performance tests

Track:

- Application launch
- Fixture load
- Layout time
- Pan/zoom responsiveness
- Memory use
- Database growth
- Collector duration
- Background idle overhead

Set budgets only after measuring an initial implementation; do not invent
arbitrary thresholds.

## Harness requirements

- A fixture browser available in Debug builds
- A command-line fixture validator
- Seeded layout behavior
- Temporary filesystem builders
- A deterministic clock abstraction where time affects behavior
- Capability and permission simulation
- Failure injection for collectors and repositories
- Exportable diagnostics for failed UI scenarios

## Continuous verification

`make verify` should eventually run:

1. Formatting check
2. Static analysis/linting
3. Swift package tests
4. Application unit tests
5. Fixture validation
6. Safety tests
7. Build

UI and live integration suites may be separate when their runtime would make the
standard loop impractical, but CI or release verification must run them.

## Phase 0 implementation

`make verify` currently runs:

1. Strict `swift-format` lint
2. Eleven deterministic domain, fixture-contract, and visualization tests
3. Validation of all four versioned fixture graphs
4. A complete Debug build
5. Native application-bundle structure and identity validation

The harness verifies that the SwiftUI executable is packaged as an `APPL`
bundle with the isolated Debug identity `com.hal.dev`. Critical controls
include accessibility identifiers and labels. Full interaction-level XCUITest
and automated LaunchServices presentation remain known Phase 0 harness
limitations; product evaluation is manual using the checklist in `STATUS.md`.

## Real-machine policy

- Ordinary tests do not read private user directories.
- Live tests are explicitly named and invoked.
- Live tests are read-only until a separately authorized action suite exists.
- Test output redacts local usernames and sensitive paths where practical.
- No test installs an agent, daemon, extension, or login item by default.
