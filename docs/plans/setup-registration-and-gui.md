# geordi Setup Registration, Generalized Installers, and GUI Apply

Status: proposed
Origin: revisit of the absorbed hal-bootstrap workflow; user request, September 2026

## Product promise

Registering an app into the default setup, and installing it on a new machine,
should be one guided workflow instead of hand-editing JSON — and it should be
possible from both the terminal and the geordi desktop app, with the real
installer output visible either way.

Three surfaces, one policy engine:

1. **CLI registration** — `geordi setup register <name>` turns "I want this
   app" into a validated manifest entry, then a targeted apply installs it.
2. **Generalized installers** — Homebrew and npm stop being hardcoded; new
   package ecosystems are manifest entries, per the repository's
   manifest-driven composition rules.
3. **GUI setup panel** — the app shows setup status, runs real installs behind
   an explicit confirmation, and streams the actual installer output in an
   auto-scrolled buffer with a compact status line outside it.

## Current state

The bootstrap engine (`bootstrap/`) already implements the safety model:

- `manifest.json` (schema v2) holds two distinct sets: `items` (desired
  defaults: id, group, detect, install, dependsOn, enabled) and `inventory`
  (observed brew formulae, casks, taps, third-party apps with provenance).
- `src/installers/system.js` maps `brewCask`, `brewFormula`, `npmGlobal`, and
  `manual` to executable + argument arrays; never shell strings.
- `src/cli.js` previews by default; `--check` and `--json` never mutate;
  `--apply` requires a TTY `[y/N]` prompt or `--yes`; `--sync` is an explicit
  inventory-only refresh written atomically. Preflight before any mutation,
  re-detect before each install, post-install verification, no
  uninstall/upgrade/rollback.
- The CLI dispatcher exposes it as `geordi setup mac`
  (`cli/resources/commands.json`).

Gaps:

- Registering a new item means hand-editing `manifest.json`; there is no
  guided "add this app to my defaults" path.
- Installer types are literals in `system.js` and in
  `schema/manifest-v2.schema.json`, contradicting the rule that package
  ecosystems are manifest resources, not detector literals.
- `manifest.json` mixes a **reusable catalog** of item definitions with
  **Esteban's personal defaults** and **this machine's observed inventory**.
  Other users would inherit a defaults list they did not choose, and the
  portable artifact for moving machines is not user-scoped.
- The desktop app has no setup surface at all.

## Design

### Catalog and machine manifest are separate documents

Split today's single `manifest.json` into:

| Document | Contents | Location | Portability |
| --- | --- | --- | --- |
| **Catalog** | Item definitions only: id, label, group, detect, install, dependsOn. No inventory, no per-user registration. | Repo: `bootstrap/catalog.json`, schema-versioned, validated by tests | Ships with the engine; grows by contribution |
| **Machine manifest** | User-registered defaults (items copied from the catalog or created fresh) + observed inventory + inventoryConfig | User data dir (geordi Application Support), overridable with `--manifest PATH` so it can live in Dropbox | This is the file a new machine needs |

Rules:

- Registering copies a catalog item **into** the machine manifest. The user
  owns their copy; later catalog changes never mutate registered items
  (re-register with an explicit flag to update).
- A fresh machine manifest starts empty: nothing installs until the user
  registers. Opt-in by construction — a new geordi user gets the catalog as a
  menu of choices, never a preselected defaults list.
- One-time migration: on first run (or an explicit `migrate` subcommand),
  today's `items` move into the user's machine manifest and the committed file
  becomes the catalog. Inventory stays in the machine manifest.
- `--manifest PATH` already exists in `args.js`; the default path resolves to
  the user data dir when the flag is absent.

### Registration workflow

```
geordi setup register <name>          # detect provenance, show classification, confirm, write item
geordi setup register <name> --apply  # register, then targeted install with dependencies
geordi setup register <name> --cask <pkg> | --formula <pkg> | --npm <pkg>   # override detection
geordi setup migrate                  # one-time split of the legacy combined manifest
```

Registration order of evidence:

1. **Explicit override flag** wins; never second-guess the user.
2. **Catalog match** by id or label (copy the definition verbatim).
3. **Provenance probe**: exact cask artifact match (`brew info --json=v2`),
   formula match, npm-global availability — same exactness rules as inventory
   collection. No friendly-name inference ever.
4. **Manual**: none of the above; the item is registered with manual
   instructions the user supplies or edits later.

The probe is read-only. The write is atomic, schema-validated, and touches
only the machine manifest's `items` — the same discipline `--sync` applies to
inventory. Registering an id that already exists is a visible no-op unless
`--force` re-detects and updates it.

### Generalized installers (schema v3)

Move installer types from code literals to a versioned
`bootstrap/installers.json` manifest:

```json
{
  "schemaVersion": 1,
  "installers": [
    { "id": "brewCask", "executable": "brew", "args": ["install", "--cask", "{package}"],
      "prerequisite": { "type": "command", "value": "brew" }, "detects": ["app", "path"] }
  ]
}
```

- `system.js` becomes a generic executor: resolve the executable, substitute
  the arg template, keep the existing preflight/verify/no-shell rules.
- `manifest-v2.schema.json` item `install.type` becomes a free installer id
  validated against the installer manifest (schema v3; v2 manifests are
  migrated by adding the three built-in ids — no semantic change).
- Adding `cargo`, `gem`, `mas`, etc. becomes a catalog/installer entry plus a
  schema-version bump, not engine surgery.
- Security invariants (no shell strings, preflight, post-install verify,
  never uninstall) stay in code and cannot be weakened by manifest entries.

### GUI setup panel

Phased to keep the app read-only-first:

**Phase A — status (read-only).** A Setup section renders
`geordi-bootstrap.js mac --json` for the machine manifest: registered items
with installed/missing/manual state, brew drift, and the registration entry
point that shells out to `register`. Swift parses JSON and renders; the Node
engine remains the only policy authority; no detection logic is reimplemented.

**Phase B — apply with visible output.** On an explicit per-item or bulk
confirmation dialog, the app runs `--apply <target>` and streams combined
stdout/stderr into an auto-scrolled monospace buffer. Outside the buffer, a
compact status line (running item N of M / verified / failed) serves users who
do not read the raw output. Non-TTY `--apply` currently refuses without
`--yes`; the GUI path passes a dedicated engine affordance (e.g.
`--confirm-via <channel>`) so the explicit-dialog requirement is enforced by
the engine, not by the app's honesty. The buffer also becomes the surface
where manual-instruction items show their copy/paste guidance.

The app never edits the machine manifest directly; registration and apply both
go through the engine process.

## Delivery slices

1. **Split catalog / machine manifest + migrate** — schema v3 groundwork,
   one-time migration, tests for both documents, `--manifest` default
   resolution. CLI behavior of `setup mac` is unchanged after migration.
2. **`register` command** — probe, classify, confirm, atomic write; targeted
   `--apply <name>` works end to end; provenance probes reuse inventory
   collection exactlyness rules.
3. **Generalized installers** — `installers.json`, generic executor, schema v3
   validation, one non-brew ecosystem added as proof (candidate: `mas`).
4. **GUI status panel** — read-only `--json` rendering plus register handoff.
5. **GUI apply + output buffer** — confirmation dialog, streamed buffer,
   status line, engine-side confirm affordance.

Each slice is independently useful and leaves `make verify` plus
`npm test --prefix bootstrap` green.

## Verification

- Bootstrap unit tests cover: migration from the legacy combined manifest;
  register probe order (override > catalog > exact provenance > manual);
  atomic item writes that never touch inventory; duplicate/force semantics;
  installer-manifest validation and template substitution; refusal paths for
  unknown installer ids.
- Fixture parity: committed catalog and installer manifests validate against
  their schemas; tests fail, not warn, on drift.
- GUI apply is tested at the process boundary: injected fake installer
  emitting staged stdout/stderr, asserting streaming order, cancellation, and
  exit-code propagation. No real installs in tests.
- Fresh-machine rehearsal documented in `bootstrap/VERIFICATION.md`:
  empty machine manifest + repo checkout + `--manifest` pointing at the
  Dropbox copy restores registered defaults only.

## Acceptance criteria

- A new user runs zero setup commands and nothing is installed or registered;
  the catalog is presented as choices only.
- `geordi setup register <name> --apply` takes an app from "I want it" to
  "installed and verified" without hand-editing JSON.
- Adding a new package ecosystem requires no engine code change.
- The desktop app can install a registered item with the real installer
  output visible, behind an explicit confirmation enforced by the engine.
- Moving machines is: clone repo, point `--manifest` (or default path) at the
  synced machine manifest, run `setup mac --apply`.

## Open decisions

- Default machine-manifest location: geordi Application Support directory
  (proposed) versus a path under `~/.config`. Application Support matches the
  desktop app's data dir and the backup/reset story.
- Syncing the machine manifest: user-managed (Dropbox) is proposed for slice
  1; any geordi-managed sync is out of scope.
- Whether `register` should offer bulk registration driven by a `--sync`
  diff (register everything observed but unregistered) — probably yes, but it
  must stay explicitly confirmed and is deferred to a later slice.
