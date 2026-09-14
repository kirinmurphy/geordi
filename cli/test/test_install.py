"""All installation writes remain inside disposable prefixes."""

import os

from support import Sandbox
from geordi_cli.install import Installer
from geordi_cli.schema import ManifestError


class InstallTests(Sandbox):
    def test_install_idempotent_and_geordi_link_works(self):
        for _ in range(2):
            result = self.install()
            self.assertEqual(result.returncode, 0, result.stderr)
        directory = self.base / "prefix/bin"
        self.assertEqual((directory / "geordi").resolve(), self.root / "bin/geordi")
        result = self.run_cli("--help", command=directory / "geordi")
        self.assertIn("Test Toolkit", result.stdout)
        result = self.run_cli("find-dupe-files", "--help",
                              command=directory / "geordi")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_dry_run_creates_nothing(self):
        result = self.install("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("would create", result.stdout)
        self.assertFalse((self.base / "prefix").exists())

    def test_occupied_file_directory_and_unrelated_links_refused_before_writes(self):
        directory = self.base / "prefix/bin"
        directory.mkdir(parents=True)
        target = directory / "geordi"
        for kind in ["file", "directory", "unrelated", "broken"]:
            with self.subTest(kind=kind):
                if kind == "file":
                    target.write_text("keep this")
                elif kind == "directory":
                    target.mkdir()
                else:
                    target.symlink_to(self.cwd if kind == "unrelated" else self.base / "missing")
                result = self.install()
                self.assertEqual(result.returncode, 2)
                self.assertFalse(os.path.lexists(directory / "find-dupe-files"))
                self.assertTrue(os.path.lexists(target))
                if kind == "file":
                    self.assertEqual(target.read_text(), "keep this")
                if kind == "directory":
                    target.rmdir()
                else:
                    target.unlink()

    def test_missing_source_refuses_before_creating_prefix(self):
        # the find-dupe-files sidekick is a manifest-declared command
        # source; deleting it must abort the whole install
        (self.root / "cli/bin/sidekicks/find-dupe-files").chmod(0o644)
        (self.root / "cli/bin/sidekicks/find-dupe-files").unlink()
        result = self.install()
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.base / "prefix").exists())

    def test_raced_target_is_not_replaced(self):
        installer = Installer(self.registry(), self.base / "prefix")
        plan = installer.plan()
        installer.directory.mkdir(parents=True)
        target = installer.directory / "geordi"
        target.write_text("arrived after preflight")
        with self.assertRaises(FileExistsError):
            installer.apply(plan)
        self.assertEqual(target.read_text(), "arrived after preflight")

    def test_raced_occupied_target_is_not_replaced(self):
        # legacy-source symlink -> plan() classifies it as a replace;
        # a target swapped after preflight must abort the apply
        self.manifest["links"][0]["legacySources"] = [
            "cli/bin/sidekicks/find-dupe-files"]
        installer = Installer(self.registry(), self.base / "prefix")
        installer.directory.mkdir(parents=True)
        target = installer.directory / "geordi"
        target.symlink_to(self.root / "cli/bin/sidekicks/find-dupe-files")
        plan = installer.plan()
        target.unlink()
        target.write_text("arrived after preflight")
        with self.assertRaisesRegex(ManifestError, "target changed"):
            installer.apply(plan)
        self.assertEqual(target.read_text(), "arrived after preflight")
