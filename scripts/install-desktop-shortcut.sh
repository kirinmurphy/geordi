#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
source "$project_dir/scripts/product-brand.sh"
installed_bundle="$HOME/Applications/$product_display_name.app"
shortcut="$HOME/Desktop/$product_display_name.app"

if [[ ! -d "$installed_bundle" ]]; then
  print -u2 "$product_display_name is not installed at $installed_bundle"
  print -u2 "Run 'make install-dev' first."
  exit 1
fi

if [[ -e "$shortcut" || -L "$shortcut" ]]; then
  print -u2 "Refusing to replace existing Desktop item at $shortcut"
  exit 1
fi

ln -s "$installed_bundle" "$shortcut"
print "Created Desktop shortcut at $shortcut"
