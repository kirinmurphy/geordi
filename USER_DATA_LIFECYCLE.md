# User Data Lifecycle

## Managed locations

HAL's current real-data milestone persists one file:

- `~/Library/Application Support/HAL/latest-live-snapshot.json`

The file is a normalized, versioned `GraphSnapshot` containing observed
application metadata, filesystem paths, signing evidence projected as details,
collector outcomes, and timestamps. No raw file contents are collected.

Two preferences are stored in the app's `UserDefaults` domain:

- `dataSource.mode`
- `dataSource.syntheticWelcomeDismissed`

No SQLite database, logs, caches, credentials, background agents, or external
connectors are created by this milestone.

## Link

First launch is synthetic and performs no machine collection. Choosing
**Link to your Mac** runs the manifest-scoped application and signing
collectors. HAL persists `linkedMac` only after a successful snapshot is
available.

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
