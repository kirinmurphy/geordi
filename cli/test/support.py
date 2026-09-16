"""Hermetic fixture checkout; never read installed commands or user data."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "cli"))
from geordi_cli.registry import Registry


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="geordi-cli-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.root = self.base / "checkout"
        shutil.copytree(REPO / "cli/geordi_cli", self.root / "cli/geordi_cli")
        shutil.copytree(REPO / "cli/resources", self.root / "cli/resources")
        (self.root / "bin").mkdir()
        shutil.copy2(REPO / "bin/geordi", self.root / "bin/geordi")
        (self.root / "scripts").mkdir()
        shutil.copy2(REPO / "scripts/install-cli.py", self.root / "scripts/install-cli.py")
        brand = self.root / "Sources/GeordiManifestKit/Resources"
        brand.mkdir(parents=True)
        self.save(brand / "product-brand.json", {"schemaVersion": 1, "displayName": "Test Toolkit", "cliCommand": "geordi"})
        self.save(brand / "product-brand.schema.json", {
            "type": "object", "additionalProperties": False,
            "required": ["schemaVersion", "displayName", "cliCommand"],
            "properties": {"schemaVersion": {"const": 1}, "displayName": {"type": "string"}, "cliCommand": {"type": "string"}}})
        self.manifest = json.loads((self.root / "cli/resources/commands.json").read_text())
        self.cwd = self.base / "work space"
        self.cwd.mkdir()
        sidekick = self.root / "cli/bin/sidekicks/find-dupe-files"
        sidekick.parent.mkdir(parents=True)
        shutil.copy2(REPO / "cli/bin/sidekicks/find-dupe-files", sidekick)
        install_cli = self.root / "cli/bin/repair-cli"
        install_cli.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO / "cli/bin/repair-cli", install_cli)
        install_cli.chmod(0o755)  # the installer preflights command sources
        bootstrap = self.root / "bootstrap/bin/geordi-bootstrap.js"
        bootstrap.parent.mkdir(parents=True)
        bootstrap.write_text("console.log(JSON.stringify({args:process.argv.slice(2),cwd:process.cwd()}));\n")
        bootstrap.chmod(0o755)  # the installer preflights command sources

    @staticmethod
    def save(path, data):
        path.write_text(json.dumps(data), encoding="utf-8")

    def persist(self):
        self.save(self.root / "cli/resources/commands.json", self.manifest)

    def registry(self):
        self.persist()
        return Registry(self.root)

    def run_cli(self, *args, command=None, env=None):
        self.persist()
        return subprocess.run([str(command or self.root / "bin/geordi"), *args], cwd=self.cwd,
                              input="", text=True, capture_output=True, timeout=15, env=env)

    def install(self, *args):
        self.persist()
        return subprocess.run([sys.executable, str(self.root / "scripts/install-cli.py"),
                               "--prefix", str(self.base / "prefix"), *args],
                              cwd=self.cwd, input="", text=True, capture_output=True, timeout=15)

    def dummy(self, tokens=("probe",), runtime="python"):
        script = self.root / "cli/probe.py"
        script.write_text("import json, os, sys\nprint(json.dumps({'args':sys.argv[1:],'cwd':os.getcwd()}))\nsys.exit(23)\n")
        self.manifest["commands"].append({"command": list(tokens), "description": "Test fixture",
                                           "category": "utility",
                                           "runtime": runtime, "path": "cli/probe.py", "args": ["fixed"]})
