#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
source_bundle="$project_dir/.build/debug/HALApp.app"
applications_dir="$HOME/Applications"
installed_bundle="$applications_dir/HAL.app"

if [[ ! -d "$source_bundle" ]]; then
  print -u2 "Missing packaged app at $source_bundle"
  print -u2 "Run 'make build' first."
  exit 1
fi

mkdir -p "$applications_dir"
/usr/bin/ditto "$source_bundle" "$installed_bundle"
codesign --verify --deep --strict "$installed_bundle"

print "Installed HAL development build at $installed_bundle"
