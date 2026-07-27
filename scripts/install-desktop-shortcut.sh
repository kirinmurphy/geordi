#!/bin/zsh
set -euo pipefail

installed_bundle="$HOME/Applications/HAL.app"
shortcut="$HOME/Desktop/HAL.app"

if [[ ! -d "$installed_bundle" ]]; then
  print -u2 "HAL is not installed at $installed_bundle"
  print -u2 "Run 'make install-dev' first."
  exit 1
fi

if [[ -e "$shortcut" || -L "$shortcut" ]]; then
  print -u2 "Refusing to replace existing Desktop item at $shortcut"
  exit 1
fi

ln -s "$installed_bundle" "$shortcut"
print "Created Desktop shortcut at $shortcut"
