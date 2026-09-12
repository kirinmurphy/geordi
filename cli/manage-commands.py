#!/usr/bin/env python3
"""Generate a complete registry from explicit JSON command and link parameters."""

import argparse
import json
import sys
from pathlib import Path

from geordi_cli.registry import Registry
from geordi_cli.schema import ManifestError, SchemaValidator, read_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--command", action="append", required=True, help="command object as JSON (repeatable)")
    parser.add_argument("--link", action="append", required=True, help="installation link object as JSON (repeatable)")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    resources = root / "cli/resources"
    try:
        data = {"schemaVersion": 1, "commands": [json.loads(c) for c in args.command],
                "links": [json.loads(link) for link in args.link]}
        # Generate before a brand is required; the registry contract is independent.
        registry = Registry.__new__(Registry)
        registry.root = root
        registry.validator = SchemaValidator(read_json(resources / "commands.schema.json"))
        registry.validate(data)
        output = resources / "commands.json"
        temporary = output.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        temporary.replace(output)
        print(output)
        return 0
    except (ManifestError, OSError, json.JSONDecodeError) as error:
        print(f"Registry error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
