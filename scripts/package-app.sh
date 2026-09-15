#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
source "$project_dir/scripts/product-brand.sh"
configuration="${1:-debug}"
binary="$project_dir/.build/$configuration/GeordiApp"
bundle="$project_dir/.build/$configuration/GeordiApp.app"
contents="$bundle/Contents"

# Repack from scratch: a stale .app from an earlier run contains read-only
# resource bundles that cp cannot overwrite.
rm -rf "$bundle"

if [[ ! -x "$binary" ]]; then
  print -u2 "Missing GeordiApp executable at $binary"
  print -u2 "Run 'swift build --product GeordiApp' first."
  exit 1
fi

mkdir -p "$contents/MacOS" "$contents/Resources"
install -m 755 "$binary" "$contents/MacOS/GeordiApp"
install -m 644 "$project_dir/Resources/GeordiApp-Info.plist" "$contents/Info.plist"
install -m 644 "$project_dir/Resources/GeordiApp.icns" "$contents/Resources/GeordiApp.icns"
# SwiftPM module resource bundles (Bundle.module lookups) - without them
# collectors cannot load their manifests and collection fails.
for resource_bundle in "$project_dir"/.build/$configuration/*.bundle(N); do
  cp -R "$resource_bundle" "$contents/Resources/"
done

plutil -replace CFBundleDisplayName -string "$product_display_name" "$contents/Info.plist"
plutil -replace CFBundleName -string "$product_display_name" "$contents/Info.plist"
plutil -lint "$contents/Info.plist" >/dev/null
codesign --force --sign - --identifier com.geordi.dev "$bundle"
print "Packaged $bundle"
