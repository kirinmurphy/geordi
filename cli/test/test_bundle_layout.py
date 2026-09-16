"""Bundle layout manifest + shim resolution tests (hermetic; no real bundle)."""

import json
import os
import stat
from pathlib import Path
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "cli"))
from geordi_cli.registry import safe_resource  # noqa: E402
from geordi_cli.schema import ManifestError, SchemaValidator, read_json  # noqa: E402


class BundleLayoutTests(unittest.TestCase):
    def setUp(self):
        self.resources = REPO / "cli/resources"
        self.layout = read_json(self.resources / "bundle-layout.json")
        self.schema = read_json(self.resources / "bundle-layout.schema.json")

    def test_committed_manifest_validates(self):
        SchemaValidator(self.schema).validate(self.layout)

    def test_unknown_fields_and_wrong_version_rejected(self):
        mutations = [
            lambda d: d.update(extra=True),
            lambda d: d.update(schemaVersion=2),
            lambda d: d["stage"][0].update(extra=True),
            lambda d: d["stage"][0].update(bundlePath="MacOS/evil"),
            lambda d: d["stage"].append({"source": "x", "bundlePath": "Desktop/y"}),
            lambda d: d["shim"].update(bundlePath="Resources/geordi/escape"),
        ]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                data = json.loads(json.dumps(self.layout))
                mutate(data)
                with self.assertRaises(ManifestError):
                    SchemaValidator(self.schema).validate(data)

    def test_stage_sources_are_relative_and_resolve_inside_repo(self):
        """Traversal/absolute staging paths are refused by the shared
        path-safety check used at staging time, not by the schema subset."""
        for bad in ["../outside", "/etc/passwd"]:
            with self.subTest(path=bad):
                with self.assertRaises(ManifestError):
                    safe_resource(REPO, bad, "$.stage.source")

    def test_staged_paths_resolve_inside_repo(self):
        for entry in self.layout["stage"]:
            source = safe_resource(REPO, entry["source"], f"$.stage: {entry['source']}")
            self.assertTrue(source.exists(), f"stage source missing: {entry['source']}")

    def test_every_staged_command_source_lands_in_bundle_cli_root(self):
        """The dispatcher resolves command paths against cliRoot; staging
        must place every commands.json path under it."""
        commands = read_json(self.resources / "commands.json")
        cli_root = self.layout["cliRoot"]
        staged = {entry["source"]: entry["bundlePath"] for entry in self.layout["stage"]}
        for command in commands["commands"]:
            matches = []
            for source, bundle_path in staged.items():
                if command["path"] == source or command["path"].startswith(source + "/"):
                    matches.append((source, bundle_path))
            self.assertTrue(matches, f"command path not staged: {command['path']}")
            for source, bundle_path in matches:
                self.assertEqual(bundle_path, f"{cli_root}/{source}")

    def test_shim_source_exists_and_resolves_bundle(self):
        shim = safe_resource(REPO, self.layout["shim"]["source"])
        self.assertTrue(shim.is_file())
        text = shim.read_text()
        self.assertIn("parents[2]", text)  # MacOS/geordi -> Contents/MacOS -> Bundle
        self.assertIn("bundle-layout.json", text)  # layout comes from the manifest, not literals


class ShimBundleResolutionTests(unittest.TestCase):
    """Run the shim against a minimal fake bundle to prove bundle/root
    resolution without building the real app."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="geordi-shim-test-")
        self.addCleanup(self.temp.cleanup)
        self.bundle = Path(self.temp.name) / "geordi.app"
        contents = self.bundle / "Contents"
        root = contents / "Resources/geordi"
        # mirror the committed layout manifest exactly: cli/ tree + brand
        # resources under the bundle cli root
        (root / "cli/geordi_cli").mkdir(parents=True)
        (root / "cli/resources").mkdir(parents=True)
        brand_dir = root / "Sources/GeordiManifestKit/Resources"
        brand_dir.mkdir(parents=True)
        for name in ("product-brand.json", "product-brand.schema.json"):
            (brand_dir / name).write_text((REPO / "Sources/GeordiManifestKit/Resources" / name).read_text())
        for name in ("commands.json", "commands.schema.json",
                     "bundle-layout.json", "bundle-layout.schema.json"):
            (root / "cli/resources" / name).write_text(
                (REPO / "cli/resources" / name).read_text())
        for module in (REPO / "cli/geordi_cli").glob("*.py"):
            (root / "cli/geordi_cli" / module.name).write_text(module.read_text())
        shim = contents / "MacOS/geordi"
        shim.parent.mkdir(parents=True)
        shim.write_text((REPO / "Resources/geordi-shim.py").read_text())
        shim.chmod(0o755)
        # a probe "sidekick" so dispatch has something harmless to run
        probe = root / "cli/bin/sidekicks/probe"
        probe.parent.mkdir(parents=True)
        probe.write_text("#!/usr/bin/env python3\nimport json, sys\nprint(json.dumps({'argv': sys.argv[1:]}))\n")
        probe.chmod(0o755)
        commands = json.loads((REPO / "cli/resources/commands.json").read_text())
        commands["commands"] = [{"command": ["probe"], "description": "probe", "category": "utility",
                                 "runtime": "python",
                                 "path": "cli/bin/sidekicks/probe", "args": []}]
        (root / "cli/resources/commands.json").write_text(json.dumps(commands))
        self.shim = shim

    def test_symlinked_invocation_resolves_bundle_and_runs_command(self):
        import subprocess
        link = Path(self.temp.name) / "bin"
        link.mkdir()
        link = link / "geordi"
        link.symlink_to(self.shim)
        # cwd outside the bundle: resolution must come from argv[0], not cwd
        run = subprocess.run(
            [str(link), "probe", "--marker"], capture_output=True, text=True, timeout=15,
            cwd=self.temp.name,
            env={**os.environ, "PYTHONHASHSEED": "0"})
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("--marker", run.stdout)

    def test_env_override_bundle_root(self):
        import subprocess
        run = subprocess.run(
            [sys.executable, str(REPO / "Resources/geordi-shim.py"), "probe", "--tail"],
            capture_output=True, text=True, timeout=15,
            env={**os.environ, "GEORDI_BUNDLE_ROOT": str(self.bundle)})
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(run.stdout.strip(), '{"argv": ["--tail"]}')


if __name__ == "__main__":
    unittest.main()
