# User Data Lifecycle

## Managed locations

HAL's current real-data milestone persists one file:

- `~/Library/Application Support/HAL/latest-live-snapshot.json`

The file is a normalized, versioned `GraphSnapshot` containing observed
application metadata, conventional associated-location paths, signing and
provenance details, evidence-bearing application/location relationships,
point-in-time process identifiers, executable paths, parent identifiers,
resident-memory values, application/process resolutions, collector outcomes,
startup declaration labels, executable paths, `RunAtLoad` and `KeepAlive`
states, application/persistence resolutions, and timestamps. Command arguments,
environment variables, and raw file contents are not collected.

Two preferences are stored in the app's `UserDefaults` domain:

- `dataSource.mode`
- `dataSource.syntheticWelcomeDismissed`

No SQLite database, logs, caches, credentials, background agents, or external
connectors are created by this milestone.

## Link

First launch is synthetic and performs no machine collection. Choosing
**Link to your Mac** runs the manifest-scoped application, signing, provenance,
associated-location, and point-in-time process collectors. HAL persists
`linkedMac` only after a successful snapshot is available. User/local launchd
property lists are read for a bounded persistence inventory; full program
arguments are not retained.

## Refresh

Linked startup loads the last snapshot when available and refreshes it.
Manual refresh is available in the sidebar and homepage. Refresh failure keeps
the last successful snapshot visible with an error; it never substitutes
synthetic data.

## Backup

**Export Backup, then Unlink** writes the last compiled snapshot atomically to
the location selected by the user. The export may contain private application
paths and should be handled as private metadata. HAL does not track or manage
the exported file afterward.

## Unlink and reset

**Delete Compiled Data and Unlink** removes only HAL's exact application-support
directory after rejecting root, home-directory, non-directory, and symbolic-link
targets. It resets the two data-source preferences and restores the
deterministic first-launch profile.

An elected backup is the only live information intentionally left behind, and
it is outside the app's scope. HAL never deletes applications or other machine
data.
