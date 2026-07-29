# HAL domain-language audit

Updated: July 29, 2026

HAL’s manifest-backed glossary now covers the domain terms currently repeated
across the overview, inspector, evidence, application-story, and planned shell
visualizer copy.

## Tooltip-enabled vocabulary

- application bundle, bundle identifier, and bundle installer
- package manager, Homebrew cask, runtime, and toolchain
- App Store receipt
- shell profile and PATH
- persistence / startup declaration
- rebuildable / reclaimable data
- observed, derived, inferred, and user-decided evidence
- PID, parent PID, resident memory, shared attributes, and observed instance

## Terms to review as their screens become user-facing

- canonical path and executable
- signing identifier, team identifier, and application group
- launch agent, launch daemon, and login item
- formula, keg, Caskroom, global package, shim, and symlink
- process, helper, service, runtime capability, and environment variable
- confidence levels: possible, probable, high, confirmed, and ambiguous

The UI should use `GlossaryAwareText` for prose and `GlossaryTermToggle` for
individual labels. This is the SwiftUI equivalent of a browser-wide string
observer: matching happens during declarative view rendering, so no mutation
observer or manual lifecycle listener is required.
