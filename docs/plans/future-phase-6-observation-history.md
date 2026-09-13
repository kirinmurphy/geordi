# Future Phase 6 — Local Observation History and Parser Feedback

Status: deliberately parked  
Earliest reconsideration: after the next user-facing product-validation phase

## Why this is not next

geordi has not yet proved that its current inventory, application explanation, and
maps are compelling enough to justify more persistence infrastructure.
Observation History would add schemas, retention, migration, recovery,
redaction, and UI obligations before the core product story is validated.

Do not begin this phase merely because collector runs already produce useful
diagnostics.

## Intended user outcome

Users can understand noteworthy changes across observation runs without seeing
notification spam or confusing parser limitations with Mac problems.

The user-facing name is **Observation History**, not telemetry.

## Candidate scope

- Versioned, bounded run-history schema
- Run identifiers and timestamps
- Collector identifiers and versions
- Complete, partial, failed, and unavailable states
- Stable issue reason codes and privacy-safe structural fingerprints
- Added, removed, and reclassified software summaries
- Acknowledgment and resolution state
- Recognition that a newer collector version handled an earlier structure
- Explicit, previewable redacted export

## Privacy and safety requirements

- Store locally by default.
- Never upload automatically.
- Do not retain arbitrary file contents, command arguments, usernames, or raw
  paths for parser feedback.
- Aggregate repeated instances.
- Bound storage with explicit retention and size limits.
- Keep unredacted diagnostic detail separately scoped and short-lived.
- Require explicit user action to export or share feedback.

## Entry requirements

Reconsider this phase only when:

1. user testing demonstrates that change-over-time is a top unmet question;
2. the product can state which events are worth retaining;
3. retention, migration, corruption recovery, and export redaction are
   designed;
4. the history UI has a clear job beyond exposing collector logs; and
5. the work outranks user-facing improvements possible with current data.

## Acceptance criteria

- No history leaves the Mac without explicit user action.
- Storage is bounded, versioned, migratable, and recoverable.
- Repeated issues are aggregated.
- Non-actionable issues remain subtle.
- A user can distinguish software change from collection-quality change.
- A developer can reproduce a parser shape without receiving private content.

## Deferred engineering tasks

- Choose the persistence technology and migration strategy.
- Specify retention and compaction.
- Define fingerprints for each collector family.
- Add corruption and partial-write recovery.
- Add export preview and redaction tests.
- Add the Observation History interface.

No implementation is authorized by this plan while its status remains parked.
