#!/usr/bin/env python3
"""In-bundle CLI launcher.

Resolve the app bundle even when invoked through the installed symlink in
/opt/homebrew/bin: sys.argv[0] follows the symlink back to
<Bundle>/Contents/MacOS/geordi, and parents[2] of that path is the bundle.
GEORDI_BUNDLE_ROOT overrides (tests). The CLI root inside the bundle comes
from the versioned bundle-layout manifest, never a hardcoded layout.
"""

from pathlib import Path
import json
import os
import sys


def cli_root(bundle):
    manifest_path = (bundle / "Contents" /
                     "Resources/geordi/cli/resources/bundle-layout.json")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    return bundle / "Contents" / manifest["cliRoot"]

def main():
    if os.environ.get("GEORDI_BUNDLE_ROOT"):
        bundle = Path(os.environ["GEORDI_BUNDLE_ROOT"])
    else:
        argv0 = Path(sys.argv[0]).resolve()
        bundle = argv0.parents[2]  # Bundle/Contents/MacOS/geordi -> Bundle
    root = cli_root(bundle)  # the dir the CLI treats as ROOT (repo-shaped: cli/, Sources/)
    sys.path.insert(0, str(root / "cli"))
    from geordi_cli.dispatch import main as dispatch_main
    sys.exit(dispatch_main(root=root))


if __name__ == "__main__":
    main()
