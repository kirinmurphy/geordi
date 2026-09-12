#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_dir="${0:A:h:h}"
source "$project_dir/scripts/product-brand.sh"
app_bundle="$project_dir/.build/debug/GeordiApp.app"
app_binary="$app_bundle/Contents/MacOS/GeordiApp"

cd "$project_dir"
swift build --disable-sandbox --product GeordiApp >/dev/null
"$project_dir/scripts/package-app.sh" >/dev/null

[[ -d "$app_bundle" ]]
[[ -x "$app_binary" ]]
[[ "$(plutil -extract CFBundlePackageType raw "$app_bundle/Contents/Info.plist")" == "APPL" ]]
[[ "$(plutil -extract CFBundleIdentifier raw "$app_bundle/Contents/Info.plist")" == "com.geordi.dev" ]]
[[ "$(plutil -extract CFBundleDisplayName raw "$app_bundle/Contents/Info.plist")" == "$product_display_name" ]]

print "✓ $product_display_name is packaged as a valid native application bundle."
