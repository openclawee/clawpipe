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
AGENT_SYSTEMS=(
  "你是 Agent1。风格简洁，先给观点，再给一个理由。"
  "你是 Agent2。你需要回应上一位并补充一个不同角度。"
)

# Shared chat context (minimal): pass latest message to next agent.
last_message="Host: 讨论主题是：${TOPIC}"

for ((turn=0; turn<TOTAL_TURNS; turn++)); do
  idx=$((turn % 2))
  name="${AGENT_NAMES[$idx]}"
  user_id="${AGENT_USERS[$idx]}"
  system_prompt="${AGENT_SYSTEMS[$idx]}"

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
