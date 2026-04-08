#!/usr/bin/env bash
set -euo pipefail

openclaw_available() {
  command -v openclaw >/dev/null 2>&1
}

openclaw_chat() {
  local user_id="${1:?missing user id}"
  local persona_file="${2:?missing persona file}"
  local prompt="${3:?missing prompt}"
  local stream="${4:-0}"

  local persona_text
  persona_text="$(<"$persona_file")"

  local -a cmd
  cmd=(openclaw chat --user "$user_id" --system "$persona_text" --message "$prompt")
  if [[ "$stream" == "1" ]]; then
    cmd+=(--stream)
  fi

  "${cmd[@]}"
}

mock_chat() {
  local user_id="${1:?missing user id}"
  local prompt="${2:?missing prompt}"
  local snippet
  snippet="$(printf '%s' "$prompt" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-80)"
  printf '[mock/%s] %s\n' "$user_id" "$snippet"
}
