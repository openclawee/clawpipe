#!/usr/bin/env bash
set -euo pipefail

# ClawPipe MVP evolving scheduler loop:
# - supports N agents
# - supports max turns
# - supports simple scheduling strategy (round_robin / random)
# - OpenClaw invocation via: chat --user

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/scheduler.sh
source "$ROOT_DIR/scripts/lib/scheduler.sh"

# ----- fixed defaults (still no CLI parsing) -----
TOPIC="${TOPIC:-AI Agent 如何协作完成任务？}"
MAX_TURNS="${MAX_TURNS:-6}"
SCHEDULER_POLICY="${SCHEDULER_POLICY:-round_robin}" # round_robin | random

# Format:
# AGENTS=(
#   "display_name|openclaw_user_id|persona_file"
# )
AGENTS=(
  "Agent1|cp.clawpipe.mvp.agent1|$ROOT_DIR/personas/mvp_agent1.md"
  "Agent2|cp.clawpipe.mvp.agent2|$ROOT_DIR/personas/mvp_agent2.md"
  "Agent3|cp.clawpipe.mvp.agent3|$ROOT_DIR/personas/builder.md"
)

AGENT_NAMES=()
AGENT_USERS=()
AGENT_PERSONA_FILES=()
AGENT_SYSTEMS=()

validate_runtime() {
  if ! command -v openclaw >/dev/null 2>&1; then
    echo "[ERROR] openclaw command not found in PATH." >&2
    exit 1
  fi

  if [[ "${#AGENTS[@]}" -eq 0 ]]; then
    echo "[ERROR] no agents configured." >&2
    exit 1
  fi

  if [[ ! "$MAX_TURNS" =~ ^[0-9]+$ ]] || [[ "$MAX_TURNS" -eq 0 ]]; then
    echo "[ERROR] MAX_TURNS must be a positive integer." >&2
    exit 1
  fi

  if [[ "$SCHEDULER_POLICY" != "round_robin" && "$SCHEDULER_POLICY" != "random" ]]; then
    echo "[ERROR] unsupported SCHEDULER_POLICY: $SCHEDULER_POLICY" >&2
    exit 1
  fi
}

load_agents() {
  local agent_spec name user_id persona_file
  for agent_spec in "${AGENTS[@]}"; do
    IFS='|' read -r name user_id persona_file <<<"$agent_spec"
    if [[ -z "${name:-}" || -z "${user_id:-}" || -z "${persona_file:-}" ]]; then
      echo "[ERROR] invalid agent spec: $agent_spec" >&2
      exit 1
    fi

    if [[ ! -f "$persona_file" ]]; then
      echo "[ERROR] persona file not found: $persona_file" >&2
      exit 1
    fi

    AGENT_NAMES+=("$name")
    AGENT_USERS+=("$user_id")
    AGENT_PERSONA_FILES+=("$persona_file")
    AGENT_SYSTEMS+=("$(<"$persona_file")")
  done
}

initialize_personas() {
  local i init_name init_user init_system
  for i in "${!AGENT_NAMES[@]}"; do
    init_name="${AGENT_NAMES[$i]}"
    init_user="${AGENT_USERS[$i]}"
    init_system="${AGENT_SYSTEMS[$i]}"

    openclaw chat \
      --user "$init_user" \
      --system "$init_system" \
      --message "初始化角色。请仅回复：INIT_OK" >/dev/null

    echo "[INIT] ${init_name} persona injected -> ${init_user}"
  done
}

run_dialogue() {
  local agent_count="${#AGENT_NAMES[@]}"
  local last_message="Host: 讨论主题是：${TOPIC}"
  local last_speaker_idx=-1
  local turn idx name user_id system_prompt prompt raw_output output

  echo "[INFO] Scheduler policy: ${SCHEDULER_POLICY}"
  echo "[INFO] Agent count: ${agent_count}, max turns: ${MAX_TURNS}"

  for ((turn=0; turn<MAX_TURNS; turn++)); do
    idx="$(scheduler_next_index "$SCHEDULER_POLICY" "$turn" "$agent_count" "$last_speaker_idx")"
    name="${AGENT_NAMES[$idx]}"
    user_id="${AGENT_USERS[$idx]}"
    system_prompt="${AGENT_SYSTEMS[$idx]}"

    prompt=$(cat <<EOF
主题：${TOPIC}
群聊最近消息：${last_message}
这是第 $((turn + 1)) 轮。请给出一条简洁回复（不超过80字）。
EOF
)

    # Required chain: call OpenClaw with chat --user and capture output.
    raw_output="$(openclaw chat --user "$user_id" --system "$system_prompt" --message "$prompt")"
    output="$(printf '%s' "$raw_output" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
    [[ -n "$output" ]] || output="[no output]"

    echo "${name}: ${output}"

    # Pass current agent output to the next agent.
    last_message="${name}: ${output}"
    last_speaker_idx="$idx"
  done
}

main() {
  validate_runtime
  load_agents
  initialize_personas
  run_dialogue
}

main
