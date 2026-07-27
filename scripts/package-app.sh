#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${1:-debug}"
binary="$project_dir/.build/$configuration/HALApp"
bundle="$project_dir/.build/$configuration/HALApp.app"
contents="$bundle/Contents"

if [[ ! -x "$binary" ]]; then
  print -u2 "Missing HALApp executable at $binary"
  print -u2 "Run 'swift build --product HALApp' first."
  exit 1
fi

mkdir -p "$contents/MacOS" "$contents/Resources"
install -m 755 "$binary" "$contents/MacOS/HALApp"
install -m 644 "$project_dir/Resources/HALApp-Info.plist" "$contents/Info.plist"
install -m 644 "$project_dir/Resources/HALApp.icns" "$contents/Resources/HALApp.icns"

plutil -lint "$contents/Info.plist" >/dev/null
codesign --force --sign - --identifier com.hal.dev "$bundle"
print "Packaged $bundle"
