#!/bin/zsh
set -eu

SOURCE_DIR="${0:A:h}"
PROJECTS_DIR="$HOME/projects"
TARGET_DIR="$PROJECTS_DIR/hal"

if [[ -e "$TARGET_DIR" ]]; then
  print -u2 "Refusing to overwrite existing path:"
  print -u2 "  $TARGET_DIR"
  exit 1
fi

mkdir -p "$PROJECTS_DIR"
mkdir "$TARGET_DIR"
/usr/bin/ditto "$SOURCE_DIR" "$TARGET_DIR"

cd "$TARGET_DIR"
chmod +x bootstrap-hal-project.sh

if [[ ! -d .git ]]; then
  git init
fi

print
print "HAL project prepared at:"
print "  $TARGET_DIR"
print
print "Next prerequisite:"
print "  Install and launch the current stable Xcode."
print
print "After Xcode is ready, start Phase 0 from:"
print "  $TARGET_DIR/PHASE_0.md"
