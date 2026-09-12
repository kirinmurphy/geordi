# geordi Development Environment

## Verified machine

Verified on July 26, 2026:

```text
macOS: 26.5.2 (25F84)
Architecture: Apple Silicon arm64
Swift: 6.3.3
Git: 2.50.1
Command Line Tools: 26.6
Active developer directory: /Library/Developer/CommandLineTools
```

## Xcode prerequisite

Resolved on July 26, 2026. Full Xcode 26.6 is installed and selected:

```text
/Applications/Xcode.app/Contents/Developer
Xcode 26.6 (17F113)
Swift 6.3.3
```

The project is a Swift package that opens directly in Xcode. Select the
`GeordiApp` scheme. This avoids generated project metadata while retaining Xcode
build, debug, and Apple-platform integration.

The stable Debug installation is `~/Applications/geordi.app`. `make run` refreshes
that bundle on every invocation, so Spotlight and a Desktop shortcut remain
valid across development updates. It also stops any running geordi development
copy before replacing the bundle, launches exactly one installed copy, and
records that process in `.build/geordi-dev.pids`. You do not need to quit or reopen
geordi separately after source changes; use `make run` once. geordi also enforces
single-instance behavior inside the application: launching another development
bundle activates the existing process and immediately terminates the duplicate.

## Repository location

Permanent project:

```text
~/projects/geordi
```

Debug build data:

```text
~/Library/Application Support/geordi-Dev
~/Library/Caches/geordi-Dev
~/Library/Logs/geordi-Dev
```

Future Release data:

```text
~/Library/Application Support/geordi
~/Library/Caches/geordi
~/Library/Logs/geordi
```

Debug and Release must use distinct bundle identifiers and never share mutable
databases or preferences.

## Environment modes

### Synthetic

- Default throughout Phase 0
- Deterministic fixtures
- No real collectors
- No real mutations
- Visible environment label

### Live read-only

- Introduced in Phase 1
- Real collectors
- Separate development database
- No cleanup, process control, helper installation, or persistence changes
- Visible environment label

### Controlled actions

- Introduced only after dry-run plans and safety tests
- Explicitly enabled capabilities
- Target-by-target confirmation
- Trash/recovery preference
- Audit trail

### Release

- Separate identity and data
- Signed, hardened, and eventually notarized
- Only required permissions

## Development conventions

- Use Swift Package Manager for reusable modules.
- Use Xcode for the app target, signing, UI tests, and Apple integrations.
- Prefer Foundation, SwiftUI, AppKit, XCTest, and other native libraries before
  adding dependencies.
- Use Swift's strict concurrency checks.
- Use deterministic fixtures for UI development.
- Keep generated build products and user-specific Xcode state out of Git.
- Never require live system mutation to run the ordinary test suite.

## Standard commands

The repository provides these stable wrappers:

```text
make build
make test
make test-unit
make test-ui
make verify
make run
```

The wrappers may call `xcodebuild` and `swift`; product documentation should not
require users to remember lengthy implementation-specific commands.

`make test-ui` is currently a native launch smoke test. Accessibility
identifiers establish the boundary for richer XCUITest journeys when a
conventional app test runner is warranted. `make build` also packages the Swift
executable as `.build/debug/GeordiApp.app`; `make run` opens that bundle through
LaunchServices rather than running the executable directly.

## Optional development tools

Formatting and linting should be automated, but third-party tools are not
currently installed. During scaffolding, evaluate native `swift format` support
before adding SwiftFormat or SwiftLint.

The current prototype has no third-party dependencies. Formatting uses the
`swift-format` bundled with Xcode.
