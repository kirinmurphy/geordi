"""Dispatcher acceptance tests through a real subprocess and symlink chain."""

import json
import os
import shutil
import signal
import sys

from support import Sandbox


class DispatchTests(Sandbox):
    def test_help_list_brand_and_unknown_arguments(self):
        for args in [(), ("--help",), ("-h",), ("help",)]:
            result = self.run_cli(*args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Test Toolkit", result.stdout)
            self.assertIn("geordi setup", result.stdout)
        self.assertIn("find-dupe-files", self.run_cli("list").stdout)
        for args in [("bogus",), ("--wat",), ("list", "--wat"), ("--help", "junk")]:
            self.assertEqual(self.run_cli(*args).returncode, 2)
        self.assertEqual(self.run_cli("setup", "--help").returncode, 0)

    def test_new_manifest_command_exact_argv_cwd_and_exit_through_symlinks(self):
        self.dummy(("new", "command"))
        first, second = self.base / "first", self.base / "second"
        first.symlink_to(self.root / "bin/geordi")
        second.symlink_to(first)
        args = ["with spaces", "", "--flag=x=y", "--", "-x", "café", "$(no-shell)"]
        result = self.run_cli("new", "command", *args, command=second)
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"args": ["fixed", *args], "cwd": str(self.cwd)})

    def test_help_tail_forwarded(self):
        self.dummy()
        result = self.run_cli("help", "probe")
        self.assertEqual(json.loads(result.stdout)["args"], ["fixed", "--help"])

    def test_executable_adapter_and_signal_passthrough(self):
        script = self.root / "cli/signal.sh"
        script.write_text("#!/bin/sh\nkill -TERM $$\n")
        script.chmod(0o755)
        self.dummy(runtime="executable")
        self.manifest["commands"][-1]["path"] = "cli/signal.sh"
        result = self.run_cli("probe")
        self.assertEqual(result.returncode, -signal.SIGTERM)

    def test_bootstrap_route_default_has_no_apply_and_preserves_options(self):
        if shutil.which("node") is None:
            self.skipTest("Node.js unavailable for real Node route fixture")
        result = self.run_cli("setup", "mac")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"args": ["mac"], "cwd": str(self.cwd)})
        args = ["--apply", "--yes", "--json", "--manifest=path with spaces"]
        result = self.run_cli("setup", "mac", *args)
        self.assertEqual(json.loads(result.stdout)["args"], ["mac"] + args)

    def test_real_bootstrap_preview_in_isolated_checkout(self):
        from support import REPO
        node = shutil.which("node")
        if node is None:
            self.skipTest("Node.js unavailable")
        shutil.copytree(REPO / "bootstrap", self.root / "bootstrap", dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("node_modules", ".git"))
        fixture = json.loads((REPO / "bootstrap/test/fixtures/integration.json").read_text())
        fixture["inventoryConfig"]["appRoots"] = [str(self.cwd)]
        fixture["inventoryConfig"]["brewPaths"] = []
        present = self.cwd / "present"
        present.touch()
        fixture["items"][0]["detect"][0]["value"] = str(present)
        fixture["items"][1]["detect"][0]["value"] = str(self.cwd / "missing")
        manifest = self.cwd / "bootstrap.json"
        self.save(manifest, fixture)
        before = manifest.read_bytes()
        isolated = self.base / "node-path"
        isolated.mkdir()
        (isolated / "node").symlink_to(node)
        (isolated / "python3").symlink_to(sys.executable)
        # Explicit fake Homebrew: only read-only inventory calls are accepted.
        brew = isolated / "brew"
        brew.write_text('#!/usr/bin/env python3\nimport sys\n'
                        'if sys.argv[1:] == ["info", "--json=v2", "--installed"]:\n'
                        '    print(\'{"formulae":[],"casks":[]}\')\n'
                        'elif sys.argv[1:] != ["tap"]:\n'
                        '    sys.exit(99)\n')
        brew.chmod(0o755)
        env = {**os.environ, "PATH": str(isolated), "HOME": str(self.cwd)}
        result = self.run_cli("setup", "mac", "--manifest", str(manifest), env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("preview", result.stdout.lower())
        self.assertEqual(manifest.read_bytes(), before)
        self.assertFalse((self.cwd / "missing").exists())
        refused = self.run_cli("setup", "mac", "--apply", "--manifest", str(manifest), env=env)
        self.assertEqual(refused.returncode, 2, refused.stderr)
        self.assertIn("--yes", refused.stderr)
        self.assertFalse((self.cwd / "missing").exists())

    def test_missing_node_diagnostic(self):
        isolated = self.base / "path"
        isolated.mkdir()
        (isolated / "python3").symlink_to(sys.executable)
        result = self.run_cli("setup", "mac", env={**os.environ, "PATH": str(isolated)})
        self.assertEqual(result.returncode, 127)
        self.assertIn("Node.js is required", result.stderr)

    def test_missing_command_resource_is_controlled_error(self):
        (self.root / "bootstrap/bin/geordi-bootstrap.js").unlink()
        result = self.run_cli("setup", "mac")
        self.assertEqual(result.returncode, 2)
        self.assertIn("resource missing", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_sidekick_default_cwd_help_and_nontty_no_deletion(self):
        result = self.run_cli("find-dupe-files", "--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        for name in ["song.wav", "song 2.wav"]:
            (self.cwd / name).write_bytes(b"same nonempty bytes")
        result = self.run_cli("find-dupe-files")
        self.assertIn("stdin is not a terminal", result.stdout)
        self.assertIn(str(self.cwd), result.stdout)
        self.assertTrue((self.cwd / "song.wav").exists())
        self.assertTrue((self.cwd / "song 2.wav").exists())
        self.assertEqual(self.run_cli("find-dupe-files", "--not-an-option").returncode, 2)
