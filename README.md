# geordi

A native Mac system explorer with a CLI sidekick and a manifest-backed Mac
setup engine. One folder, one repository.

| Surface | Purpose | Location |
|---|---|---|
| Desktop | Explore applications, processes, files, startup behavior, and installation evidence | `Sources/`, `Tests/` |
| CLI | Dispatch helper scripts, including duplicate-file review | `bin/`, `cli/` |
| Mac setup | Compare desired software with installed inventory; preview and explicitly apply missing installs | `bootstrap/` |

## Getting started

| You want | Do this |
|---|---|
| Work on geordi | `make run` — builds, installs a debug app to `~/Applications/geordi.app`, and launches it. Verify with `make verify` before committing |
| Install the packaged app | `make dmg`, drag to `/Applications`, right-click → Open on first launch (ad-hoc signed) |
| Use the CLI | Enable it from the Home card, or run `python3 scripts/install-cli.py` from a checkout. `geordi --help` lists commands |
| Turn the CLI off | `rm /opt/homebrew/bin/geordi` — the Home card returns; `geordi repair-cli` restores the link |

What each install puts on disk, and how to remove every trace:
[docs/install-and-uninstall.md](docs/install-and-uninstall.md).
Command reference: [cli/USAGE.md](cli/USAGE.md). Setup engine: [bootstrap/README.md](bootstrap/README.md).

## Safety boundaries

- **Desktop first launch is synthetic.** Linking a Mac is explicit; observation stays local and read-only.
- **Duplicate cleanup requires confirmation.** Report mode only inspects; deletions default to the macOS Trash, and `--hard-delete` is the only permanent path.
- **Setup previews before installing.** Inventory refresh changes the manifest, not the machine; real installs require an explicit apply and confirmation.
- **No automatic uninstall.** Differences between the Mac and its manifest are reported, never resolved by removing software.

## Configuration

All growable knowledge lives in versioned, schema-validated manifest
resources — code never hardcodes which instances exist.

| Contract | Source |
|---|---|
| Product identity | `Sources/GeordiManifestKit/Resources/product-brand.json` |
| System profile schema | `Sources/GeordiProfileSchema/Resources/system-profile.schema.json` |
| CLI commands | `cli/resources/commands.json` |
| Setup catalog, schemas, and legacy fixture | `bootstrap/catalog.json`, `bootstrap/schema/`, `bootstrap/manifest.json` |

## Development

macOS 15+, a Swift 6.2+ toolchain, Python 3 (CLI uses stdlib only), Node.js 20+
(setup engine). `make verify` runs the same jobs CI does on every push: format
check, tests, fixture validation, build, and UI smoke.

Status and plans: [docs/product/status.md](docs/product/status.md),
[docs/plans/](docs/plans/). Architecture and design records:
[docs/architecture/](docs/architecture/), [docs/decisions/](docs/decisions/).
