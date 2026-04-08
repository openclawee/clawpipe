#!/usr/bin/env bash
set -euo pipefail

ansi_enabled() {
  [[ -t 1 ]]
}

color_code_for_name() {
  local color_name="${1:-default}"
  case "$color_name" in
    red) printf '%s' "31" ;;
    green) printf '%s' "32" ;;
    yellow) printf '%s' "33" ;;
    blue) printf '%s' "34" ;;
    magenta) printf '%s' "35" ;;
    cyan) printf '%s' "36" ;;
    white) printf '%s' "37" ;;
    *) printf '%s' "0" ;;
  esac
}

agent_badge() {
  local name="${1:-agent}"
  local short
  short="$(printf '%s' "$name" | tr -cd '[:alnum:]' | cut -c1-2)"
  [[ -n "$short" ]] || short="AG"
  printf '[%s]' "${short^^}"
}

render_room_header() {
  local topic="${1:?missing topic}"
  local strategy="${2:?missing strategy}"
  local total_turns="${3:?missing total turns}"
  local dry_run="${4:?missing dry run flag}"

  printf '\n'
  printf '=== ClawPipe Chat Room =========================================\n'
  printf 'Topic: %s\n' "$topic"
  printf 'Strategy: %s | Max turns: %s | Mode: %s\n' "$strategy" "$total_turns" "$([[ "$dry_run" == "1" ]] && printf 'dry-run' || printf 'openclaw')"
  printf '===============================================================\n'
}

render_agent_init() {
  local name="${1:?missing name}"
  local user_id="${2:?missing user id}"
  printf 'INIT  %-12s -> %s\n' "$name" "$user_id"
}

render_chat_message() {
  local turn_no="${1:?missing turn no}"
  local total_turns="${2:?missing total turns}"
  local name="${3:?missing name}"
  local color_name="${4:-default}"
  local message="${5:-}"
  local badge
  badge="$(agent_badge "$name")"

  if ansi_enabled; then
    local code
    code="$(color_code_for_name "$color_name")"
    printf '\033[1;90m[%02d/%02d]\033[0m \033[%sm%s %-12s\033[0m %s\n' \
      "$turn_no" "$total_turns" "$code" "$badge" "$name" "$message"
  else
    printf '[%02d/%02d] %s %-12s %s\n' "$turn_no" "$total_turns" "$badge" "$name" "$message"
  fi
}

render_room_footer() {
  local transcript_path="${1:?missing transcript path}"
  printf '%s\n' '---------------------------------------------------------------'
  printf 'Transcript: %s\n' "$transcript_path"
}
