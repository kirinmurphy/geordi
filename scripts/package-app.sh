#!/bin/zsh
set -euo pipefail

# Development packaging delegates to make-bundle.py so the dev bundle has
# the exact same layout as the release bundle (staged CLI included —
# without it, "Enable CLI" cannot find the installer). The bundle keeps
# the executable name so existing .build/<config>/GeordiApp.app paths in
# install-dev.sh / ui-smoke.sh stay stable; all layout knowledge lives in
# cli/resources/bundle-layout.json.
project_dir="${0:A:h:h}"
configuration="${1:-debug}"

exec python3 "$project_dir/scripts/make-bundle.py" --configuration "$configuration" --bundle-name GeordiApp
