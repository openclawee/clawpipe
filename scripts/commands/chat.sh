#!/usr/bin/env bash
set -euo pipefail

chat_usage() {
  cat <<'EOF'
Usage:
  clawpipe chat --topic "..." [--rounds 3] [--config path] [--context-lines 8] [--dry-run]

Options:
  --topic          Required. Topic for the multi-agent dialogue.
  --rounds         Number of rounds per agent. Default: 3
  --config         Agent TSV file path. Default: config/agents.example.tsv
  --context-lines  Recent transcript lines injected each turn. Default: 8
  --dry-run        Do not call OpenClaw; use mock responses.
EOF
}

clawpipe_chat() {
  local root_dir="${1:?missing root dir}"
  shift

  # shellcheck source=../lib/common.sh
  source "$root_dir/scripts/lib/common.sh"
  # shellcheck source=../lib/config.sh
  source "$root_dir/scripts/lib/config.sh"
  # shellcheck source=../lib/context.sh
  source "$root_dir/scripts/lib/context.sh"
  # shellcheck source=../lib/openclaw.sh
  source "$root_dir/scripts/lib/openclaw.sh"

  local topic=""
  local rounds=3
  local context_lines=8
  local dry_run=0
  local config_file="$root_dir/config/agents.example.tsv"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --topic)
        topic="${2:-}"
        shift 2
        ;;
      --rounds)
        rounds="${2:-3}"
        shift 2
        ;;
      --context-lines)
        context_lines="${2:-8}"
        shift 2
        ;;
      --config)
        config_file="${2:-$config_file}"
        shift 2
        ;;
      --dry-run)
        dry_run=1
        shift
        ;;
      -h|--help)
        chat_usage
        return 0
        ;;
      *)
        fail "Unknown argument: $1"
        ;;
    esac
  done

  [[ -n "$topic" ]] || { chat_usage; fail "--topic is required"; }
  is_integer "$rounds" || fail "--rounds must be a non-negative integer"
  is_integer "$context_lines" || fail "--context-lines must be a non-negative integer"

  local resolved_config
  resolved_config="$(resolve_path "$root_dir" "$config_file")"
  load_agents "$resolved_config" "$root_dir"

  if [[ "$dry_run" -eq 0 ]]; then
    openclaw_available || fail "openclaw command not found; use --dry-run to test without runtime"
  fi

  local runtime_dir="$root_dir/runtime"
  ensure_dir "$runtime_dir"
  local session_id
  session_id="$(date +%Y%m%d-%H%M%S)"
  local transcript="$runtime_dir/transcript-$session_id.log"
  : > "$transcript"

  log_info "Topic: $topic"
  log_info "Agents: ${#AGENT_NAMES[@]}, rounds per agent: $rounds"
  log_info "Transcript: $transcript"
  [[ "$dry_run" -eq 1 ]] && log_warn "Dry-run mode enabled; using mock output"

  printf 'HOST: Topic => %s\n' "$topic" | tee -a "$transcript" >/dev/null

  local agent_count="${#AGENT_NAMES[@]}"
  local total_turns=$((agent_count * rounds))

  local turn idx name user_id persona_file context prompt raw_output clean_output
  for ((turn=0; turn<total_turns; turn++)); do
    idx=$((turn % agent_count))
    name="${AGENT_NAMES[$idx]}"
    user_id="${AGENT_USERS[$idx]}"
    persona_file="${AGENT_PERSONAS[$idx]}"

    context="$(build_recent_context "$transcript" "$context_lines")"
    prompt="$(build_turn_prompt "$topic" "$context" "$name" "$((turn+1))")"

    if [[ "$dry_run" -eq 1 ]]; then
      raw_output="$(mock_chat "$user_id" "$prompt")"
    else
      raw_output="$(openclaw_chat "$user_id" "$persona_file" "$prompt")"
    fi
    clean_output="$(sanitize_output "$raw_output")"
    [[ -n "$clean_output" ]] || clean_output="[no output]"

    printf '%s: %s\n' "$name" "$clean_output" | tee -a "$transcript"
  done

  log_info "Done."
}
