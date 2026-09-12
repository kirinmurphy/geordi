# Geordi CLI

The unified repository's Python-stdlib dispatcher and standalone sidekicks.
See [USAGE.md](USAGE.md) for commands and installation.

| Component | Responsibility |
| --- | --- |
| `../bin/geordi` | Resolve installed symlinks to the canonical checkout |
| `resources/commands.json` | Versioned command registry and installation links |
| `resources/commands.schema.json` | Structural contract; unknown fields rejected |
| `geordi_cli/schema.py` | Stdlib validator for the schema subset used here |
| `geordi_cli/registry.py` | Validate resources, unique prefixes and contained paths |
| `geordi_cli/dispatch.py` | Help/list and process replacement with untouched arguments |
| `geordi_cli/install.py` | Preflight links, refuse unrelated targets, verify installation |
| `bin/sidekicks/` | Self-contained helper commands |
| `test/` | Disposable-prefix, subprocess, unit and PTY tests |

Brand comes from `../Sources/GeordiManifestKit/Resources/product-brand.json`
and its sibling schema. No duplicate CLI brand manifest is maintained here.

## Safety boundaries

- Registry paths cannot traverse outside the checkout, including through symlinks.
- Runtime adapters are fixed behavior (`python`, `node`, `executable`); command instances live in JSON.
- Dispatch uses no shell and preserves child exit status, signals, working directory and standard streams.
- Sidekick deletion remains prompt-gated; non-TTY invocation without `--yes` never deletes.
- The imported duplicate algorithm is unchanged. Its guided mode can return 0 after refusing/skipping non-TTY stages; refusal is observable in the report.
- `setup mac` delegates to the Node bootstrap's `mac` command; bootstrap owns preview, confirmation, inventory and installation policy.
- CLI installation never invokes sudo. Existing unrelated files, directories and symlinks are refused before writes. Only explicitly listed pre-merge links may be migrated.
