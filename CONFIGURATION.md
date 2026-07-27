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

The fixture validator runs as part of `make verify` and validates every
committed synthetic profile manifest. An invalid or stale manifest is a build
failure, not a runtime warning.

`SCHEMA_VERSIONING.md` defines compatibility, version increments, migrations,
and the required same-change updates across schemas, Swift projections,
fixtures, and documentation.

Collector roots, rebuildable-data locations, path categories, and other
growable detector knowledge must move into schema-validated manifests before
those features are enabled in the application. Security invariants remain in
code and cannot be weakened by manifest configuration.
