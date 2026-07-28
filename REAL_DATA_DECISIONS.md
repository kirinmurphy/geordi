# Real Data Implementation Decisions

This log records implementation decisions that were not already explicit in
the product discussion. They are reviewable; none should be treated as
irreversible product policy.

## 2026-07-27: first live milestone is application inventory only

Live mode shows application bundles and static signing evidence. It does not
show the synthetic storage, performance, incident, persistence, ownership, or
cleanup claims. Those navigation areas remain absent in live mode until their
own collectors and evidence models exist.

Reason: swapping a real application graph underneath a homepage containing
hardcoded synthetic alerts would make demo claims appear observed.

## 2026-07-27: linking performs immediate read-only collection

The preference changes to `linkedMac` only after the first collection succeeds.
A failed first collection leaves the app synthetic and explains the failure.
Subsequent refresh failures retain the last successful live snapshot and never
silently substitute a fixture.

## 2026-07-27: linked startup uses cache, then refreshes

On startup, a linked installation may render its last validated snapshot
immediately, then starts a new read-only refresh. The timestamp and freshness
state refer to the displayed snapshot. If no cache exists, the app displays an
empty pending live snapshot during refresh; synthetic entities are never shown
under a live label.

## 2026-07-27: compiled-data scope is intentionally narrow

The only compiled live artifact is
`Application Support/HAL/latest-live-snapshot.json`. Data-source mode and the
synthetic welcome dismissal are the only related preferences. Unlink removes
the HAL application-support directory, resets both preferences to first-launch
values, and restores the deterministic fixture.

An elected backup is a copy of the last normalized `GraphSnapshot`, written
atomically to a user-selected location outside HAL's managed scope. HAL does
not retain a pointer to that backup.

## 2026-07-27: collector paths use explicit tokens

System roots are absolute manifest paths. User-relative roots use
`$USER_HOME/`; arbitrary environment-variable and tilde expansion are not
supported. This keeps configuration deterministic and prevents accidental path
interpretation.

## 2026-07-27: synthetic profile catalog is closed over bundled manifests

The versioned profile catalog defines synthetic profile membership and ordering
by identifier and resource name. Catalog validation requires every entry to
resolve to a profile with the same identifier and rejects both missing entries
and uncataloged bundled profiles.

Reason: this makes the catalog the complete composition source of truth while
preventing a newly committed fixture from silently escaping build validation.

## 2026-07-27: download provenance is redacted before normalization

The download-origin adapter reads the existing
`com.apple.metadata:kMDItemWhereFroms` extended attribute, but retains only
unique hostnames. URL paths, queries, fragments, and the raw attribute are not
placed in observations or compiled snapshots. Missing metadata is represented
as not retained and does not imply that an application was a web download.

The App Store adapter records only whether the conventional bundle receipt file
exists. It does not read or retain receipt contents.

## 2026-07-27: first file associations are conventional metadata observations

The first associated-location collector resolves a bounded manifest of
conventional user-Library paths for each observed application. It uses
`lstat`-level metadata only, does not enumerate or descend into those locations,
does not read contents, does not calculate sizes, and never performs cleanup.

An exact bundle-identifier path is a strong conventional association, not proof
of current use or exclusive ownership. Application-name matches are weaker.
Both are projected as **may belong to** relationships with their match rule and
filesystem observation preserved as separate evidence. Missing, unreadable,
and permission-denied candidates remain collector outcomes even though only
present locations become graph nodes.

Group containers are deferred until HAL collects team/group identifiers.
Guessing them from the application bundle identifier would overstate ownership.

The version 2 associated-location manifest adds bounded immediate-child
enumeration for selected user-Library roots. Every root has an explicit entry
budget, enumeration skips descendants, and a budget stop is a partial collector
outcome. Exact application identifiers may support the same conventional
relationship as an exact candidate. Unmatched children are retained without a
relationship. Group-container children are retained with an explicit
group-identifier-unavailable basis and no ownership candidate.

## 2026-07-27: the primary atlas is relevance-bounded

Collector completeness and graph prominence are separate concerns. HAL may
retain ordinary components, paths, negative observations, and technical
metadata without rendering each record as a default graph node.

The primary atlas prioritizes observed relationships that explain current
activity, startup behavior, meaningful data associations, qualified resource
outliers, and uncertainty that changes the explanation. Repetitive ordinary
records are grouped, and deep signing, provenance, entitlement, component, and
path metadata remains accessible through progressive disclosure.

Display budgets, relationship priorities, confidence floors, and grouping
rules must be schema-validated manifest resources. They cannot silently discard
observations, evidence, unmatched records, permission failures, or uncertainty.
For this read-only milestone, “actionable” means a clear next investigation or
explanation, not a machine-changing control.

## 2026-07-27: process snapshots use bounded `ps` fields

The first point-in-time process adapter invokes `/bin/ps` with only PID, parent
PID, resident-memory, and executable-name/path fields. It does not request
command arguments or environment variables. The snapshot is foreground,
read-only, and runs only during explicit link or refresh collection.

Exact application main-executable matches are confirmed; executables contained
inside an application bundle are strong derived matches. Unmatched,
inaccessible, and ambiguous records remain normalized observations. The
primary graph shows only uniquely matched processes and applies the
manifest-defined per-application budget, ranked by observed resident memory and
then PID for determinism.

## 2026-07-28: persistence collection is application-focused

The first persistence collector reads immediate plist declarations from the
user and local `/Library` LaunchAgent and LaunchDaemon roots selected by
manifest. Apple’s `/System/Library` declarations are excluded from the default
application atlas to avoid overwhelming it with operating-system infrastructure.

HAL retains only the declaration label, first executable, `RunAtLoad`, and
`KeepAlive`. It never retains the remaining `ProgramArguments`, which may
contain sensitive values. A persistence node enters the primary graph only
when its absolute executable path is contained inside an observed application
bundle. Unmatched and malformed declarations remain collector outcomes rather
than default graph nodes.

## 2026-07-28: homepage software scope is location-inferred

The linked homepage defaults to applications found in `/Applications` and the
current user's `Applications` directory. Applications under macOS system
locations are separated into Bundled Software and the more specific System
Utilities category. Records outside recognized locations remain visible under
Other / Unclassified and All Applications.

These categories, their labels, matching priority, path rules, fallback, and
default selection are a schema-validated manifest rather than presentation-code
switches. “User Installed” is concise interface language for apps outside
macOS system locations; HAL explicitly does not treat folder location as proof
of who installed an app. Platform-signature evidence can refine this
classification later without changing the filter contract.

## 2026-07-28: refresh change detection compares normalized graphs

Manual **Check this Mac again** collection reruns the same configured read-only
collectors while leaving the last successful graph interactive. HAL reports
whether the newly normalized graph differs from the displayed graph and records
the check time and duration in the interface.

Scan identifiers, collection timestamps, and collector-run timing do not by
themselves count as a displayed change. This prevents every refresh from
claiming an update merely because it produced a new scan envelope.

## 2026-07-28: cancelling initial link invalidates its collection generation

Initial link runs behind a focused setup overlay while the fictional profile
remains the committed data source. Cancelling requests task cancellation and
invalidates the collection generation. A collector that cannot stop
immediately may finish its read-only work, but HAL ignores that late result and
does not save it or switch data-source mode.
