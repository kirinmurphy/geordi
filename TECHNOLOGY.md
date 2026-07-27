# HAL Technology Decision

## Current decision

Use **Swift with SwiftUI/AppKit** for the macOS application, collectors, domain
model, and initial CLI.

Use:

- Swift Package Manager for modular code
- Xcode for the application and Apple platform integration
- SQLite for local history
- SwiftUI for application structure and standard interface elements
- Custom SwiftUI Canvas/Core Graphics rendering for the initial relationship
  map
- AppKit where SwiftUI does not provide sufficient macOS behavior
- Apple frameworks directly for supported native collection and services

Do not introduce a separate Go service, embedded runtime, privileged helper, or
system extension until a measured requirement justifies the additional
boundary.

## Why the decision changed

HAL was initially framed as a portable maintenance CLI with a future dashboard,
for which Go was the strongest choice. The product thesis evolved into a
macOS-first, deeply integrated, highly visual desktop application.

The architecture should follow the product actually being built.

HAL benefits from direct access to:

- Application bundles and metadata
- Security and signing APIs
- Notifications
- Service Management and login item registration
- FSEvents
- XPC
- Native permission and settings flows
- System extensions and Endpoint Security if later justified
- Accessibility, menus, windows, inspectors, and platform conventions
- Xcode signing, entitlement, and notarization workflows

Swift is the idiomatic ecosystem choice for those requirements.

## UI freedom

SwiftUI does not restrict HAL to predefined controls. The application can mix:

- Native sidebars, inspectors, windows, search, settings, and menus
- SwiftUI Canvas
- Core Graphics
- AppKit custom views
- SpriteKit
- Metal
- A web-rendered visualization embedded with WebKit

The initial relationship map should use a native custom canvas. If mature web
graph libraries provide a material product advantage, a WebKit visualization
can be introduced behind the same model boundary without replacing the native
application shell.

## Alternatives considered

### Go

Strengths:

- Standalone binaries
- Low overhead
- Strong concurrency
- Excellent CLI and local HTTP server
- Good cross-platform story
- Existing user familiarity

Why not current default:

- Native UI requires a third-party toolkit, web shell, or separate Swift layer.
- Deep Apple framework integration adds bridging and packaging complexity.
- A Swift UI plus Go service creates IPC, duplicated models, two toolchains, and
  harder signing before the boundary is necessary.

Go remains a valid future implementation language for another platform or a
demonstrably isolated portable service.

### Python

Strengths:

- Rapid prototyping
- Strong filesystem, SQLite, statistics, and data-analysis ecosystem

Why not current default:

- Runtime or bundled-distribution complexity
- Higher overhead for a resident collector
- Weaker fit for signing, native UI, system extensions, and Apple frameworks

Python remains useful for offline analysis experiments and fixture generation
when justified.

### Rust

Strengths:

- Low overhead
- Memory safety
- Strong native and security-sensitive systems work

Why not current default:

- Higher implementation complexity
- Less direct fit for SwiftUI/AppKit application development
- More engineering than the first milestones require

Rust may be appropriate for a narrowly isolated, performance-critical or
privileged sensor if measurement shows Swift is unsuitable.

### Web-first desktop frameworks

Strengths:

- Excellent visualization ecosystem
- Fast custom UI iteration
- Potential portability

Why not current default:

- Less direct macOS integration
- Added runtime and packaging layers
- Native permission, helper, accessibility, and background-service flows still
  require platform work

A web visualization inside the native app remains an option.

## Portability

Preserve portability at the conceptual boundaries:

- Domain entities
- Evidence and confidence model
- Collector protocols
- Findings and rules
- Export schemas
- Fixture formats

Do not force macOS-specific evidence into shallow cross-platform abstractions.
Future Windows or Linux versions would provide their own collectors and UI
decisions against a shared conceptual model.

## Data store

SQLite is preferred because HAL needs:

- Historical comparisons
- Many-to-many relationships
- Evidence queries
- Incident timelines
- Retention and aggregation
- Schema migrations
- One local, inspectable database

Access should be isolated behind a repository boundary so UI and collectors do
not embed queries throughout the codebase.

## Background collection

Progression:

1. Manual read-only scan
2. Periodic unprivileged snapshots
3. Supported background registration
4. Adaptive telemetry
5. Privileged/system extension only if proven necessary

Each step must measure HAL's own overhead and preserve a nonprivileged mode.

## Package structure direction

Exact names may change during scaffolding, but responsibilities should remain
separate:

```text
HALApp
HALDomain
HALPersistence
HALCollectors
HALRelationships
HALFindings
HALVisualization
HALActions
HALFixtures
HALCLI
```

Do not split code merely to create modules. Split when a boundary improves
cohesion, testing, dependency direction, or platform isolation.

## Decision review trigger

Revisit this decision only if evidence shows:

- Swift collection cannot meet required overhead.
- A cross-platform release becomes an active funded milestone.
- Native graph rendering cannot meet interaction requirements.
- A privileged component benefits materially from another language.
- Build and test automation becomes unacceptably fragile.

Until then, one language and one native ecosystem minimize project risk.
