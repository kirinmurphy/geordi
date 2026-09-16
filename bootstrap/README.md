# Geordi Mac bootstrap

Dependency-free Node.js 20+ subproject, called by `geordi setup mac`.

Commands and fresh-Mac prerequisites: [USAGE.md](USAGE.md).

---

## Catalog and machine manifest

Two documents with different jobs (see
`docs/plans/setup-registration-and-gui.md`):

| Document | Contents | Location | Portability |
| --- | --- | --- | --- |
| `catalog.json` (schema v1) | Reusable item definitions only: detect, install, dependencies. No inventory, no per-user choices | Repo, validated by tests | Ships with the engine |
| Machine manifest (schema v3) | The user's registered defaults (`items`) + observed `inventory` + `inventoryConfig` | `~/Library/Application Support/geordi/machine-manifest.json` by default (`resources/paths.json`); override with `--manifest PATH` | The file a new machine needs |

`migrate` is the one-time split of a legacy combined schema-v2 manifest
(`items` + `inventory` in one file): registered items and inventory move into
the machine manifest; definitions absent from the catalog are contributed to
it — existing catalog entries are never mutated. The legacy file is left
unchanged. A fresh machine manifest starts empty: nothing installs until the
user registers. `GEORDI_BOOTSTRAP_HOME` redirects `$HOME` for tests.

## Registered defaults versus observed inventory

The machine manifest has two distinct sets:

| Field | Meaning |
| --- | --- |
| `items` | Registered defaults, including defaults not installed now; disabled shell defaults remain disabled |
| `inventory.brew.formulae` | Every installed formula, **including transitive dependencies**, using exact `full_name` |
| `inventory.brew.casks` | Every installed cask, using exact `full_token` |
| `inventory.brew.taps` | Actual `brew tap` output; empty is valid with API-based core/cask |
| `inventory.apps` | Third-party application metadata, with exact cask-artifact matches or unverified/manual provenance |

Setup restores missing declared defaults and recorded inventory. Inventory-only
apps have manual instructions, never an inferred Homebrew package. Existing app
bundles may satisfy declared defaults without changing their install source.
Formula and cask identifiers occupy separate namespaces even when names match.
Versions are evidence, not pins. `installedOnRequest` distinguishes requested
formulae from dependency installs but neither set is excluded from setup.

`--check` compares live Homebrew identifiers and taps to the snapshot and detects
recorded/default apps and commands. It **does not rescan for new apps**; use
`--sync` for that explicit collection. `declaredNotBrew` explains defaults absent
from Homebrew even if a manually installed app satisfies them. Extra installed
packages are reported, never uninstalled. Sync intentionally replaces the old
observed set, so review the diff before accepting removals from the snapshot.

## Deterministic inventory collection

`--sync` uses only:

1. `brew info --json=v2 --installed` and `brew tap` (read-only).
2. Directory entries under manifest-configured `/Applications` and
   `$HOME/Applications`, recursing through suite directories but never inside an
   `.app` bundle except reading `Contents/Info.plist` with `plutil`.
3. Plist bundle name, identifier, and version; `com.apple.` bundles are excluded
   by config. Missing/unreadable plists retain name-only entries with warnings.

No Spotlight scan, app launch, npm query, command version probes, personal data,
or application databases are read. Command detection checks executable metadata
and resolved symlink paths only. App cask provenance requires an exact artifact
target path; matching a friendly name never assigns a package source.

Output is sorted and timestamp-free; identical observations are a byte-for-byte
no-op. `$HOME` paths are portable. Collection and schema validation complete
before an atomic manifest replacement. Directory read failures and missing brew
abort rather than save a misleading empty/partial inventory. Warnings are stored
for individual missing plist metadata.

### Hermes provenance

The old guessed `hermes-agent` Homebrew formula has been removed. The default
checks the `hermes` executable path without executing it, reports its resolved
path as evidence, and retains manual official installation instructions at
<https://hermes-agent.nousresearch.com/docs>. Executable presence is not a claim
that any package manager owns it. The desktop app is independently inventoried.

## Central schema and migration

Three schemas share one item-definitions fragment
(`schema/item-v1.schema.json`): `machine-v3.schema.json` (machine manifest),
`catalog-v1.schema.json` (catalog), and `manifest-v2.schema.json` (legacy
combined manifests, migration input only). The small generic interpreter in
`schema/validate.js` supports only its declared JSON Schema subset — including
`definitions` and cross-file fragment references — and rejects unsupported
keywords. It validates required fields, unknown keys, types, enums, variants,
patterns, uniqueness, and array bounds with field paths. `src/manifest.js`
adds semantic uniqueness, dependency graph, and provenance reference checks
without maintaining another structural field list.

Version 3 intentionally rejects combined v2 manifests as machine manifests;
`migrate` is the only path from v2 to v3. The earlier v1-to-v2 migration
(retain default item intent; explicit manual instructions; metadata-only
checks; then live sync) remains a one-time historical step. Custom v1 users
must make the same explicit migration—no automatic package-name
inference or silent schema upgrade occurs.

## Verification

Tests use temporary directories, injected inventory/process adapters, and tiny
Node subprocesses for failure propagation; they never run real package installs.
They cover schema errors, graph semantics, exact brew namespaces, dependency
retention, cask artifact targets, metadata-only app inventory, atomic sync,
read-only modes, approval gates, idempotency, prerequisites, command failures,
post-install verification, and fixture/schema parity.

Live inventory evidence and check results are recorded in `VERIFICATION.md`.

