#!/usr/bin/env bash
set -euo pipefail

# ClawPipe MVP minimal closed loop:
# - fixed 2 agents
# - fixed 2 turns (Agent1 -> Agent2)
# - OpenClaw invocation via: chat --user

if ! command -v openclaw >/dev/null 2>&1; then
  echo "[ERROR] openclaw command not found in PATH." >&2
  exit 1
fi

# ----- hardcoded settings -----
TOPIC="AI Agent 如何协作完成任务？"
TOTAL_TURNS=2

AGENT_NAMES=("Agent1" "Agent2")
AGENT_USERS=("cp.clawpipe.mvp.agent1" "cp.clawpipe.mvp.agent2")
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_PERSONA_FILES=(
  "$ROOT_DIR/personas/mvp_agent1.md"
  "$ROOT_DIR/personas/mvp_agent2.md"
)

for persona_file in "${AGENT_PERSONA_FILES[@]}"; do
  if [[ ! -f "$persona_file" ]]; then
    echo "[ERROR] persona file not found: $persona_file" >&2
    exit 1
  fi
done

# Shared chat context (minimal): pass latest message to next agent.
last_message="Host: 讨论主题是：${TOPIC}"

# Init step: inject each agent persona into its own OpenClaw user memory.
for i in "${!AGENT_NAMES[@]}"; do
  init_name="${AGENT_NAMES[$i]}"
  init_user="${AGENT_USERS[$i]}"
  init_system="$(<"${AGENT_PERSONA_FILES[$i]}")"

  openclaw chat \
    --user "$init_user" \
    --system "$init_system" \
    --message "初始化角色。请仅回复：INIT_OK" >/dev/null

  echo "[INIT] ${init_name} persona injected -> ${init_user}"
done

for ((turn=0; turn<TOTAL_TURNS; turn++)); do
  idx=$((turn % 2))
  name="${AGENT_NAMES[$idx]}"
  user_id="${AGENT_USERS[$idx]}"
  system_prompt="$(<"${AGENT_PERSONA_FILES[$idx]}")"

  prompt=$(cat <<EOF
主题：${TOPIC}
群聊最近消息：${last_message}
请给出一条简洁回复（不超过80字）。
EOF
)

  # Required chain: call OpenClaw with chat --user and capture output.
  raw_output="$(openclaw chat --user "$user_id" --system "$system_prompt" --message "$prompt")"
  output="$(printf '%s' "$raw_output" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"
  [[ -n "$output" ]] || output="[no output]"

  echo "${name}: ${output}"

  # Pass current agent output to the next agent.
  last_message="${name}: ${output}"
done
