#!/bin/bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash uninstall-codex-macos.sh [--dry-run] [--yes]

Removes the Codex macOS app, Codex CLI installations, and local Codex data.
This permanently deletes local tasks, settings, credentials, caches, plugins,
and other data under ~/.codex and Codex-specific Library folders.

  --dry-run  Print what would be done without changing anything.
  --yes      Skip the interactive confirmation.
EOF
}

dry_run=false
assume_yes=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --yes) assume_yes=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
  esac
done

run() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  if ! $dry_run; then
    "$@"
  fi
}

remove_path() {
  local target=$1
  if [[ -e "$target" || -L "$target" ]]; then
    run rm -rf -- "$target"
  fi
}

remove_codex_app() {
  local app=$1
  local plist="$app/Contents/Info.plist"
  [[ -d "$app" ]] || return 0

  # Never delete an app at these paths unless its bundle ID is Codex's.
  local bundle_id=''
  if [[ -f "$plist" ]]; then
    bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist" 2>/dev/null || true)
  fi
  if [[ "$bundle_id" == "com.openai.codex" ]]; then
    remove_path "$app"
  else
    printf 'Skipping app with unexpected bundle ID (%s): %s\n' "${bundle_id:-unknown}" "$app" >&2
  fi
}

if ! $dry_run && ! $assume_yes; then
  cat <<'EOF'
WARNING: This permanently removes the Codex app and CLI, including all local
Codex tasks, configuration, credentials, plugins, caches, and logs.
EOF
  read -r -p 'Type DELETE CODEX to continue: ' reply
  [[ "$reply" == 'DELETE CODEX' ]] || { printf 'Cancelled.\n'; exit 1; }
fi

# Stop the app and its helpers. Failures are harmless when they are not running.
if $dry_run; then
  printf '+ terminate processes belonging to Codex\n'
else
  pkill -x Codex 2>/dev/null || true
  pkill -f '/Applications/ChatGPT.app/.*com.openai.codex' 2>/dev/null || true
  pkill -f '/Applications/Codex.app/' 2>/dev/null || true
  sleep 1
fi

# Remove package-manager CLI installations when present.
if command -v npm >/dev/null 2>&1 && npm list -g --depth=0 @openai/codex >/dev/null 2>&1; then
  run npm uninstall -g @openai/codex
fi
if command -v brew >/dev/null 2>&1; then
  if brew list --formula codex >/dev/null 2>&1; then run brew uninstall codex; fi
  if brew list --cask codex >/dev/null 2>&1; then run brew uninstall --cask codex; fi
fi

# Standalone CLI locations. Symlinks and files only; directories are skipped.
for cli in \
  "$HOME/.local/bin/codex" \
  /opt/homebrew/bin/codex \
  /usr/local/bin/codex
do
  if [[ -f "$cli" || -L "$cli" ]]; then
    run rm -f -- "$cli"
  fi
done

# Current and legacy app bundle names. Current releases may be named ChatGPT.app
# while retaining the com.openai.codex bundle identifier.
remove_codex_app /Applications/ChatGPT.app
remove_codex_app /Applications/Codex.app
remove_codex_app "$HOME/Applications/ChatGPT.app"
remove_codex_app "$HOME/Applications/Codex.app"

# Codex state and app data. Keep paths explicit to avoid touching other OpenAI apps.
paths=(
  "$HOME/.codex"
  "$HOME/.config/codex"
  "$HOME/Library/Application Support/Codex"
  "$HOME/Library/Application Support/com.openai.codex"
  "$HOME/Library/Application Support/OpenAI/Codex"
  "$HOME/Library/Caches/Codex"
  "$HOME/Library/Caches/com.openai.codex"
  "$HOME/Library/Preferences/com.openai.codex.plist"
  "$HOME/Library/Logs/com.openai.codex"
  "$HOME/Library/Saved Application State/com.openai.codex.savedState"
  "$HOME/Library/WebKit/com.openai.codex"
  "$HOME/Library/HTTPStorages/com.openai.codex"
  "$HOME/Library/HTTPStorages/com.openai.codex.binarycookies"
  "$HOME/Library/Group Containers/2DC432GLL2.com.openai.codex.notifications"
)
for path in "${paths[@]}"; do
  remove_path "$path"
done

if $dry_run; then
  printf '\nDry run complete; nothing was removed.\n'
else
  printf '\nCodex uninstall complete. Restart your Mac before reinstalling.\n'
fi
