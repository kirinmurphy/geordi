# Installing, updating, and fully uninstalling geordi

This document covers the packaged app (DMG) and the development install:
what each one places on your disk, how they coexist, and how to remove
every trace.

## What is inside the DMG

`geordi-<version>.dmg` is a read-only compressed disk image containing
one item: `geordi.app`. The app bundle layout:

```
geordi.app/Contents/
├── Info.plist                    # identity: com.geordi.dev, version, display name
├── MacOS/
│   ├── GeordiApp                 # the native Swift GUI binary
│   └── geordi                    # CLI launcher shim (resolves the bundle
│                                 #   through any symlink to itself)
└── Resources/
    ├── GeordiApp.icns            # app icon
    ├── geordi/                   # the staged CLI tree (layout declared by
    │   ├── cli/bin/…             #   cli/resources/bundle-layout.json):
    │   ├── cli/geordi_cli/…      #   dispatcher, sidekicks, command registry
    │   ├── bootstrap/…           #   Mac setup engine
    │   └── Sources/…             #   brand manifest copy
    └── geordi_*.bundle           # SwiftPM module resource bundles
                                  #   (collector manifests, schemas, fixtures)
```

The GUI and the CLI share one copy of everything: when you replace the
bundle, both update together. The installer symlinks the bundled `geordi`
into your PATH; no scripts are copied outside the bundle.

## Install (DMG)

1. Open the DMG and drag `geordi.app` to `/Applications`
   (or `~/Applications` — see "Dev and DMG coexistence").
2. **First launch only** (unsigned/ad-hoc build): right-click the app →
   **Open**, then confirm. macOS 15+: if it refuses, use
   System Settings → Privacy & Security → **Open Anyway**. This is a
   one-time step per app copy; it disappears entirely with Developer ID
   notarization (not yet).
3. Enable the CLI from inside the app (onboarding card, **Enable CLI**)
   or from a terminal: `geordi install-cli` once the link exists — or
   from the bundle directly:
   `/Applications/geordi.app/Contents/MacOS/geordi install-cli`.

This creates exactly one thing outside the app: a symlink
`/opt/homebrew/bin/geordi` → the bundle's launcher. Nothing else is
installed, no sudo, no launch agents.

## What geordi puts on disk (complete asset inventory)

| Path | What | Created by |
|---|---|---|
| `/Applications/geordi.app` or `~/Applications/geordi.app` | The app (GUI + CLI + resources) | Install |
| `/opt/homebrew/bin/geordi` | Symlink → the installed launcher | CLI enablement |
| `~/Library/Application Support/geordi/` | Compiled live snapshot + machine manifest (only after **Link This Mac**) | App, when linked |
| `~/Library/Preferences/com.geordi.dev.plist` | Preferences (data-source mode, dismissed cards) | App |
| `~/.find-dupe-files/` | CLI duplicate-review seen-state, per scan root | `geordi find-dupe-files` guided review |
| `~/.Trash/…` | Trashed duplicates (recoverable until Trash is emptied) | Duplicate deletion |

The first two are "the install"; the rest is user data the app creates
through use.

## Update

Replace the bundle (drag the new `geordi.app` over the old one, or
`make install-dev` for development) — the PATH symlink target does not
change, so the CLI follows the new bundle automatically. If the app was
renamed or moved, the launcher detects the broken link: run
`geordi install-cli` again (or use the in-app card) to re-link.

## Dev and DMG coexistence

Both builds share the same bundle identity (`com.geordi.dev`), display
name, and user-data paths **by design** — they are the same product, so
preferences and linked snapshots carry across.

- **Development** (`make install-dev` / `make run`): installs the debug
  build to `~/Applications/geordi.app`; the PATH symlink points at the
  repository (`bin/geordi`), so the CLI always runs your working tree.
- **DMG/release**: drag to `/Applications/geordi.app`.

Both copies can sit on disk at once (one in `/Applications`, one in
`~/Applications`), and which one Dock/Finder opens is ambiguous — treat
one of them as the "installed" app. The reliable switch is the PATH
symlink:

- Dev CLI: `python3 scripts/install-cli.py` (targets the repo checkout)
- Bundled CLI: `geordi install-cli` from the installed bundle, or
  `/Applications/geordi.app/Contents/MacOS/geordi install-cli`

`readlink /opt/homebrew/bin/geordi` always tells you which one is live.

**Recommended while iterating:** keep the dev install in `~/Applications`
and the CLI pointed at the repo; install the DMG copy only to test the
packaged experience.

## Full uninstall (garbage collection)

Quit the app first, then remove each asset you have:

```sh
# 1. The app (whichever copies exist)
rm -rf /Applications/geordi.app ~/Applications/geordi.app

# 2. The PATH link (only if you enabled the CLI)
rm /opt/homebrew/bin/geordi

# 3. Preferences
defaults delete com.geordi.dev 2>/dev/null
rm -f ~/Library/Preferences/com.geordi.dev.plist

# 4. Compiled linked-Mac data (only exists if you linked)
rm -rf ~/Library/"Application Support"/geordi

# 5. CLI duplicate-review seen-state (only exists after guided review runs)
rm -rf ~/.find-dupe-files
```

Nothing else is left behind: no launch agents, no kernel extensions, no
cron entries, no files outside the paths above. Steps 4–5 delete user
data (compiled snapshots and review history) — skip them if you plan to
reinstall and want to keep your state.
