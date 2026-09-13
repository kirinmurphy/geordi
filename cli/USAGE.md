# CLI usage

Run these commands from the repository root unless stated otherwise.

## Quick start

```sh
bin/geordi --help
bin/geordi list
bin/geordi find-dupe-files --report
bin/geordi setup mac --help
```

`find-dupe-files` scans the current directory when no path is supplied.
Arguments after a registered command prefix pass through unchanged.

### Duplicate review stages

`find-dupe-files` (guided mode) walks five stages:

1. Byte-identical copies split across temp/permanent folders — batch prompt.
2. Byte-identical OS copy-suffixed duplicates (` 2`, ` copy`) — batch prompt.
3. Manual review, one group at a time: lossless/compressed pairs, same-audio
   copies (identical audio payload, different metadata for wav/mp3/flac),
   remaining byte-identical groups, and compatible-format name matches.
4. Compatible-format name matches (whitelist-based) in the same review loop.
5. POSSIBLE duplicates — least confidence: same name with version words
   stripped and equal or unreadable duration. Rendered last, explicitly
   labeled, never preselected.

Deletions move files to the macOS Trash (recoverable until emptied);
`--hard-delete` unlinks permanently instead. `--report` stays read-only.

Seen-state: groups rendered in stage 3 are recorded per scan root in
`~/.find-dupe-files/` (a dot-directory, hidden from Finder). Run with
`--unreviewed` to skip already-reviewed groups, `--forget-seen` to clear
the state. A group counts as seen when it is displayed — keeping
everything is a decision too.

## Install

Python 3 is required. Mac setup additionally requires Node.js.

```sh
# Preview the two installation links without writing.
python3 scripts/install-cli.py --dry-run

# Install in /opt/homebrew/bin, without sudo.
python3 scripts/install-cli.py

# Alternative prefix; places links in ~/.local/bin.
python3 scripts/install-cli.py --prefix "$HOME/.local"
```

The installer creates `geordi` and the `find-dupe-files` compatibility link.
Repeated installation is idempotent. It refuses unrelated occupied targets;
there is no force flag. A legacy link into this checkout's
`bin/sidekicks/find-dupe-files` can be migrated to `cli/bin/sidekicks/find-dupe-files`.
Keep the checkout in place: installed commands are symlinks, not copied bundles.

## Commands

| Command | Behavior |
| --- | --- |
| `geordi list` | List commands from the manifest |
| `geordi help [command]` | Top-level help or forwarded command help |
| `geordi find-dupe-files [args]` | Run the duplicate-review sidekick (stages, Trash default, `--unreviewed`/`--forget-seen` seen-state) |
| `geordi setup mac [args]` | Run `node bootstrap/bin/geordi-bootstrap.js mac [args]` |

`geordi setup mac` defaults to preview. Use `--apply` for prompted installation,
`--apply --yes` for scripts, `--check` or `--json` for status, and `--sync` for
inventory refresh. Consult `geordi setup mac --help` for bootstrap's full interface.

Dispatcher input/manifest errors return 2; unavailable Node.js returns 127.
Dispatched commands otherwise retain their own exit status.

## Registry maintenance

Edit command definitions through the validating factory, passing the complete
collection as repeated JSON parameters. This example regenerates the current registry:

```sh
python3 cli/manage-commands.py \
  --command '{"command":["find-dupe-files"],"description":"Review duplicate files (current directory by default)","runtime":"python","path":"cli/bin/sidekicks/find-dupe-files","args":[]}' \
  --command '{"command":["setup","mac"],"description":"Preview missing Mac setup packages; use --apply to install","runtime":"node","path":"bootstrap/bin/geordi-bootstrap.js","args":["mac"]}' \
  --link '{"name":"@cliCommand","path":"bin/geordi","legacySources":[]}' \
  --link '{"name":"find-dupe-files","path":"cli/bin/sidekicks/find-dupe-files","legacySources":["bin/sidekicks/find-dupe-files"]}'
```

`@cliCommand` resolves the installed name from the canonical brand. All paths
are checkout-relative. Duplicate/overlapping command prefixes and reserved
`help`/`list` prefixes are rejected. Add commands without editing dispatcher code.

## Tests

```sh
python3 -m unittest discover -s cli/test -v
```

Tests use disposable directories and repository executables, never commands
resolved from a live `find-dupe-files` installation. Node route integration uses
an isolated copied bootstrap and a sandbox manifest; no packages are installed.
PTY tests check rendered text and filesystem outcomes, not visual styling.
