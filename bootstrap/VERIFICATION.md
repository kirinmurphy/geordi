# Bootstrap verification evidence

Verified against the actual machine during the bootstrap integration. No package
installs, upgrades, removals, app launches, or Swift builds were performed.

| Gate | Observed result |
| --- | --- |
| Prototype baseline `npm test` | 7 passed |
| Expanded `npm test` | 39 passed, 0 failed |
| `npm run validate` | Manifest valid, schema v2 |
| Live `mac --sync` | 39 formulae, 2 casks, 15 third-party apps |
| Repeated live `mac --sync` | Unchanged, byte-stable manifest |
| Independent captured JSON and `brew list` comparison | Exact formula/cask identifier equality |
| Formula provenance | 7 installed on request, 32 dependency formulae; all retained |
| App provenance | 2 exact cask-artifact matches, 13 unverified/manual; no plist warnings |
| Taps | Empty live `brew tap`; valid API-based Homebrew installation |
| `mac --json` and `mac --check` | Exit 1: 57 of 60 planned items present, 3 missing |
| `mac` preview | Exit 0, no changes |
| Homebrew drift | No missing/untracked formulae, casks, or taps |
| Small-file check | All 19 JavaScript files below 300 lines |

## Catalog/machine-manifest split (slice 1, 2026-09-13)

| Gate | Observed result |
| --- | --- |
| `npm test` after the split | 45 passed, 0 failed (incl. 5 new migrate suites) |
| `npm run validate` | Machine-manifest fixture valid, schema v3 |
| Sandbox `migrate --yes` of the real legacy manifest | 13 registered items, catalog 13 definitions, legacy file untouched |
| `mac --check` against the migrated sandbox machine manifest | 56/60 present, 4 missing — matches the pre-split live state |
| Repeated sandbox `migrate --force` | Byte-stable machine manifest and catalog |
| Fixture parity | `catalog.json` validates against `catalog-v1.schema.json`; fixture validates against `machine-v3.schema.json`; tests fail on drift |

The observed check ran with `GEORDI_BOOTSTRAP_HOME` pointed at a temp
directory; no real user data was read or written.

Missing defaults are `chatgpt`, `codex`, and `claude`. Command absence is relative
to the current process PATH. Defaults not Homebrew-managed are `cmux`, `vscode`,
`dropbox`, `native-access`, `chatgpt`, `docker`, and `brave`; all except ChatGPT
were detected as existing app bundles, so setup will not reinstall them merely
to change their package-manager provenance.

The observed `hermes` executable resolves under `.hermes/hermes-agent/venv/bin`.
No Homebrew ownership is inferred. Its default installer is manual; the invalid
prototype formula guess has been removed. Actual inventory identifiers such as
`$HOME/Applications/HAL.app` are preserved literally, not renamed as branding.

---

## Reproduce the read-only verification

From `bootstrap/`, after an explicit inventory sync:

```sh
npm test
npm run validate
node bin/geordi-bootstrap.js mac --sync
node bin/geordi-bootstrap.js mac --json > /tmp/geordi-bootstrap-check.json
# Exit 1 is expected while declared defaults remain missing.
HOMEBREW_NO_AUTO_UPDATE=1 brew info --json=v2 --installed > /tmp/geordi-brew-inventory.json
HOMEBREW_NO_AUTO_UPDATE=1 brew list --formula -1 > /tmp/geordi-formula-list.txt
HOMEBREW_NO_AUTO_UPDATE=1 brew list --cask -1 > /tmp/geordi-cask-list.txt
python3 scripts/verify-evidence.py /tmp/geordi-brew-inventory.json \
  /tmp/geordi-formula-list.txt /tmp/geordi-cask-list.txt \
  /tmp/geordi-bootstrap-check.json
```

The evidence helper cross-checks concrete identifiers and declared counts. It
writes nothing. On custom-tap machines, `brew list` may use a short alias while
JSON uses a qualified name; the helper intentionally requires exact matching
for the captured machine, not alias inference.

## Validator passes and limits

- Pass 1, against root AGENTS.md, coding-standard modular/config rules, and
  geordi safety conventions: fixed inherited-key schema handling and added
  missing/self runtime-dependency reference rejection with regression tests.
- Pass 2: schema/fixture parity, live inventory equality, read-only behavior,
  argument-array install adapters, confirmation, failure propagation, idempotency,
  metadata-only app scanning, docs/interface parity, and subtree scope passed.
- Generic code auditor passed. Generic YAML config auditor could not run because
  PyYAML is absent; the actual JSON contract was validated by `npm run validate`
  and schema tests instead. No dependency was installed to make the unrelated
  YAML auditor run.
- Real package installation is deliberately unexecuted; its adapter/control flow
  is tested with fake commands. The real TTY prompt is dependency-injected in
  tests; approval/decline/non-TTY decisions are covered. Command-path detection
  establishes presence, not authenticated executable identity.
