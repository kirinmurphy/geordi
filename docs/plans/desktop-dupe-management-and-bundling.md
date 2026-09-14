# Plan: Desktop dupe management + bundled app distribution

Status: seed (2026-09-12); reviewed 2026-09-13 — open questions were
decided that day and are marked **[DECIDED]** with rationale. Nothing
is left open; revisit any decision in-session if implementation
surfaces new information.

## Goal

Surface the find-dupe-files workflow (currently CLI-only, 5-stage) in the
geordi desktop client, and distribute geordi as a one-click downloadable
app bundle whose CLI is the bundle's own — replacing the current
symlink-into-checkout install.

## Decisions locked this session (context for whoever picks this up)

- **[DECIDED] CLI identity: symlink into the bundle.** The installed CLI
  is a symlink to `Geordi.app/Contents/MacOS/geordi` (or a launcher shim
  next to it). One copy of the scripts, updates ride along with app
  updates, repo checkout stays the single source of truth at build time.
  Rationale: idiomatic macOS; the current `/opt/homebrew/bin/geordi ->
  bin/geordi` (repo) link exists only because there is no bundle yet.
- **[DECIDED] Signing tier: ad-hoc for now.** Esteban is the only user;
  no Apple Developer Program certificate. Developer ID + notarization is
  a future requirement ONLY if the bundle is shared with others ($99/yr,
  automated malware scan + countersignature — not an approval of
  behavior).
- **[DECIDED] Single PATH entry.** The loose `find-dupe-files` compat
  link was removed (2026-09-12); the manifest has one link (`geordi`) and
  the installer preflights every manifest command source. Desktop work
  must not reintroduce loose aliases.

## Part A — bundle packaging

1. **Bundle layout** [DECIDED 2026-09-13]: everything Python lives under
   `Contents/Resources/geordi/` (sidekicks, `geordi_cli/`, `resources/`).
   `Contents/MacOS/geordi` is a thin launcher shim that sets `PYTHONPATH`
   to its own bundle's Resources and execs the dispatcher. The exact
   source-path → bundle-path mapping is a versioned, validated manifest
   resource (`bundle-layout.json`, schema v1) consumed by `make bundle`
   and by the in-app installer — no hardcoded layouts in scripts.
   Bundle name, identifier, and CLI command name derive from
   `Sources/GeordiManifestKit/Resources/product-brand.json` (schema v2),
   never from literals.
2. **Release build path.** Today `install-dev.sh` dittoes
   `.build/debug/GeordiApp.app` into `~/Applications`. Add a
   `make bundle` (or extend install-dev) that produces a release build
   with the CLI + resources staged in, ad-hoc codesigned, verified.
   [DECIDED 2026-09-13] **Do not use `codesign --deep`** — it's
   deprecated and unreliable for nested code. Sign inside-out: nested
   binaries/shims first, then the outer bundle, with
   `codesign --verify --strict` and a launch smoke test as the gate.
3. **Installer inside the app.** One-time CLI enable step (the Part C
   onboarding card; menu item as the always-available fallback) that
   symlinks the bundle's `geordi` into
   `/opt/homebrew/bin` — same preflight rules as `install-cli.py`
   (refuse unrelated occupied targets, idempotent). The existing
   `scripts/install-cli.py` logic should be reused, parameterized by
   bundle path, not duplicated.
4. **Update seam.** App update replaces the bundle; the symlink target
   path is stable (bundle path fixed), so no re-linking needed — verify
   this holds for `~/Applications` and document it.
   [DECIDED 2026-09-13] Repair, not just verification: on launch (or on
   `geordi --version`), the app/installer detects a dangling or
   wrong-target symlink at the PATH location and offers one-click
   re-link using the same preflight rules as A3. Bundle renames are a
   real scenario (see the bundle-rename runbook in the project skill),
   so "the path never changes" is not an assumption the design makes.
5. **Distribution artifact.** ZIP of the .app (personal use) — DMG only
   if/when sharing. `make dist` produces it.

## Part B — desktop dupe management

Groundwork from the CLI session (all shipped, tested, documented in
`cli/USAGE.md` + skill internals reference):

- 5-stage pipeline; byte dupes, copy-suffixed dupes, same-audio payload
  matching (wav/mp3/flac via `audio_payload()`), compat-format matches,
  and a least-confidence POSSIBLE tier.
- Trash-default deletion (`mac_trash()`), `--hard-delete` escape hatch.
- Seen-state per scan root in `~/.find-dupe-files/` (`--unreviewed`,
  `--forget-seen`).

Design constraints (from repo AGENTS.md + CLI conventions):

- Manifest-driven: folder lists, thresholds, stage definitions must come
  from versioned resources, not Swift literals.
- Synthetic-first/read-only desktop contract: the dupe scan is real user
  data — it must live behind the explicit "link this Mac" lifecycle, not
  run on first launch.
- Reuse, don't fork: the desktop UI should invoke the same sidekick
  (subprocess with structured output) or share its pure
  logic, NOT reimplement detection in Swift.
  [DECIDED 2026-09-13] Add a `--json` output mode to find-dupe-files —
  it is the seam, and it's cheap: `view_report()` at
  `cli/bin/sidekicks/find-dupe-files:1169` already computes everything
  from pure functions (`byte_clusters`, `name_groups`,
  `same_audio_groups`) and renders text afterward, so JSON mode is a
  parallel serializer over the same data, not a refactor. Contract:
  one JSON document, `{"schema_version": 1, "scan_root": ..., "groups":
  [...]}`, each group carrying a stable `group_key` (the existing
  `group_key()` — sorted member paths), confidence tier, and file
  entries with absolute path, size, mtime, payload hash where
  computed. Any later field addition bumps `schema_version`.
- Keep the interactive curses review terminal-only; the desktop UI is a
  parallel surface (group cards, per-group keep/delete), not a terminal
  emulator.

**[DECIDED 2026-09-13] JSON durations: not in v1.** `--json` ships
without duration info; a cached-duration store (written by `--dur`
runs, consumed by `--json`) is a later slice. Byte and audio-payload
groups — the high-confidence work — don't need durations, and
per-file `afinfo`/`ffprobe` shell-outs are too slow for a desktop UI
that rescans. The same-name/POSSIBLE tiers render without duration
classification until the cache exists.

**[DECIDED 2026-09-13] Division of labor — detection via sidekick,
deletion via app.** The desktop consumes `--json` for detection and
grouping only; the sidekick never gains an `--apply`/delete-by-key
mode. Deletion in the desktop app moves files to the macOS Trash
through its own Swift code, showing the same per-group review
semantics (lossless/lossy pairs never bulk-decided; POSSIBLE tier
never preselected). Rationale: the sidekick's non-tty refusal rule
exists precisely so scripts can't delete; teaching the sidekick to
delete on behalf of a GUI re-opens that door, and it would need its
own confirmation/audit design. Keeping deletion in the app matches the
repo rule that destructive behavior waits for explicit semantics.

**[DECIDED 2026-09-13] Seen-state: desktop is read-only against it.**
`--json` mode never reads or writes seen-state (verified: only
`review_mode()` touches it — `load_seen`/`save_seen` at
`cli/bin/sidekicks/find-dupe-files:944,1113`; `view_report()` is
state-free). Desktop-observed groups therefore never mask CLI review,
and vice versa. If a desktop "mark reviewed" feature is wanted later,
it becomes its own state store in the app's data directory, not the
sidekick's `~/.find-dupe-files/` files.

Suggested build order: A1–A2 (bundle) → B seam (`--json`) → B UI (read-
only report view first, destructive actions last) → A3 (in-app
installer) → C onboarding card (ships with A3's surface, trivial once
A3 exists).

**Progress (2026-09-13): ALL SHIPPED AND COMMITTED.** A1–A2 bundle
packaging (`bf0e3f4`, `37c3b13`), B `--json` seam (`eb7ed07`), and
A3/C/B-UI (`0dee5b1`: `geordi install-cli` manifest command,
`CLIEnablementModel` link classification + repair-on-request,
`CLICommandInventory` runtime decode powering the onboarding card's
info tooltip and success inventory, dismissible CLIOnboardingCard with
persisted preference, `DupeScan` schema-pinned decoder +
`DupeReviewView` read-only group cards behind the link-Mac gate,
`dupeReview` manifest destination). Gates at commit time: `make verify`
green, swift test 191 passed, CLI 91 passed, bootstrap 45 passed.
NOTE: the parallel bootstrap arc's later `commands.json` rewrite
dropped the install-cli entry once — it was re-added onto their schema;
both arcs' tests now assert containment rather than pinned counts.

## Verification

- `make verify` (desktop) + CLI unittest suite + bootstrap suite all
  green.
- Bundle: fresh-machine simulation (ad-hoc sign, launch, CLI enable,
  `geordi find-dupe-files --report` from the bundled path **and**
  through the `/opt/homebrew/bin/geordi` symlink — the symlink is the
  user's actual path, so it's the one that must pass).
- Desktop dupe view: synthetic-first holds; live scan only after
  linking.
- `--json` output round-trips through a schema check in the CLI test
  suite (golden-file test), so the Swift consumer never sees a silent
  shape change.

## Part C — CLI enablement onboarding

**[DECIDED 2026-09-13] Onboarding card, not a silent menu item and not
a launch-time install dialog.** First launch of a bundle-installed
app shows a dismissible onboarding card in the dupe/tool surface:

> Run agent-friendly actions via our CLI — [Enable CLI]

- The CTA runs the A3 installer flow (same preflight rules as
  `scripts/install-cli.py`, parameterized by bundle path).
- Dismissed state is a persisted user preference; the same action stays
  reachable from the menu (File → Enable Command-Line Tools or
  equivalent, name derived from the brand manifest).
- The card's wording is display copy — it lives in a versioned
  resource, not a Swift literal.
- The app never enables the CLI without the explicit button press.
- **[DECIDED 2026-09-13] Info tooltip with the CLI inventory.** The
  card carries an info icon whose tooltip lists every command the CLI
  exposes — name + one-line description read at runtime from the
  versioned command registry (`cli/resources/commands.json`, fields
  `command` + `description`; already schema-validated via
  `commands.schema.json`) — never a hardcoded list, so the user can
  see what they're enabling before deciding.
- **[DECIDED 2026-09-13] Success message reuses the same inventory.**
  After "Enable CLI" succeeds, the confirmation shows the same
  command breakdown (now with the actual installed command name and
  link target), reinforcing what became available and where. One
  component renders it in both places; the registry is the single
  source of truth for its contents.
