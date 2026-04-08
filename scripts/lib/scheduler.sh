#!/usr/bin/env bash
set -euo pipefail

# Strategy:
# - round_robin: deterministic, fair cycling
# - random: simple random pick, avoiding immediate repeat when possible
scheduler_next_index() {
  local strategy="${1:?missing strategy}"
  local turn_no="${2:?missing turn number}"
  local agent_count="${3:?missing agent count}"
  local prev_idx="${4:--1}"

  if [[ "$agent_count" -le 0 ]]; then
    echo "[ERROR] agent_count must be > 0" >&2
    return 1
  fi

  local next_idx
  case "$strategy" in
    round_robin)
      next_idx=$((turn_no % agent_count))
      ;;
    random)
      next_idx=$((RANDOM % agent_count))
      if [[ "$agent_count" -gt 1 && "$next_idx" -eq "$prev_idx" ]]; then
        next_idx=$(((next_idx + 1) % agent_count))
      fi
      ;;
    *)
      echo "[ERROR] unknown strategy: $strategy (supported: round_robin, random)" >&2
      return 1
      ;;
  esac

  printf '%s\n' "$next_idx"
}
