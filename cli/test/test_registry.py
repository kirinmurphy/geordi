"""Structural schema and non-configurable safety invariant regression tests."""

import copy

from support import Sandbox
from geordi_cli.schema import ManifestError, SchemaValidator, read_json


class RegistryTests(Sandbox):
    def test_committed_manifest_validates(self):
        commands = {tuple(c["command"]) for c in self.registry().data["commands"]}
        # Both arcs' registry commands must coexist: find-dupe-files (sidekicks),
        # repair-cli (installation/repair), and the bootstrap arc's setup/migrate.
        self.assertTrue({("find-dupe-files",), ("repair-cli",), ("setup", "mac"), ("migrate", "manifest")} <= commands)

    def test_unknown_fields_invalid_enums_and_types(self):
        mutations = [
            lambda d: d.update(extra=True),
            lambda d: d.update(schemaVersion=3),
            lambda d: d.update(schemaVersion=True),
            lambda d: d["commands"][0].update(extra=True),
            lambda d: d["commands"][0].update(runtime="shell"),
            lambda d: d["commands"][0].update(command="not-an-array"),
            lambda d: d["commands"][0].pop("args"),
            lambda d: d["commands"][0].pop("category"),
            lambda d: d["commands"][0].update(category="bogus"),
            lambda d: d["links"][0].update(extra=True),
            lambda d: d["commands"][0].update(args=["bad\0arg"]),
        ]
        original = copy.deepcopy(self.manifest)
        for mutate in mutations:
            self.manifest = copy.deepcopy(original)
            mutate(self.manifest)
            with self.subTest(manifest=self.manifest), self.assertRaisesRegex(ManifestError, r"\$"):
                self.registry()

    def test_traversal_and_absolute_paths_rejected(self):
        for path in ["../outside", "/tmp/outside", "cli/../outside", "cli/./probe", "cli//probe", "cli\\probe"]:
            for section in ["commands", "links"]:
                with self.subTest(path=path, section=section):
                    old = self.manifest[section][0]["path"]
                    self.manifest[section][0]["path"] = path
                    with self.assertRaises(ManifestError):
                        self.registry()
                    self.manifest[section][0]["path"] = old

    def test_symlink_escape_and_loop_rejected(self):
        escape = self.root / "cli/escape"
        escape.symlink_to(self.base)
        self.manifest["commands"][0]["path"] = "cli/escape/outside"
        with self.assertRaisesRegex(ManifestError, "escapes"):
            self.registry()
        escape.unlink()
        escape.symlink_to(escape)
        with self.assertRaisesRegex(ManifestError, "symlink loop"):
            self.registry()

    def test_duplicate_prefix_reserved_and_link_collisions(self):
        original = copy.deepcopy(self.manifest)
        for tokens in [["setup"], ["setup", "mac"], ["list"], ["help", "more"], ["migrate"]]:
            self.manifest = copy.deepcopy(original)
            self.dummy(tokens)
            with self.assertRaises(ManifestError):
                self.registry()
        self.manifest = copy.deepcopy(original)
        self.manifest["links"].append(
            {"name": "geordi", "path": "bin/geordi", "legacySources": []})
        with self.assertRaisesRegex(ManifestError, "duplicate resolved"):
            self.registry()

    def test_brand_schema_and_safe_install_name(self):
        brand = self.root / "Sources/GeordiManifestKit/Resources/product-brand.json"
        for value in [{"schemaVersion": 1, "displayName": "Test", "cliCommand": "../oops"},
                      {"schemaVersion": 1, "displayName": "Test", "cliCommand": "geordi", "extra": True}]:
            self.save(brand, value)
            with self.assertRaises(ManifestError):
                self.registry()

    def test_unknown_schema_keywords_fail_closed(self):
        with self.assertRaisesRegex(ManifestError, "unsupported schema keywords"):
            SchemaValidator({"type": "string", "format": "uri"}).validate("anything")

    def test_factory_rejects_invalid_input_without_overwriting(self):
        import json
        import shutil
        import subprocess
        import sys
        from support import REPO
        factory = self.root / "cli/manage-commands.py"
        shutil.copy2(REPO / "cli/manage-commands.py", factory)
        output = self.root / "cli/resources/commands.json"
        before = output.read_bytes()
        args = [sys.executable, str(factory)]
        for command in self.manifest["commands"]:
            args.extend(["--command", json.dumps(command)])
        for link in self.manifest["links"]:
            args.extend(["--link", json.dumps(link)])
        result = subprocess.run(args, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(output.read_text()), self.manifest)
        before = output.read_bytes()
        args.extend(["--command", json.dumps({**self.manifest["commands"][0], "runtime": "shell"})])
        result = subprocess.run(args, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(output.read_bytes(), before)

    def test_duplicate_json_keys_rejected(self):
        path = self.base / "duplicate.json"
        path.write_text('{"schemaVersion":1,"schemaVersion":2}')
        with self.assertRaisesRegex(ManifestError, "duplicate field"):
            read_json(path)
