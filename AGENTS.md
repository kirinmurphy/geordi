# Geordi Repository Rules

## Unified project

- This repository contains the desktop app (`Sources/`, `Tests/`), CLI
  (`bin/`, `cli/`), and Mac setup engine (`bootstrap/`). Do not split these
  into separate repositories.
- Product identity belongs in the versioned product-brand manifest, not
  duplicated UI strings, launch scripts, or CLI command registries.
- CLI sidekicks retain the admission and safety rules in `cli/AGENTS.md`.
- Bootstrap inventory refresh is explicit and read-only with respect to the
  machine. Package installation requires an explicit apply action and
  confirmation; never uninstall packages merely to match the manifest.
- Keep observed installed inventory distinct from desired bootstrap defaults.
- Verify desktop, CLI, and bootstrap together after cross-cutting changes.
  Preserve synthetic-first desktop launch behavior.

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
- The canonical structural contract must be a declarative, versioned JSON
  Schema resource. Swift types are projections of that contract, not a second
  independently maintained structural schema.
- Use typed Swift decoding plus versioned schema validation. Do not introduce a
  JavaScript runtime solely to use Zod.
- Swift may enforce semantic invariants that JSON Schema cannot express
  cleanly, such as unique graph identifiers and valid relationship endpoints.
  It must not duplicate field lists, required keys, or enum sets.
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

## Working with Esteban (collaboration protocol)

Esteban is the product owner; the agent owns implementation detail. He thinks
in CLI terms (experienced CLI designer), has never built a Swift app, and wants
outcomes, not process narration.

- **Ownership.** Esteban decides what and why; the agent decides how. Do not
  surface implementation choices as questions — resolve them, record the
  decision, and move on.
- **Decision protocol.** For every decision: evaluate the options, their pros
  and cons, and pick a clear winner. Decisions with a dominant option are
  decided unilaterally and documented (commit message, plan doc, or skill
  note). Decisions that are genuinely subjective — strong pros AND strong cons
  on both sides with no clear winner — are BLOCKED and block all dependent
  tasks until discussed with Esteban. Do not guess on blocked decisions.
- **Run to the wall.** Keep working until every remaining task is either done
  or blocked. No periodic check-ins, no stopping on open questions while other
  work remains. When work ends, deliver ONE outcome-first summary; batch all
  blocked decisions together at that point, each with its pros/cons laid out.
- **Learning moments.** Geordi exists so Esteban can understand his computer.
  When implementation touches a transferable concept (app bundles, code
  signing, sandboxing, notifications, storage, the window/view lifecycle…),
  treat the concept as a potential product surface: implement it directly if
  complexity is low, otherwise write it up as a candidate feature. Explain
  concepts in chat in layperson terms when relevant.
- **Self-audit.** The agent is responsible for its own quality without being
  asked: at task start, discover and load relevant skills (code standards,
  testing, auditing, CLI UX — search by keyword, don't assume a fixed list)
  plus the in-repo standards (`cli/AGENTS.md`,
  `references/cli-ux-conventions.md`, the `geordi-project` skill), apply them
  to every change, and summarize audit results in the final summary.
- **Technical register.** CLI-side discussion can assume a technical peer;
  desktop/Swift topics start at layperson level and build up.

## Review checklist

Before committing:

1. Could a new instance be added without editing Swift?
2. Is the relevant manifest schema versioned and validated?
3. Do synthetic profiles still validate against the live schema?
4. Is the new collector or rule selected through configuration?
5. Are observed, derived, inferred, and user-decided values still distinct?
6. Does ordinary app launch remain synthetic and non-collecting unless the user
   has explicitly linked the Mac?
