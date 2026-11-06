#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${1:-$PWD}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd -P)"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/herdr-four-pane"
STATE_FILE="$STATE_DIR/workspace-id"
PANES_FILE="$STATE_DIR/panes.json"
CONFIG_DIR="${HERDR_CONFIG_DIR:-$HOME/bin/my-tool-kit/ai/herdr-config}"
COORDINATOR_RULES="$CONFIG_DIR/coordinator.md"
mkdir -p "$STATE_DIR"
for tool in herdr jq codex agy tmux; do
  command -v "$tool" >/dev/null || { echo "Missing command: $tool" >&2; exit 1; }
done

server_ready() { herdr workspace list >/dev/null 2>&1; }
ensure_server() {
  server_ready && return 0
  local session=herdr-four-pane-server log="$STATE_DIR/server-start.log" i
  echo 'Starting Herdr server in detached tmux PTY...'
  if ! tmux has-session -t "=$session" 2>/dev/null; then
    tmux new-session -d -s "$session" -c "$HOME" \
      "exec herdr >> $(printf '%q' "$log") 2>&1"
  fi
  for ((i=0;i<20;i++)); do
    server_ready && return 0
    sleep 1
  done
  echo "Herdr server not ready. Inspect: tmux attach -t $session" >&2
  tail -n 20 "$log" >&2 || true
  exit 1
}
json_id() { jq -er "$2" <<<"$1"; }

ensure_server
workspace=''
if [[ -s "$STATE_FILE" ]]; then
  candidate="$(cat "$STATE_FILE")"
  if herdr workspace get "$candidate" >/dev/null 2>&1; then
    workspace="$candidate"
    echo "Reusing workspace $workspace"
  fi
fi

if [[ -z "$workspace" ]]; then
  echo "Creating four-pane workspace in $PROJECT_DIR"
  created="$(herdr workspace create --cwd "$PROJECT_DIR" --label four-agent-lab --no-focus)"
  workspace="$(json_id "$created" '.result.workspace.workspace_id')"
  root="$(json_id "$created" '.result.root_pane.pane_id')"
  upper_right="$(json_id "$(herdr pane split "$root" --direction right --ratio 0.5 --no-focus)" '.result.pane.pane_id')"
  lower_left="$(json_id "$(herdr pane split "$root" --direction down --ratio 0.5 --no-focus)" '.result.pane.pane_id')"
  lower_right="$(json_id "$(herdr pane split "$upper_right" --direction down --ratio 0.5 --no-focus)" '.result.pane.pane_id')"
  herdr pane rename "$root" 'Agy - Worker A' >/dev/null
  herdr pane rename "$upper_right" 'Codex - Coordinator' >/dev/null
  herdr pane rename "$lower_left" 'Codex - Worker B' >/dev/null
  herdr pane rename "$lower_right" 'Manual - Bash' >/dev/null
  jq -n --arg workspace "$workspace" --arg agy "$root" --arg coordinator "$upper_right" \
    --arg worker "$lower_left" --arg manual "$lower_right" \
    '{workspace:$workspace,agy:$agy,coordinator:$coordinator,worker:$worker,manual:$manual}' > "$PANES_FILE"
  printf '%s\n' "$workspace" > "$STATE_FILE"
fi

# Discover actual panes from Herdr, including workspaces created by older launchers.
# Never trust a stale local mapping over the server's live pane list.
panes_raw="$(herdr pane list --workspace "$workspace")"
panes_json="$(jq -e '.result.panes | select(type=="array")' <<<"$panes_raw")" || {
  echo "ERROR: Cannot read live pane list for $workspace" >&2; exit 1;
}
find_pane() {
  local label="$1"
  jq -er --arg label "$label" '
    [ .[] | select(.label == $label) ] |
    if length == 1 then .[0].pane_id else error("Missing or duplicate pane label: " + $label) end
  ' <<<"$panes_json"
}
agy="$(find_pane 'Agy - Worker A')"
coord="$(find_pane 'Codex - Coordinator')"
worker="$(find_pane 'Codex - Worker B')"
manual="$(find_pane 'Manual - Bash')"
for pane in "$agy" "$coord" "$worker" "$manual"; do
  [[ "$pane" == "$workspace":* ]] || { echo "ERROR: Invalid pane $pane" >&2; exit 1; }
done
[[ "$(printf '%s\n' "$agy" "$coord" "$worker" "$manual" | sort -u | wc -l)" -eq 4 ]] || {
  echo 'ERROR: Pane IDs overlap; refusing to continue.' >&2; exit 1;
}
# Atomic mapping refresh. A pre-v5 workspace can now be recovered.
map_tmp="$(mktemp "$STATE_DIR/panes.json.XXXXXX")"
jq -n --arg workspace "$workspace" --arg agy "$agy" --arg coordinator "$coord" \
  --arg worker "$worker" --arg manual "$manual" \
  '{workspace:$workspace,agy:$agy,coordinator:$coordinator,worker:$worker,manual:$manual}' > "$map_tmp"
mv "$map_tmp" "$PANES_FILE"
printf '%s\n' "$workspace" > "$STATE_FILE"
echo "Discovered panes: Agy=$agy Coordinator=$coord Worker=$worker Manual=$manual"


# Agent list describes registrations; pane title is a secondary safety check.
# Fail closed on ambiguous states: never send keystrokes to a possibly active pane.
agent_state() {
  local name="$1" raw
  raw="$(herdr agent list)" || return 2
  jq -er --arg n "$name" '
    .result.agents // .agents // [] |
    map(select(.name==$n or .agent_id==$n or .id==$n)) |
    if length==0 then "missing"
    elif length>1 then "ambiguous"
    else (.[0].agent_status // .[0].status // "unknown")
    end' <<<"$raw"
}

# Some Herdr builds retain stopped agent registrations. We do not assume that
# `agent start` can overwrite them; report the exact CLI failure if it cannot.
start_if_needed() {
  local name="$1" kind="$2" pane="$3" state
  state="$(agent_state "$name")" || { echo "ERROR: Cannot inspect $name" >&2; return 1; }
  case "$state" in
    idle|working|starting|ready)
      echo "Keeping $name ($state)"; return 1 ;; # no new coordinator prompt
    missing|stopped|exited|terminated)
      # The agent registry alone does not prove the pane is safe to reuse.
      # Require the terminal title to look like a normal shell prompt.
      local title
      title="$(jq -r --arg p "$pane" '.[] | select(.pane_id==$p) | .terminal_title_stripped // .terminal_title // ""' <<<"$panes_json")"
      if [[ "$title" != *"@"*":"* ]]; then
        echo "ERROR: Pane $pane does not look like an idle shell (title: $title)." >&2
        echo 'Inspect it manually; refusing to inject a new agent.' >&2
        return 2
      fi
      echo "Starting $name in $pane (previous state: $state)"
      if herdr agent start "$name" --kind "$kind" --pane "$pane" --timeout 60000; then
        return 0
      fi
      echo "ERROR: Failed to start $name. Inspect its pane and 'herdr agent list'." >&2
      return 2 ;;
    *)
      echo "ERROR: $name state '$state' is ambiguous; refusing to restart." >&2
      return 2 ;;
  esac
}


start_if_needed worker-agy agy "$agy" || rc=$?
[[ ${rc:-0} -ne 2 ]] || exit 1
unset rc
start_if_needed worker-codex codex "$worker" || rc=$?
[[ ${rc:-0} -ne 2 ]] || exit 1
unset rc
coord_started=0
if start_if_needed coordinator codex "$coord"; then
  coord_started=1
else
  rc=$?
  [[ "$rc" -ne 2 ]] || exit 1
fi

if [[ "$coord_started" -eq 1 && -f "$COORDINATOR_RULES" ]]; then
  echo "Loading AUTO rules into newly started coordinator..."
  herdr agent prompt coordinator "$(cat "$COORDINATOR_RULES")" || \
    echo 'WARNING: Could not deliver AUTO rules; inspect Coordinator.' >&2
fi

herdr workspace focus "$workspace" >/dev/null || true
echo "Workspace: $workspace"
echo 'Existing agents preserved; stopped/missing agents restarted where supported.'
echo 'Attach with: herdr'
