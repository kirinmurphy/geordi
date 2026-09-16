# Mac setup usage

```sh
node bootstrap/bin/geordi-bootstrap.js mac                 # preview only
node bootstrap/bin/geordi-bootstrap.js mac --check         # read-only status
node bootstrap/bin/geordi-bootstrap.js mac --json          # read-only JSON
node bootstrap/bin/geordi-bootstrap.js mac --sync          # update inventory only
node bootstrap/bin/geordi-bootstrap.js mac --apply         # real install, [y/N]
node bootstrap/bin/geordi-bootstrap.js mac --apply --yes   # explicit script approval
node bootstrap/bin/geordi-bootstrap.js mac chatgpt --apply # target + dependencies
node bootstrap/bin/geordi-bootstrap.js migrate --yes       # one-time v2 -> v3 split, [y/N]
```

The **machine manifest** (registered defaults + observed inventory) lives at
`~/Library/Application Support/geordi/machine-manifest.json` by default.
`--manifest PATH` selects another location — point it at a synced folder to
carry your registrations to a new machine. Item **definitions** come from the
repo's `catalog.json`. A legacy combined schema-v2 manifest is converted by
`migrate --legacy PATH`; the legacy file is left unchanged and the split is
refused if the machine manifest already exists (pass `--force` to replace it).

From this directory: `npm test`, `npm run validate`, `npm run check`.
`--help` works without Homebrew.
Internal aliases: `check`, `list`, `validate`, `sync`; `install` remains a preview
unless paired with `--apply`. Unknown flags are errors.

## Safety and exit codes

- Default execution previews. `--check` and `--json` never write or install.
- `--apply` requires an affirmative TTY prompt, or `--yes` without a TTY.
  Cancellation exits 1. Already-present targets are skipped, including explicitly
  named targets and packages installed as another action's dependency.
- `migrate` follows the same gate: explicit TTY confirmation or `--yes`.
  It writes only the machine manifest and the catalog; it never runs installs
  or modifies the legacy source file.
- `--sync` is the explicit authorization to replace **only inventory** in the
  selected manifest. It cannot combine with apply/check/yes or a target.
  `--json` cannot combine with sync/apply.
- Install adapters use executable + argument arrays, not shell strings. All
  missing items are preflighted before mutations; command failures and failed
  post-install detection exit 2. There is no simulated-success installer.
- No explicit upgrade, removal, cleanup, tap removal, shell-file editing, or
  app execution. Homebrew auto-update, analytics, and install cleanup are disabled.
  Installing a missing package can still install/update dependencies under
  Homebrew's own resolution rules; this is not a pinned-version restoration tool.
- Exit 0: successful preview/sync/validation/install. Exit 1: check finds missing
  items or package/tap drift, or user declines. Exit 2: invalid input, unavailable
  prerequisites, collection failure, installer failure, or failed verification.

### Fresh Mac prerequisites

Install Apple Command Line Tools (`xcode-select --install`, finish its dialog),
Homebrew from <https://brew.sh>, and Node.js 20+ before running this Node subproject.
The unified dispatcher should report missing Node instead of claiming setup ran.
Homebrew is found on PATH or at manifest-configured Apple Silicon/Intel locations.
If unavailable, collection stops clearly and **does not overwrite inventory**.
Homebrew/CLT bootstrapping and shell environment changes are deliberately manual:
no downloaded scripts are silently executed. npm-backed defaults require npm.
A manual missing item blocks bulk apply before any mutation; resolve it first or
select an installable target. Interrupted/failed installs are not rolled back;
rerun to detect completed work and retry only missing items.

