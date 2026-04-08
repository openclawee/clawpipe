#!/usr/bin/env bash
set -euo pipefail

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Missing required command: $cmd"
    exit 1
  fi
}

fail() {
  log_error "$*"
  exit 1
}

ensure_dir() {
  local dir="$1"
  mkdir -p "$dir"
}

is_integer() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

sanitize_output() {
  local text="${1:-}"
  text="${text//$'\r'/}"
  # Collapse multi-line output into one readable line for transcript.
  printf '%s' "$text" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'
}

resolve_path() {
  local root_dir="${1:?missing root dir}"
  local raw_path="${2:?missing path}"

  if [[ "$raw_path" == /* ]]; then
    printf '%s\n' "$raw_path"
  else
    printf '%s\n' "$root_dir/${raw_path#./}"
  fi
}

