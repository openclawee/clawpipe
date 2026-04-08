#!/usr/bin/env bash
set -euo pipefail

load_agents() {
  local config_file="${1:?missing config file}"
  local root_dir="${2:?missing root dir}"

  if [[ ! -f "$config_file" ]]; then
    fail "Config file not found: $config_file"
  fi

  AGENT_NAMES=()
  AGENT_USERS=()
  AGENT_PERSONAS=()
  AGENT_COLORS=()

  local line name user_id persona_file color
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    IFS=$'\t' read -r name user_id persona_file color <<<"$line"
    if [[ -z "${name:-}" || -z "${user_id:-}" || -z "${persona_file:-}" ]]; then
      fail "Invalid config line (need 3+ tab-separated fields): $line"
    fi

    local persona_abs
    persona_abs="$(resolve_path "$root_dir" "$persona_file")"
    [[ -f "$persona_abs" ]] || fail "Persona file not found: $persona_abs"

    AGENT_NAMES+=("$name")
    AGENT_USERS+=("$user_id")
    AGENT_PERSONAS+=("$persona_abs")
    AGENT_COLORS+=("${color:-default}")
  done <"$config_file"

  if [[ "${#AGENT_NAMES[@]}" -eq 0 ]]; then
    fail "No agents loaded from: $config_file"
  fi
}
