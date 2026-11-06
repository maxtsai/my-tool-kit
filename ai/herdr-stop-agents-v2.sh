#!/usr/bin/env bash
# Gracefully stop managed agents while preserving Herdr workspace and manual pane.
set -Eeuo pipefail
WS="$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/herdr-four-pane/workspace-id" 2>/dev/null || true)"
DRY=0; FORCE=0
for arg in "$@"; do case "$arg" in --dry-run) DRY=1;; --force) FORCE=1;; --help|-h) echo "Usage: $0 [workspace-id] [--dry-run] [--force]"; exit 0;; -*) echo "Unknown option: $arg" >&2; exit 2;; *) WS="$arg";; esac; done
[[ -n "$WS" && "$WS" != --* ]] || { echo 'ERROR: workspace ID required (e.g. w6)' >&2; exit 2; }
for cmd in herdr jq; do command -v "$cmd" >/dev/null || { echo "ERROR: missing $cmd" >&2; exit 2; }; done
panes=$(herdr pane list --workspace "$WS")
getpane() { jq -er --arg label "$1" '[.result.panes[] | select(.label==$label) | .pane_id] | if length==1 then .[0] else error("missing or duplicate pane label") end' <<<"$panes"; }
agy=$(getpane 'Agy - Worker A')
coord=$(getpane 'Codex - Coordinator')
worker=$(getpane 'Codex - Worker B')
manual=$(getpane 'Manual - Bash')
[[ "$agy" != "$manual" && "$coord" != "$manual" && "$worker" != "$manual" ]] || { echo 'ERROR: pane collision' >&2; exit 2; }
# Query current processes directly; never rely solely on Herdr's agent registry.
process_json() { herdr pane process-info --pane "$1"; }
proc_state() {
  local json="$1" kind="$2"
  jq -er --arg k "$kind" '
    [.result.process_info.foreground_processes[]?.name | ascii_downcase] as $names |
    if any($names[]; . == $k) then "running"
    elif ($names | length)==0 then "unknown"
    else "absent" end' <<<"$json"
}
agent_registry=$(herdr agent list)
# Herdr statuses are advisory only. Refuse when known to be working unless --force.
working_count=$(jq -r '[.result.agents[]? | select((.agent_status // .status // "") == "working")] | length' <<<"$agent_registry")
if (( working_count > 0 && FORCE == 0 )); then
  echo "ERROR: Herdr reports $working_count working agent(s). Refusing; use --force only after confirming work is saved." >&2
  exit 3
fi
pids=("$agy" "$coord" "$worker")
kinds=(agy codex codex)
labels=('Agy Worker' 'Codex Coordinator' 'Codex Worker')
states=()
for i in 0 1 2; do
  state=$(proc_state "$(process_json "${pids[$i]}")" "${kinds[$i]}")
  states+=("$state")
  echo "${labels[$i]}: pane=${pids[$i]} process=$state"
done
if (( DRY )); then echo 'DRY RUN: no input sent.'; exit 0; fi
for i in 0 1 2; do
  case "${states[$i]}" in
    absent) echo "SKIP ${labels[$i]}: agent process absent";;
    unknown) echo "ERROR: cannot safely identify process in ${pids[$i]}; aborting" >&2; exit 4;;
    running)
      echo "Stopping ${labels[$i]}..."
      # Both CLIs use a second Ctrl+C to confirm exit. Separate writes let
      # the application process the first key before receiving the second.
      herdr pane send-keys "${pids[$i]}" ctrl+c
      sleep 0.3
      state=$(proc_state "$(process_json "${pids[$i]}")" "${kinds[$i]}")
      if [[ "$state" == running ]]; then
        herdr pane send-keys "${pids[$i]}" ctrl+c
      fi
      ;;
  esac
done
failed=0
for i in 0 1 2; do
  [[ "${states[$i]}" == running ]] || continue
  done_flag=0
  for _ in {1..15}; do
    sleep 1
    state=$(proc_state "$(process_json "${pids[$i]}")" "${kinds[$i]}")
    if [[ "$state" == absent ]]; then done_flag=1; break; fi
  done
  if (( done_flag )); then echo "STOPPED ${labels[$i]}"; else echo "NOT CONFIRMED ${labels[$i]} (still running or unknown)" >&2; failed=1; fi
done
if (( failed )); then echo 'Some agents remain. Workspace preserved; inspect panes manually.' >&2; exit 5; fi
echo "All three target agent processes are absent. Workspace $WS and Manual pane $manual preserved."
echo 'Detach the Herdr TUI with Ctrl+B, then q (if using that keybinding).'
