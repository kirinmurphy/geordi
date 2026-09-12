"""CLI control plane; configured command tails are passed through untouched."""

import os
import shutil
import sys
from pathlib import Path

from .registry import Registry
from .schema import ManifestError


class Dispatcher:
    def __init__(self, registry):
        self.registry = registry

    def show_commands(self):
        name = self.registry.brand["cliCommand"]
        for command in self.registry.data["commands"]:
            print(f"  {name} {' '.join(command['command'])}  · {command['description']}")

    def help(self):
        brand = self.registry.brand
        name = brand["cliCommand"]
        print(f"{brand['displayName']} desktop toolkit\n")
        print(f"Usage: {name} <command> [args]\n")
        self.show_commands()
        print(f"\n  {name} list  · List available commands")
        print(f"  {name} help [command]  · Show help")
        return 0

    def run(self, args):
        if not args or args in (["--help"], ["-h"], ["help"]):
            return self.help()
        if args == ["list"]:
            self.show_commands()
            return 0
        if args[0] == "help":
            return self.run(args[1:] + ["--help"])
        for command in self.registry.data["commands"]:
            prefix = command["command"]
            if args[:len(prefix)] == prefix:
                return self.launch(command, args[len(prefix):])
        # Group help is derived from manifest prefixes, never a command switch.
        group = args[:-1] if args[-1] in ("--help", "-h") else args
        matches = [c for c in self.registry.data["commands"]
                   if c["command"][:len(group)] == group]
        if matches and args[-1] in ("--help", "-h"):
            for command in matches:
                print(f"  {' '.join(command['command'])}  · {command['description']}")
            return 0
        print(f"{self.registry.brand['cliCommand']}: unknown or incomplete command: {' '.join(args)}", file=sys.stderr)
        return 2

    def launch(self, command, remaining):
        script = self.registry.resource(command["path"])
        if not script.is_file():
            raise ManifestError(f"command resource missing: {script}")
        runtime = command["runtime"]
        if runtime == "python":
            argv = [sys.executable, str(script)]
        elif runtime == "node":
            node = shutil.which("node")
            if node is None:
                print("Node.js is required for this command; install Node.js and retry.", file=sys.stderr)
                return 127
            argv = [node, str(script)]
        else:
            argv = [str(script)]
        argv += command["args"] + remaining
        # Replace the process: exact status/signals, stdio and cwd belong to child.
        os.execv(argv[0], argv)


def main(argv=None, root=None):
    try:
        registry = Registry(root or Path(__file__).resolve().parents[2])
        return Dispatcher(registry).run(list(sys.argv[1:] if argv is None else argv))
    except (ManifestError, OSError) as error:
        print(f"CLI error: {error}", file=sys.stderr)
        return 2
