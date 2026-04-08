#!/usr/bin/env bash
set -euo pipefail

build_recent_context() {
  local transcript_file="$1"
  local ctx_lines="${2:-8}"

  if [[ ! -f "$transcript_file" ]]; then
    printf "%s\n" "No transcript yet."
    return 0
  fi

  tail -n "$ctx_lines" "$transcript_file"
}

build_turn_prompt() {
  local topic="${1:?missing topic}"
  local recent_context="${2:?missing recent context}"
  local agent_name="${3:?missing agent name}"
  local turn_no="${4:?missing turn number}"

  cat <<EOF
[TOPIC]
$topic

[GROUP_CONTEXT]
$recent_context

[TURN_TASK]
你是 ${agent_name}。
当前是第 ${turn_no} 轮发言。
先回应最近一条与你相关的观点，再补充一个新观点。
避免重复，保持简洁。
EOF
}
