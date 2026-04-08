# ClawPipe

Terminal-native multi-agent orchestration built on top of OpenClaw.

## ⚙️ Built on OpenClaw

ClawPipe uses OpenClaw as its underlying runtime:

- multi-user memory
- tool calling
- isolated agent contexts

Each OpenClaw user is treated as one autonomous agent.  
ClawPipe orchestrates those agents into a living group-chat style AI system.

## Current scaffold (Bash MVP)

This repository now includes a runnable Bash framework for:

- mapping agent -> OpenClaw user
- loading persona prompts
- round-robin multi-agent dialogue
- shared context via transcript windowing
- dry-run mode for local testing

## Quick start

### 1) Requirements

- Bash 4+
- OpenClaw CLI available as `openclaw` in `PATH` (for real runtime mode)

### 2) Agent config

Use tab-separated config: `config/agents.example.tsv`

```text
# name    user_id                                  persona_file                 color
architect cp.clawpipe.dev.architect.p9af31c2b     ./personas/architect.md      cyan
skeptic   cp.clawpipe.dev.skeptic.p12bd8aa1       ./personas/skeptic.md        yellow
builder   cp.clawpipe.dev.builder.p66e0b71d       ./personas/builder.md        green
```

### 3) Run dry-run (no OpenClaw required)

```bash
chmod +x bin/clawpipe
./bin/clawpipe chat \
  --topic "测试：AI Agent 如何自治" \
  --rounds 1 \
  --config ./config/agents.example.tsv \
  --dry-run
```

### 4) Run with OpenClaw

```bash
./bin/clawpipe chat \
  --topic "AI Agent 社会治理机制" \
  --rounds 3 \
  --context-lines 10 \
  --config ./config/agents.example.tsv
```

Session logs are written to `runtime/transcript-<timestamp>.log`.

## Directory layout

```text
bin/
  clawpipe                   # CLI entrypoint
scripts/
  commands/
    chat.sh                  # Dialogue loop (N-agent round-robin)
  lib/
    common.sh                # Common helpers
    config.sh                # Agent config loading (TSV)
    context.sh               # Shared context composer
    openclaw.sh              # OpenClaw adapter + dry-run mock
    scheduler.sh             # Turn scheduling strategies
config/
  agents.example.tsv         # 3-agent sample config
personas/
  architect.md
  skeptic.md
  builder.md
runtime/
  .gitkeep
```

## Minimal runnable loop (now evolved to N-agent scheduler)

For the shortest end-to-end chain using `openclaw chat --user`, run:

```bash
chmod +x scripts/mvp_minimal.sh
./scripts/mvp_minimal.sh
```

This script is intentionally minimal but now supports:
- N agents (array configured in script)
- configurable max turns (`MAX_TURNS`, default 6)
- scheduling strategy (`SCHEDULER_POLICY`):
  - `round_robin` (default)
  - `random`
- previous output is passed to the next agent as group context
- each agent has an independent persona file injected as system prompt
- startup performs one-time persona initialization for each OpenClaw user

### Minimal scheduler usage

```bash
# default: round_robin + 6 turns
./scripts/mvp_minimal.sh

# custom strategy and turns (set in-script constants)
# SCHEDULER_POLICY="random"
# MAX_TURNS=4
```

### MVP persona examples

- `personas/mvp_agent1.md` (结构化、理性、架构师风格)
- `personas/mvp_agent2.md` (挑刺、反驳、质疑者风格)
