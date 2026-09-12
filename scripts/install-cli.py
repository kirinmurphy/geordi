#!/usr/bin/env python3
"""Install the unified checkout's manifest-defined command links."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "cli"))
from geordi_cli.install import main

if __name__ == "__main__":
    sys.exit(main(root=ROOT))
