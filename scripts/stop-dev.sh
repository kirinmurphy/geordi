#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
source "$project_dir/scripts/product-brand.sh"
installed_executable="$HOME/Applications/$product_display_name.app/Contents/MacOS/HALApp"
pid_file="$project_dir/.build/hal-dev.pids"

is_hal_development_command() {
  local command="$1"
  [[ "$command" == "$installed_executable" ]] && return 0
  [[ "$command" == "$project_dir/.build/"*"/HALApp.app/Contents/MacOS/HALApp" ]] && return 0
  [[ "$command" == "$project_dir/.build/"*"/HALApp" ]] && return 0
  return 1
}

typeset -a candidate_pids

if [[ -f "$pid_file" ]]; then
  while IFS= read -r pid; do
    [[ "$pid" == <-> ]] && candidate_pids+=("$pid")
  done < "$pid_file"
fi

while read -r pid command; do
  if is_hal_development_command "$command"; then
    candidate_pids+=("$pid")
  fi
done < <(/bin/ps -axo pid=,command=)

typeset -a hal_pids
for pid in ${(u)candidate_pids}; do
  command="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
  command="${command## }"
  if [[ -n "$command" ]] && is_hal_development_command "$command"; then
    hal_pids+=("$pid")
  fi
done

if (( ${#hal_pids} == 0 )); then
  rm -f "$pid_file"
  print "No running $product_display_name development process."
  exit 0
fi

# SIGTERM gives the app a chance to terminate normally. Every PID is checked
# against an exact development-bundle path immediately before signaling it.
for pid in $hal_pids; do
  command="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
  command="${command## }"
  if is_hal_development_command "$command"; then
    /bin/kill -TERM "$pid"
  fi
done

for _ in {1..50}; do
  typeset -a remaining
  for pid in $hal_pids; do
    command="$(/bin/ps -p "$pid" -o command= 2>/dev/null || true)"
    command="${command## }"
    if [[ -n "$command" ]] && is_hal_development_command "$command"; then
      remaining+=("$pid")
    fi
  done
  (( ${#remaining} == 0 )) && break
  sleep 0.1
done

if (( ${#remaining} > 0 )); then
  print -u2 "$product_display_name did not exit after SIGTERM: ${remaining[*]}"
  print -u2 "Refusing to force-kill it; quit those processes manually and retry."
  exit 1
fi

rm -f "$pid_file"
print "Stopped $product_display_name development process(es): ${hal_pids[*]}"
