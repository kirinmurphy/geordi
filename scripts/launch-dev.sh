#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
installed_bundle="$HOME/Applications/HAL.app"
installed_executable="$installed_bundle/Contents/MacOS/HALApp"
pid_file="$project_dir/.build/hal-dev.pids"

if [[ ! -x "$installed_executable" ]]; then
  print -u2 "HAL is not installed at $installed_bundle"
  print -u2 "Run 'make install-dev' first."
  exit 1
fi

# The stop step makes this a single-instance launch. Deliberately omit `-n`:
# that flag was the source of accumulating development processes.
open "$installed_bundle"

typeset -a launched_pids
for _ in {1..50}; do
  launched_pids=()
  while read -r pid command; do
    if [[ "$command" == "$installed_executable" ]]; then
      launched_pids+=("$pid")
    fi
  done < <(/bin/ps -axo pid=,command=)
  (( ${#launched_pids} > 0 )) && break
  sleep 0.1
done

if (( ${#launched_pids} != 1 )); then
  print -u2 "Expected one installed HAL process; found ${#launched_pids}."
  (( ${#launched_pids} > 0 )) && print -u2 "PIDs: ${launched_pids[*]}"
  exit 1
fi

mkdir -p "${pid_file:h}"
print -r -- "$launched_pids[1]" > "$pid_file"
print "Launched HAL development build (PID $launched_pids[1])."
