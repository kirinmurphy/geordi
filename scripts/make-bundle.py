#!/usr/bin/env python3
"""Build a production Geordi.app bundle: release binary + staged CLI +
ad-hoc signature (no --deep; sign the outer bundle only — there is no
nested code with its own identity).

Layout, shim placement, and staged paths come from the versioned
bundle-layout manifest (cli/resources/bundle-layout.json, validated
against its JSON Schema). Product name/identifier come from the brand
manifest. No layout knowledge lives in this script.
"""

from pathlib import Path
import argparse
import json
import shutil
import subprocess
import sys

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "cli"))
from geordi_cli.registry import safe_resource  # noqa: E402
from geordi_cli.schema import ManifestError, SchemaValidator, read_json  # noqa: E402


def product_brand():
    brand_dir = REPO / "Sources/GeordiManifestKit/Resources"
    brand = read_json(brand_dir / "product-brand.json")
    SchemaValidator(read_json(brand_dir / "product-brand.schema.json")).validate(brand)
    return brand


def load_layout():
    resources = REPO / "cli/resources"
    layout = read_json(resources / "bundle-layout.json")
    SchemaValidator(read_json(resources / "bundle-layout.schema.json")).validate(layout)
    return layout


def check(condition, message):
    if not condition:
        raise ManifestError(message)


def run(command, **kwargs):
    result = subprocess.run(command, capture_output=True, text=True, **kwargs)
    check(result.returncode == 0,
          f"command failed ({result.returncode}): {' '.join(command)}\n{result.stderr.strip()}")
    return result.stdout.strip()


def stage_into(bundle_contents, layout):
    for entry in layout["stage"]:
        source = safe_resource(REPO, entry["source"], f"$.stage.source: {entry['source']}")
        check(source.exists(), f"stage source missing: {source}")
        destination = bundle_contents / entry["bundlePath"]
        destination.parent.mkdir(parents=True, exist_ok=True)
        if source.is_dir():
            shutil.copytree(source, destination, ignore=shutil.ignore_patterns(".DS_Store", "__pycache__"))
        else:
            shutil.copy2(source, destination)
        # sidekicks and shims must stay executable through the copy
        if source.is_dir():
            for path in destination.rglob("*"):
                if path.is_file() and not path.name.endswith(".json"):
                    path.chmod(0o755)


def main():
    parser = argparse.ArgumentParser(description="Build the production Geordi.app bundle (release build, staged CLI, ad-hoc signature).")
    parser.add_argument("--configuration", default="release", choices=["release", "debug"])
    parser.add_argument("--output", default=None, help="output directory (default: .build/<configuration>)")
    args = parser.parse_args()

    brand = product_brand()
    layout = load_layout()
    binary = REPO / ".build" / args.configuration / brand["executable"]
    check(binary.is_file(), f"missing {brand['executable']} binary at {binary}; run 'swift build -c {args.configuration} --product {brand['executable']}' first")

    build_dir = Path(args.output) if args.output else binary.parent
    bundle = build_dir / f"{brand['displayName']}.app"
    contents = bundle / "Contents"
    if bundle.exists():
        shutil.rmtree(bundle)
    (contents / "MacOS").mkdir(parents=True)
    (contents / "Resources").mkdir(parents=True)

    # GUI binary + icon + SwiftPM module resource bundles. Collectors load
    # their manifests via Bundle.module, which resolves Contents/Resources/
    # <module>.bundle next to the executable — a bundle without them boots
    # but fails read-only collection ("Not Collected" everywhere).
    shutil.copy2(binary, contents / "MacOS" / brand["executable"])
    (contents / "MacOS" / brand["executable"]).chmod(0o755)
    icon = REPO / "Resources" / f"{brand['executable']}.icns"
    check(icon.is_file(), f"missing app icon: {icon}")
    shutil.copy2(icon, contents / "Resources" / f"{brand['executable']}.icns")
    for resource_bundle in sorted(binary.parent.glob("*.bundle")):
        shutil.copytree(
            resource_bundle, contents / "Resources" / resource_bundle.name,
            ignore=shutil.ignore_patterns(".DS_Store"))

    # Info.plist: template placeholders from the brand manifest
    plist_text = (REPO / "Resources" / f"{brand['executable']}-Info.plist").read_text(encoding="utf-8")
    plist_text = plist_text.replace("__PRODUCT_NAME__", brand["displayName"])
    (contents / "Info.plist").write_text(plist_text, encoding="utf-8")
    run(["plutil", "-lint", str(contents / "Info.plist")])
    run(["plutil", "-replace", "CFBundleIdentifier", "-string", brand["bundleIdentifier"], str(contents / "Info.plist")])

    # CLI shim + staged CLI tree, both declared by the layout manifest
    shim_source = safe_resource(REPO, layout["shim"]["source"], "$.shim.source")
    shim_target = contents / layout["shim"]["bundlePath"]
    shutil.copy2(shim_source, shim_target)
    shim_target.chmod(0o755)
    stage_into(contents, layout)

    # ad-hoc signature, inside-out (no --deep): the shim is nested code that
    # must carry its own signature before the outer bundle seals it
    run(["codesign", "--force", "--sign", "-",
         "--identifier", f"{brand['bundleIdentifier']}.cli-shim", str(shim_target)])
    run(["codesign", "--force", "--sign", "-", "--identifier", brand["bundleIdentifier"], str(bundle)])
    run(["codesign", "--verify", "--strict", str(bundle)])

    print(f"Built {bundle}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ManifestError, OSError) as error:
        print(f"bundle error: {error}", file=sys.stderr)
        sys.exit(2)
