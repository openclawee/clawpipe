#!/usr/bin/env bash
set -euo pipefail

chat_usage() {
  cat <<'EOF'
Usage:
  clawpipe chat [--topic "..."] [--max-turns 9] [--strategy round_robin] [--config path] [--context-lines 8] [--dry-run]

Options:
  --topic          Optional. If omitted, CLI asks interactively.
  --max-turns      Maximum total turns. Default: 9
  --strategy       Scheduling strategy: round_robin | random (default: round_robin)
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
  # shellcheck source=../lib/scheduler.sh
  source "$root_dir/scripts/lib/scheduler.sh"
  # shellcheck source=../lib/render.sh
  source "$root_dir/scripts/lib/render.sh"

  local topic=""
  local max_turns=9
  local context_lines=8
  local dry_run=0
  local strategy="round_robin"
  local config_file="$root_dir/config/agents.example.tsv"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --topic)
        topic="${2:-}"
        shift 2
        ;;
      --max-turns)
        max_turns="${2:-9}"
        shift 2
        ;;
      --rounds)
        # Backward-compatible alias.
        max_turns="${2:-9}"
        shift 2
        ;;
      --strategy)
        strategy="${2:-round_robin}"
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

  if [[ -z "$topic" ]]; then
    printf '🎯 输入一个讨论主题: '
    IFS= read -r topic || true
  fi
  [[ -n "$topic" ]] || fail "topic is required"
  is_integer "$max_turns" || fail "--max-turns must be a non-negative integer"
  [[ "$max_turns" -gt 0 ]] || fail "--max-turns must be > 0"
  is_integer "$context_lines" || fail "--context-lines must be a non-negative integer"
  [[ "$strategy" == "round_robin" || "$strategy" == "random" ]] || fail "--strategy must be round_robin or random"

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

  render_room_header "$topic" "$strategy" "$max_turns" "$dry_run"
  log_info "Transcript: $transcript"
  [[ "$dry_run" -eq 1 ]] && log_warn "Dry-run mode enabled; using mock output"

  printf 'HOST: Topic => %s\n' "$topic" >> "$transcript"

  local agent_count="${#AGENT_NAMES[@]}"
  local total_turns="$max_turns"
  local last_speaker_idx=-1

  local turn idx name user_id persona_file context prompt raw_output clean_output color
  for ((turn=0; turn<total_turns; turn++)); do
    idx="$(scheduler_next_index "$strategy" "$turn" "$agent_count" "$last_speaker_idx")"
    name="${AGENT_NAMES[$idx]}"
    user_id="${AGENT_USERS[$idx]}"
    persona_file="${AGENT_PERSONAS[$idx]}"
    color="${AGENT_COLORS[$idx]}"

    context="$(build_recent_context "$transcript" "$context_lines")"
    prompt="$(build_turn_prompt "$topic" "$context" "$name" "$((turn+1))")"

    if [[ "$dry_run" -eq 1 ]]; then
      raw_output="$(mock_chat "$user_id" "$prompt")"
    else
      raw_output="$(openclaw_chat "$user_id" "$persona_file" "$prompt")"
    fi
    clean_output="$(sanitize_output "$raw_output")"
    [[ -n "$clean_output" ]] || clean_output="[no output]"

    render_chat_message "$((turn+1))" "$total_turns" "$name" "$color" "$clean_output"
    printf '%s: %s\n' "$name" "$clean_output" >> "$transcript"
    last_speaker_idx="$idx"
  done

  render_room_footer "$transcript"
  log_info "Done."
}
