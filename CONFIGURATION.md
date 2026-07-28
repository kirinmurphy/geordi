# HAL Configuration Model

## Principles

- Configuration is typed and validated.
- Defaults live in one versioned location.
- Debug, test, and release environments are explicit.
- Business rules are not duplicated as UI constants.
- Security invariants cannot be disabled through ordinary user configuration.
- Unknown keys and invalid values produce clear diagnostics.

## Configuration layers

Lowest to highest precedence:

1. Versioned application defaults
2. Environment/mode defaults
3. User preferences
4. Explicit test overrides
5. Command-line overrides for supported diagnostic commands

## Initial Phase 0 configuration

- Environment mode
- Fixture scenario
- Initial visualization lens
- Animation/reduced-motion behavior
- Debug evidence visibility
- Layout tuning values
- Feature flags for incomplete UI experiments

Layout tuning belongs to a dedicated typed configuration object rather than
being scattered through drawing code.

## Later configuration

- Collector enablement and intervals
- Thresholds
- Retention and aggregation
- Protected and excluded paths
- Notification preferences and quiet hours
- Sensitive telemetry opt-ins
- Reclaim review preferences

## Nonconfigurable invariants

Ordinary settings must never disable:

- Broad-path protection
- Fresh target validation
- Shared/ambiguous data protection
- Required confirmation
- Privileged IPC authentication
- Audit recording for actions
- Secret redaction defaults without an explicit privacy-controlled capability

Redacted diagnostic export therefore uses a code-enforced allowlist for a
small set of bounded status and version values. Manifests cannot opt paths,
entity names, collector scopes, observation identifiers, or free-form evidence
into the default diagnostic.

## Storage

Use platform-appropriate preferences for simple user choices and a versioned
configuration representation for structured settings. Secrets, if ever needed,
belong in Keychain rather than configuration files.

Debug and Release preferences must be isolated by bundle identifier.

## Manifest composition

Growable collections and entity resources are versioned manifests, not Swift
arrays or entity-instance switches. Small related resources may share a
collection manifest. Complicated or independently discoverable resources use
individual manifest files.

`HALProfileSchema/Resources/system-profile.schema.json` is the canonical,
declarative Draft 2020-12 structural contract for synthetic and normalized
live system profiles. `HALProfileSchema/SystemProfileSchema.swift` is its
generic Swift validation adapter, typed decoder, semantic graph-integrity
validator, and domain projector. It does not maintain a second list of allowed
fields. Tests keep schema enums in parity with their Swift domain projections.
System-profile version 2 adds optional entity presentation metadata—symbol,
color role, subtitle, and trailing-detail selection—so fixture-specific
presentation remains in manifests rather than entity-identifier switches in
Swift.

The fixture validator runs as part of `make verify` and validates every
committed synthetic profile manifest. An invalid or stale manifest is a build
failure, not a runtime warning.

`HALFixtures/Resources/profile-catalog.json` is the versioned source of truth
for synthetic profile membership and ordering. Its adjacent JSON Schema rejects
unknown fields and invalid resource names. Every catalog entry must resolve to
a system-profile manifest with the same identifier, and validation fails for
both missing and uncataloged profile resources.

`SCHEMA_VERSIONING.md` defines compatibility, version increments, migrations,
and the required same-change updates across schemas, Swift projections,
fixtures, and documentation.

Collector roots, rebuildable-data locations, path categories, and other
growable detector knowledge must move into schema-validated manifests before
those features are enabled in the application. Security invariants remain in
code and cannot be weakened by manifest configuration.

The application inventory collector reads its default roots from
`HALCollectors/Resources/application-search-roots.json`, validated by the
adjacent `application-search-roots.schema.json`. System roots must be absolute.
User roots use the explicit `$USER_HOME/` token and cannot contain parent-path
traversal. Tests may still inject temporary roots directly without reading the
machine-wide defaults.

Homepage software categories, labels, ordering priority, fallback behavior,
and the default linked-data filter are defined by
`HALCollectors/Resources/application-classifications.json`, validated by its
adjacent versioned schema. The first rules classify bundle paths into User
Installed, Bundled Software, System Utilities, or Other / Unclassified.
Version 2 adds `platformBinaryWhenKnown`: observed platform-signature evidence
must agree with a category when configured, while unavailable signing evidence
preserves the explicitly weaker location-only classification. Classification
is a presentation aid and does not prove which person or installer placed an
application on the Mac.

Application provenance adapters are selected and labeled by
`HALCollectors/Resources/application-provenance-adapters.json`, validated by
its adjacent versioned schema. The current adapters observe App Store receipt
presence and retained download-origin metadata. Adapter manifests select
bounded collector implementations; they cannot add arbitrary executable code.

Conventional application-associated locations are defined by
`HALCollectors/Resources/application-associated-locations.json` and its
adjacent versioned schema. Templates are restricted to `$USER_HOME/` and the
explicit `$BUNDLE_ID` or `$APP_NAME` match token. Parent traversal, unknown
tokens, unsafe application-name components, and paths outside the resolved user
home are rejected. The manifest supplies resource instances and display
categories; code supplies only generic resolution, metadata inspection, and
evidence projection. Version 2 declares a small set of user-Library roots
whose immediate children may be enumerated, each with an explicit entry budget.
Enumeration never descends into a child. Unmatched children remain observations
without an application relationship. Version 3 permits group-container matches
only when the container name exactly matches an application-group identifier
from that application's validated code-signing entitlements. A team-ID prefix
or bundle identifier alone is never treated as group-container evidence.

Process-to-application strategies, the per-application presentation budget,
and the bounded unmatched-process retention budget are defined by
`HALCollectors/Resources/process-resolution-strategies.json` and its adjacent
versioned schema. Exact main-executable matches take priority over application
bundle containment. Version 2 adds `maxUnmatchedProcesses`; inaccessible
records rank first, followed by unmatched records by observed memory. These
records remain searchable and summarized in coverage without appearing as
disconnected nodes in the default atlas.

Rebuildable-data classifications, bounded tool-managed roots, descendant-name
exclusions, and evidence rules are defined by
`HALCollectors/Resources/rebuildable-data-detectors.json` and its adjacent
versioned schema. The initial contract names Xcode DerivedData, Homebrew
downloads, and npm cache roots but does not authorize collection or deletion.
Swift permanently rejects parent traversal, wildcards, NULs, unsafe exclusion
components, and resolved locations outside the configured user home. Linked-Mac
collection now performs one `lstat`-level metadata check per configured root.
It does not enumerate descendants, calculate sizes, read contents, or expose a
removal action. Present symbolic links are retained as limited observations and
are not projected as reclaim candidates.

Version 2 adds a required `measurementPolicy` contract for a future bounded
size collector. Its budgets and fixed filesystem safety semantics are described
in `SIZE_MEASUREMENT_CONTRACT.md`. The policy is validated today but is not yet
executed; the live collector still performs root metadata checks only.

Persistence search roots are defined by
`HALCollectors/Resources/persistence-roots.json` and its adjacent versioned
schema. The default scope includes the user and local-domain LaunchAgent and
LaunchDaemon directories, but excludes Apple’s `/System/Library` declarations
from the application-focused atlas. The collector reads only immediate plist
files and retains labels, declared executable paths, `RunAtLoad`, and
`KeepAlive`; full argument arrays are never normalized.
