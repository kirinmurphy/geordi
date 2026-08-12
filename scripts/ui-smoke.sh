#!/bin/zsh
set -euo pipefail
unsetopt BG_NICE

project_dir="${0:A:h:h}"
source "$project_dir/scripts/product-brand.sh"
app_bundle="$project_dir/.build/debug/HALApp.app"
app_binary="$app_bundle/Contents/MacOS/HALApp"

cd "$project_dir"
swift build --disable-sandbox --product HALApp >/dev/null
"$project_dir/scripts/package-app.sh" >/dev/null

[[ -d "$app_bundle" ]]
[[ -x "$app_binary" ]]
[[ "$(plutil -extract CFBundlePackageType raw "$app_bundle/Contents/Info.plist")" == "APPL" ]]
[[ "$(plutil -extract CFBundleIdentifier raw "$app_bundle/Contents/Info.plist")" == "com.hal.dev" ]]
[[ "$(plutil -extract CFBundleDisplayName raw "$app_bundle/Contents/Info.plist")" == "$product_display_name" ]]

print "✓ $product_display_name is packaged as a valid native application bundle."
