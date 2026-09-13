"""Preflighted symlink installer: no sudo, no unrelated target replacement."""

import argparse
import os
import sys
from pathlib import Path

from .registry import Registry
from .schema import ManifestError


class Installer:
    def __init__(self, registry, prefix):
        self.registry = registry
        self.directory = Path(prefix).expanduser().absolute() / "bin"

    def plan(self):
        planned = []
        # preflight every declared command source too: an install that
        # leaves a manifest command unrunnable is a broken install
        for command in self.registry.data["commands"]:
            source = self.registry.resource(command["path"])
            if not source.is_file() or not os.access(source, os.X_OK):
                raise ManifestError(f"installation source missing or not executable: {source}")
        for link in self.registry.data["links"]:
            source = self.registry.resource(link["path"])
            if not source.is_file() or not os.access(source, os.X_OK):
                raise ManifestError(f"installation source missing or not executable: {source}")
            target = self.directory / self.registry.link_name(link)
            old = None
            if os.path.lexists(target):
                if not target.is_symlink():
                    raise ManifestError(f"refusing occupied target: {target}")
                old = target.lstat()
                resolved = target.resolve()
                if resolved == source:
                    planned.append((source, target, "unchanged", old))
                    continue
                allowed = [self.registry.resource(p) for p in link["legacySources"]]
                if resolved not in allowed:
                    raise ManifestError(f"refusing unrelated symlink: {target} -> {os.readlink(target)}")
            planned.append((source, target, "replace" if old else "create", old))
        return planned

    def apply(self, planned):
        self.directory.mkdir(parents=True, exist_ok=True)
        for source, target, action, old in planned:
            if action == "unchanged":
                continue
            if action == "replace":
                current = target.lstat()
                if (current.st_dev, current.st_ino, current.st_mtime_ns) != (old.st_dev, old.st_ino, old.st_mtime_ns):
                    raise ManifestError(f"target changed during installation: {target}")
                target.unlink()
            # symlink() refuses a raced occupied destination; never use ln -sf.
            target.symlink_to(source)
        for source, target, _, _ in planned:
            if not target.is_symlink() or target.resolve() != source:
                raise ManifestError(f"installation verification failed: {target}")


def main(argv=None, root=None):
    parser = argparse.ArgumentParser(description="Install manifest-defined CLI symlinks without sudo; unrelated targets are never overwritten.")
    parser.add_argument("--prefix", default="/opt/homebrew", help="installation prefix (links go in PREFIX/bin; default: /opt/homebrew)")
    parser.add_argument("--dry-run", action="store_true", help="preview links without changing the filesystem")
    args = parser.parse_args(argv)
    try:
        installer = Installer(Registry(root or Path(__file__).resolve().parents[2]), args.prefix)
        planned = installer.plan()
        if not args.dry_run:
            installer.apply(planned)
        for source, target, action, _ in planned:
            verb = f"would {action}" if args.dry_run else ("unchanged" if action == "unchanged" else "linked")
            print(f"  {verb}: {target} -> {source}")
        return 0
    except (ManifestError, OSError, RuntimeError) as error:
        print(f"Install error: {error}", file=sys.stderr)
        return 2
