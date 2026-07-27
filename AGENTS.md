# HAL Repository Rules

These rules apply to every implementation task in this repository.

## Manifest-driven composition

- Always separate configuration, resource definitions, and composition from
  executable behavior.
- Do not define product entities, collectors, detectors, categories, paths,
  thresholds, display profiles, or other growable collections as hardcoded
  arrays or switches in application code.
- Small collections belong in versioned collection manifests. Complicated or
  independently discoverable items belong in individual manifest files.
- Every manifest format must have a centralized, versioned schema and explicit
  validation diagnostics.
- Code may implement generic behavior, adapters, validators, and schema-backed
  factories. Code must not be the source of truth for which resource instances
  exist.
- Rebuildable-data locations, protected paths, collector search roots, package
  ecosystems, and similar knowledge must be manifest resources rather than
  detector literals.
- Security invariants remain in code and cannot be disabled by ordinary
  manifests.

## Central schema

- Keep the complete system-profile schema and its validation utilities
  colocated in one clearly named module/directory.
- Use typed Swift decoding plus versioned schema validation. Do not introduce a
  JavaScript runtime solely to use Zod.
- Reject unknown keys and invalid enum values. Report paths to invalid fields.
- Schema changes require migration/version consideration and tests.

## Synthetic and live parity

- Synthetic profiles and live normalized scans implement the same schema.
- Any schema or structural change to real observations must update synthetic
  profiles in the same change.
- Build verification must validate every committed synthetic profile.
- Tests must fail, not merely warn, when a committed synthetic profile is
  structurally invalid or behind the required schema version.
- Synthetic profiles remain deterministic and must exercise unavailable,
  partial, ambiguous, and negative states as the real interface gains them.

## Data-source lifecycle

- The first launch uses the synthetic profile and performs no real collection.
- Linking a Mac is explicit, contextual, and read-only by default.
- Data-source choice is persisted as a user preference, separate from profile
  and collector definitions.
- Unlinking returns the app to the first-launch synthetic state. Once real user
  data exists, unlink must offer an explicit backup choice and a separately
  confirmed reset that removes HAL's compiled user data.
- Do not implement destructive reset behavior until exact storage scope,
  backup/export semantics, target validation, and safety tests exist.

## Review checklist

Before committing:

1. Could a new instance be added without editing Swift?
2. Is the relevant manifest schema versioned and validated?
3. Do synthetic profiles still validate against the live schema?
4. Is the new collector or rule selected through configuration?
5. Are observed, derived, inferred, and user-decided values still distinct?
6. Does ordinary app launch remain synthetic and non-collecting unless the user
   has explicitly linked the Mac?
