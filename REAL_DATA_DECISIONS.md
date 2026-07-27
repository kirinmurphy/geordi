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
