# Real Machine Data Field Availability Matrix

This reference classifies the important data geordi currently presents or plans to
present. The implementation sequence and architectural plan live separately in
`REAL_DATA_ASSESSMENT.md`.

## Classification legend

- **Directly observable**: available as a current platform fact from an API,
  filesystem record, system database, or read-only command.
- **Deterministically derived**: reproducible from specified observations and a
  versioned rule without judgment.
- **Heuristically inferred**: a plausible correlation that must preserve
  uncertainty and supporting evidence.
- **Requires historical collection**: unavailable from a single current
  snapshot.
- **Requires elevated permission or user consent**: gated by TCC, entitlements,
  privilege, sensitive-data policy, or explicit product consent.
- **Not realistically available**: cannot be complete or reliably established
  on an arbitrary Mac.
- **Currently hardcoded/demo-only**: authored in Phase 0 fixtures or UI.

More than one classification can apply to a field.

## Applications and installed software

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Bundle path and existence | Directly observable | `FileManager` enumeration of standard system, shared, and user application directories; Spotlight as supplemental discovery | User locations can be unavailable. Spotlight and `system_profiler` should not be canonical identity sources. |
| Name, icon, bundle identifier, version, build, executable | Directly observable | `Bundle`, `Info.plist`, `NSWorkspace` | Metadata can be absent, malformed, localized, or duplicated. |
| Logical and allocated bundle size | Deterministically derived | `URLResourceValues` and bounded filesystem traversal | Potentially expensive; APFS clones, sparse files, compression, and hard links require explicit size semantics. |
| Installed now | Directly observable | Successful current enumeration within a declared scope | Absence outside a complete scope does not mean removed. |
| Removed, new, or updated | Requires historical collection; deterministically derived | Compare durable identities and versions across completed scans | Requires scan completeness and history. |
| Running or stopped | Deterministically derived | Correlate process executable/bundle paths with current inventory | Point-in-time only; must carry an observation time. |
| Signing identifier, Team ID, authorities, signature validity | Directly observable | Security framework: `SecStaticCode`, `SecStaticCodeCheckValidity`, `SecCodeCopySigningInformation` | Signature identity is not user trust, application ownership, or safety. |
| Apple/system classification | Deterministically derived | Platform signature plus protected system location and metadata | Preserve the component facts; path alone is insufficient. |
| App Store provenance | Directly observable or deterministically derived | App receipt and bundle metadata | Receipt may be missing or invalid; do not retain account-related content. |
| Installer-package provenance | Directly observable or heuristically inferred | Installer receipts, package metadata, BOM records, `pkgutil` adapter | Package-to-app mapping can be ambiguous. |
| Homebrew provenance | Directly observable or deterministically derived | Homebrew JSON output and Caskroom/Cellar metadata | Multiple prefixes and versions are possible; prevent automatic updates. |
| Web download or disk-image provenance | Heuristically inferred; sometimes directly observable | Quarantine extended attributes and download-origin metadata | Frequently missing after copy, move, or metadata stripping. |
| User approval and trust | Not realistically available as observation | geordi decision history | Never infer from source, signature, or Gatekeeper status. |
| Current fixture footprint, source, state, and summaries | Currently hardcoded/demo-only | Fixture literals | Retain for demonstrations only. |

## Processes and runtime activity

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| PID, PPID, UID, executable path, start time | Directly observable | `libproc` and `sysctl` where needed | Processes can disappear during collection; PID alone is not identity. |
| Process name and current bundle association | Directly observable or deterministically derived | `libproc`, `NSRunningApplication`, executable-to-containing-bundle resolution | `NSWorkspace.runningApplications` does not cover every helper or non-GUI process. |
| Current parent/child relationship | Directly observable | PPID in a process snapshot | Parent may have exited; PID reuse must be handled. |
| Current application/process association | Deterministically derived | Exact main executable or executable containment inside an observed application bundle | Implemented for one point-in-time snapshot; unmatched, inaccessible, and ambiguous records are preserved. |
| Historical launch ancestry | Requires historical collection | Process event collection or sufficiently frequent snapshots | Snapshots miss short-lived processes. |
| CPU and memory now | Directly observable or deterministically derived | `proc_pid_rusage`, Mach host/task/process APIs | CPU requires a measurement interval; detailed records may be restricted. |
| Arguments | Directly observable where accessible; requires consent | Process APIs with strict filtering | Sensitive and incomplete. Disabled by default under `PRIVACY.md`. |
| Executable hash | Deterministically derived | Streaming CryptoKit hash | I/O cost; changes normally after updates and is not durable identity. |
| Every start and exit | Requires historical collection and elevated capability | Endpoint Security only if later justified | Do not require this for the initial atlas. |
| Current fixture processes and resource values | Currently hardcoded/demo-only | Fixture literals | Not measurements. |

## Login items, agents, daemons, helpers, and persistence

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| LaunchAgent or LaunchDaemon plist and declared fields | Directly observable | Property lists in user/system launch directories and embedded bundle locations | Parse malformed data safely; arguments can be sensitive. |
| Label, program, arguments, triggers, `KeepAlive` | Directly observable | Property list | Declaration is not current runtime state. |
| Enabled or approved status | Directly observable where supported; otherwise incomplete | `SMAppService` status and legacy status API; versioned `launchctl` adapter if needed | Service Management is not a universal enumerator for every third-party item. |
| Loaded and running state | Directly observable | Launchd domain inspection plus process correlation | Loaded, approved, scheduled, and running are different states. |
| Embedded login items, XPC services, and helpers | Directly observable | Bundle `Contents/Library` and helper directories | Containment supports association but not exclusive ownership. |
| Privileged helpers | Directly observable; sometimes permission-limited | `/Library/PrivilegedHelperTools`, launchd declarations, signatures | Complete state may be restricted. |
| Persists through | Directly observable or deterministically derived | Explicit persistence declaration naming an executable | App association can remain inferred. |
| Current application/persistence association | Direct declaration observation plus deterministic containment | User/local launchd plist executable contained in an observed application bundle | Implemented for immediate plist declarations; approval, loaded, and running state remain separate and unavailable. |
| Orphaned persistence | Requires historical collection; heuristically inferred | Complete previous app inventory plus current persistence | Missing app evidence is not automatically proof of orphaning. |
| Current fixture persistence explanations | Currently hardcoded/demo-only | Fixture relationships | Retain as narrative coverage. |

## Files, application data, caches, logs, configuration, and documents

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Path, type, permissions, owner, timestamps, flags, extended attributes | Directly observable | `FileManager`, `stat`/`lstat`, `getxattr`, `URLResourceValues` | TCC and Full Disk Access can block locations. Never follow symlinks silently. |
| Logical, allocated, and aggregate size | Directly observable or deterministically derived | Resource values and bounded traversal | Potentially expensive and affected by APFS semantics. |
| Cache, log, configuration, or support category | Deterministically derived or heuristically inferred | Known roots and versioned path rules | Arbitrary names are weak evidence. |
| User document or project classification | Heuristically inferred; sometimes directly observable by selected scope | User-selected roots, declared document types, conventional directories | File contents should not be inspected for ordinary classification. |
| Last modified | Directly observable | Filesystem metadata | Not the same as last used. |
| Recently used or stale | Requires historical collection; heuristically inferred | geordi observation history plus weak filesystem evidence | Access time is often unreliable. |
| Reads or writes relationship | Requires historical collection; often elevated | FSEvents for coarse changes; Endpoint Security for later high-fidelity attribution | FSEvents does not reliably identify the writing process. |
| Exact ownership | Deterministically derived for containment and authoritative package paths; otherwise inferred | Bundle containment, receipts, containers, bundle-ID conventions, historical writers | Shared support and documents often have multiple consumers. |
| Current conventional application association | Direct path observation plus derived or inferred match | Manifest-selected user-Library candidates using exact bundle IDs or application names | Implemented metadata-only; exact bundle-ID paths are strong associations, name matches are weak, and neither proves current access or exclusive ownership. |
| Application footprint | Deterministically derived over qualified relationships, but incomplete | Sum explicitly associated items with deduplication rules | Present as “observed associated footprint,” not complete ownership. |
| Current fixture sizes, rebuildability, protection, and removal text | Currently hardcoded/demo-only | Fixture literals | These are demo findings, not machine facts. |

## Package managers, packages, and shell frameworks

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Homebrew prefixes, Cellar, Caskroom, cache | Directly observable or deterministically derived | Known roots and read-only Homebrew commands | Multiple installations and architectures are possible. |
| Installed formulae, casks, versions, dependencies | Directly observable | Homebrew JSON and metadata | Adapter must be versioned and time-bounded. |
| npm global packages | Directly observable | `npm root -g`, `npm ls -g --json`, package metadata | Version managers create multiple environments and roots. |
| Other ecosystems | Directly observable per manager | Manager-native read-only databases or JSON | “All packages” is not realistically complete. |
| Oh My Zsh installation, Git version, and plugins | Directly observable or deterministically derived | Framework directory, Git metadata, redacted `.zshrc` references | Shell configuration can contain secrets; do not retain full content. |
| Framework active in a shell | Heuristically inferred or requires history | Redacted configuration references; process environment only with consent | Often unavailable and sensitive. |
| Package launches or reads another package | Heuristically inferred or requires history | Executable provenance, dependency metadata, runtime observation | Install dependency does not prove runtime use. |
| Current fixture package footprints and edges | Currently hardcoded/demo-only | Fixture literals and authored relationships | Retain for deterministic UX tests. |

## CPU, memory, storage, and network resources

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Host CPU usage and load | Directly observable or deterministically derived | Mach host statistics | Percentage requires an interval. |
| Physical memory, pressure, and swap | Directly observable | Mach VM statistics and `sysctl` | A single reading does not define an incident. |
| Per-process CPU, memory, and I/O | Directly observable or deterministically derived | `libproc`, `proc_pid_rusage`, repeated samples | Permission and process-exit failures are normal. |
| Volume capacity and available space | Directly observable | Volume resource values and `statfs` | Raw free and available-for-important-usage are different. |
| Network interface totals | Directly observable or deterministically derived | Interface counters | Lower sensitivity at aggregate level. |
| Per-process destinations and sockets | Requires consent/elevated capability; incomplete | Later Network Extension or privileged inspection | Explicitly deferred by current privacy policy. |
| Baseline, peak, anomaly, and sustained pressure | Requires historical collection; derived or inferred | geordi time series and versioned rules | Requires retention, sampling intervals, gaps, and sleep handling. |
| Current activity and incident fixture values | Currently hardcoded/demo-only | Fixture/UI values | Not observations. |

## Events and incidents

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Scan start, completion, partial result, and failure | Directly observable | Collector orchestration clock and result | Must be first-class. |
| Wake and sleep | Requires historical collection | `NSWorkspace` notifications or IOKit while geordi runs | No complete retroactive history. |
| Application install, update, and removal | Requires historical collection; deterministically derived | Completed snapshot comparison; FSEvents as a trigger only | Scope and scan completeness matter. |
| Process start and exit | Requires historical collection | Snapshot observation initially; Endpoint Security later if justified | Say “first observed” when exact start was not seen. |
| File change and growth | Requires historical collection; deterministically derived | Size snapshots; FSEvents for rescan scheduling | Event streams can coalesce or drop events. |
| Incident start, duration, and peak | Requires historical collection; deterministically derived | Versioned threshold state machine | Threshold and rule version are evidence. |
| Contributing process ranking | Deterministically derived but incomplete | Time-aligned resource samples | Describe as largest observed contributor, not cause. |
| Occurred near | Deterministically derived from history | Versioned time-window rule | Temporal proximity does not imply causation. |
| Caused incident | Not realistically available in general | None | geordi should report correlation and possible triggers only. |
| Current events, incidents, times, and durations | Currently hardcoded/demo-only | Fixture literals | Useful scenario coverage, not history. |

## Signing, receipts, provenance, ownership, evidence, and confidence

| Concept or field | Classification | Preferred source | Constraints |
|---|---|---|---|
| Static signature and Team ID | Directly observable | Security framework | Validate before relying on signature information. |
| Package receipt and claimed paths | Directly observable | Installer receipt database, BOM data, package adapter | Receipts can be stale or incomplete. |
| Download origin | Directly observable when retained; otherwise unavailable | Quarantine metadata | Not durable. |
| Durable application identity | Deterministically derived from multiple facts | Bundle ID, Team ID, path, receipt, optional version, hash for exact comparison | No single field is sufficient in every case. |
| Exclusive ownership | Not realistically available for arbitrary external files | Authoritative containment/receipt where possible | Otherwise preserve association and ambiguity. |
| Evidence | Directly observable or derived | Immutable observation references | Needs source, time, schema, quality, and redaction metadata. |
| Confidence | Deterministically computed or heuristically assigned | Versioned resolver over evidence | Must not be synonymous with observed versus inferred. |
| Current evidence summaries and confidence | Currently hardcoded/demo-only | Fixture relationships | Current tests verify presentation honesty, not real resolution quality. |

## Relationships

| Relationship | Classification | Required interpretation |
|---|---|---|
| `owns` | Direct or deterministic only for authoritative containment; otherwise inferred | Prefer narrower assertions such as contains, installed path, or associated with. |
| `launches` | Direct when parent/exec was observed; otherwise historical or inferred | A declared helper means can launch, not observed launch. |
| `reads/writes` | Requires history; often elevated | Precise runtime attribution should be deferred. |
| `persists through` | Directly observable or deterministic | Keep persistence declaration separate from app ownership. |
| `consumes` | Directly observable or deterministic | Always interval-specific. |
| `contributes to` | Deterministic or inferred | Arithmetic storage contribution differs from incident correlation. |
| `occurred near` | Deterministically derived from historical timestamps | Never imply cause. |
| `may belong to` | Heuristically inferred | Preserve competing candidates and evidence. |
| `shares` | Deterministic with authoritative multiple references; otherwise inferred | Default shared or ambiguous targets to protected. |

## Reclaimability and safe-action decisions

| Concept or field | Classification | Constraints |
|---|---|---|
| Item size | Directly observable or deterministic | Does not imply reclaimability. |
| Rebuildable or redownloadable | Deterministic for manager-native caches; otherwise inferred | Requires detector-specific versioned rules. |
| User or shared data | Direct in limited authoritative locations; otherwise inferred | Uncertain data defaults to protected. |
| Current use | Direct at scan time; recent use requires history | Must show observation age. |
| Expected reclaimed bytes | Deterministically derived but approximate | Allocated size, clones, hard links, and concurrent changes matter. |
| Keep, review, removable, protected | Derived finding or policy decision | Never collector output. |
| Safe to remove | Not realistically available as an unconditional fact | Depends on intent, use, backup, sharing, app semantics, and fresh validation. |
| Cleanup | Explicitly deferred | No delete, trash, uninstall, or mutation in initial real-data phases. |
| Current reclaim totals and explanations | Currently hardcoded/demo-only | Retain only as fixture findings. |
