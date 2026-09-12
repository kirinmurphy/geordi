# geordi Repository Rules

A "sidekick" is a standalone script in `bin/sidekicks/`. Admission rules:

1. Stdlib-only (no pip, no venv) — must run on a fresh Mac with Xcode CLT.
2. Defaults to the current directory; never hardcodes absolute user paths.
3. Read-only by default; destructive action behind an explicit [y/N] prompt,
   `--yes` for scripts, and refusal on non-tty stdin without `--yes`.
4. `--help` explaining the interface is mandatory.
5. Exit 0 on success, non-zero on failure/abort.
6. One file (or one self-contained subdirectory) per sidekick.
7. Tests live in `test/` and must not touch real user data — temp dirs only.
