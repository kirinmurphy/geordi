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
