#!/usr/bin/env python3
"""Build the distributable DMG from the release bundle.

Read-only-disk image (UDZO) containing the .app for drag-to-Applications
install. Volume name and image name derive from the product-brand
manifest — no literals. Verification mounts the image to a scratch
point, copies the app OUT (running from /Volumes is a classic mistake:
the image is read-only and users eject it), and smoke-checks the copy.
"""

from pathlib import Path
import argparse
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "cli"))
from geordi_cli.schema import read_json  # noqa: E402


def brand():
    brand_dir = REPO / "Sources/GeordiManifestKit/Resources"
    return read_json(brand_dir / "product-brand.json")


def run(command, check=True):
    result = subprocess.run(command, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(
            f"command failed ({result.returncode}): {' '.join(command)}\n"
            f"{result.stderr.strip()}")
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(
        description="Build the distributable DMG (drag-to-Applications).")
    parser.add_argument(
        "--output", default=None,
        help="output DMG path (default: .build/release/<name>.dmg)")
    args = parser.parse_args()

    data = brand()
    app_name = f"{data['displayName']}.app"
    version = run(
        ["plutil", "-extract", "CFBundleShortVersionString", "raw",
         str(REPO / ".build/release" / app_name / "Contents/Info.plist")],
        check=False) or "dev"
    dmg_name = f"{data['displayName']}-{version}.dmg"
    volume_name = data["displayName"]

    app_source = REPO / ".build/release" / app_name
    if not app_source.is_dir():
        raise RuntimeError(f"missing bundle: {app_source}; run 'make bundle' first")

    output = Path(args.output) if args.output else REPO / ".build/release" / dmg_name
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    run(["hdiutil", "create", "-volname", volume_name,
         "-srcfolder", str(app_source.parent),
         "-format", "UDZO", "-ov", "-quiet", str(output)])
    check_size = output.stat().st_size
    if check_size < 1_000_000:
        raise RuntimeError(f"DMG suspiciously small: {check_size} bytes")

    # Verification: mount, copy OUT, smoke the copy, unmount.
    with tempfile.TemporaryDirectory(prefix="geordi-dmg-") as scratch:
        mount_point = Path(scratch) / "mount"
        mount_point.mkdir()
        mount_info = run(["hdiutil", "attach", str(output),
                          "-mountpoint", str(mount_point), "-nobrowse",
                          "-readonly", "-quiet"])
        try:
            staged_app = mount_point / app_name
            if not staged_app.is_dir():
                raise RuntimeError(f"DMG does not contain {app_name}")
            copy_target = Path(scratch) / app_name
            run(["/usr/bin/ditto", str(staged_app), str(copy_target)])
            run(["codesign", "--verify", "--strict", str(copy_target)])
            smoke = run(
                [str(copy_target / "Contents/MacOS/geordi"), "--help"],
                check=False)
            if "Usage" not in smoke:
                raise RuntimeError(f"bundled CLI smoke failed: {smoke[:200]}")
        finally:
            run(["hdiutil", "detach", str(mount_point), "-quiet"])

    print(f"Built {output} ({check_size / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError) as error:
        print(f"dmg error: {error}", file=sys.stderr)
        sys.exit(2)
