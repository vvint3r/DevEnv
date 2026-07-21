#!/usr/bin/env bash
# Installs the Claude Code CLI and OpenAI Codex CLI, then seeds their config
# files from templates in agents/ on this machine.
#
# Credentials are NEVER stored in this repo. After running this script, add
# API keys to your shell profile, or authenticate interactively:
#   Claude Code:  export ANTHROPIC_API_KEY="sk-ant-..."  (or run 'claude' to log in)
#   Codex:        export OPENAI_API_KEY="sk-..."          (or run 'codex' to log in)
# See agents/.env.example for the full reference.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"

SKIP_CLAUDE=0
SKIP_CODEX=0
FORCE_CONFIGS=0
REINSTALL=0

usage() {
  cat <<'USAGE'
Usage:
  setup-agents.sh [options]

Installs the Claude Code CLI and OpenAI Codex CLI via npm, then seeds their
config files (~/.claude/settings.json and ~/.codex/config.toml) from the
templates under agents/ — only if the target file does not already exist.

Credentials are not handled here. After running, set ANTHROPIC_API_KEY and
OPENAI_API_KEY in your shell profile, or authenticate each CLI interactively.
See agents/.env.example for details.

Options:
  --skip-claude      Skip Claude Code install and config.
  --skip-codex       Skip Codex install and config.
  --force-configs    Overwrite existing config files with repo templates (backs
                     up the current file first).
  --reinstall        Re-run npm install even if the CLI is already in PATH.
  -h, --help         Show this help.

Examples:
  # Full setup
  bash scripts/setup-agents.sh

  # Claude only (e.g. no OpenAI subscription)
  bash scripts/setup-agents.sh --skip-codex

  # Re-deploy config templates without reinstalling
  bash scripts/setup-agents.sh --force-configs
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-claude)   SKIP_CLAUDE=1; shift ;;
    --skip-codex)    SKIP_CODEX=1; shift ;;
    --force-configs) FORCE_CONFIGS=1; shift ;;
    --reinstall)     REINSTALL=1; shift ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

# Ensure npm is on PATH; sources nvm if present.
ensure_npm() {
  if command -v npm >/dev/null 2>&1; then
    return 0
  fi
  local nvm_sh="${NVM_DIR:-$HOME/.nvm}/nvm.sh"
  if [[ -s "$nvm_sh" ]]; then
    # shellcheck disable=SC1090
    source "$nvm_sh"
    command -v npm >/dev/null 2>&1 && return 0
  fi
  echo "ERROR: npm not found. Install Node.js (https://nodejs.org) or nvm, then re-run." >&2
  return 1
}

# Seed a config file from a repo template; respects --force-configs.
seed_config() {
  local src="$1"
  local dest="$2"
  local label="$3"

  if [[ ! -f "$src" ]]; then
    echo "WARN: template not found at $src — skipping $label config seed"
    return
  fi

  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" && "$FORCE_CONFIGS" -eq 0 ]]; then
    echo "INFO: $dest already exists (use --force-configs to overwrite)"
    return
  fi

  if [[ -f "$dest" ]]; then
    local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "$dest" "$backup"
    echo "BACKUP: $backup"
  fi

  cp "$src" "$dest"
  echo "SEEDED: $dest"
}

# ── Claude Code ───────────────────────────────────────────────────────────────
if [[ "$SKIP_CLAUDE" -eq 0 ]]; then
  echo "==> Claude Code CLI"
  if ensure_npm; then
    if command -v claude >/dev/null 2>&1 && [[ "$REINSTALL" -eq 0 ]]; then
      echo "OK: claude already installed ($(claude --version 2>/dev/null | head -n1 || echo 'version unknown'))"
    else
      echo "Installing @anthropic-ai/claude-code ..."
      npm install -g @anthropic-ai/claude-code
      echo "Installed: $(claude --version 2>/dev/null | head -n1 || echo 'ok')"
    fi

    seed_config \
      "$ROOT_DIR/agents/claude/settings.json" \
      "$HOME/.claude/settings.json" \
      "Claude Code"

    echo ""
    if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
      echo "INFO: ANTHROPIC_API_KEY not set."
      echo "      Claude Max / Pro (subscription): run 'claude' — it opens a browser to log in."
      echo "      API key:  add to ~/.zshrc or ~/.bashrc:"
      echo "        export ANTHROPIC_API_KEY=\"sk-ant-api03-...\""
    else
      echo "OK: ANTHROPIC_API_KEY is set."
    fi
  fi
  echo ""
fi

# ── OpenAI Codex ──────────────────────────────────────────────────────────────
if [[ "$SKIP_CODEX" -eq 0 ]]; then
  echo "==> OpenAI Codex CLI"
  if ensure_npm; then
    if command -v codex >/dev/null 2>&1 && [[ "$REINSTALL" -eq 0 ]]; then
      echo "OK: codex already installed"
    else
      echo "Installing @openai/codex ..."
      npm install -g @openai/codex
      echo "Installed: codex"
    fi

    seed_config \
      "$ROOT_DIR/agents/codex/config.toml" \
      "$HOME/.codex/config.toml" \
      "Codex"

    echo ""
    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
      echo "INFO: OPENAI_API_KEY not set."
      echo "      ChatGPT Plus/Pro does NOT include API credits — you need a separate"
      echo "      platform.openai.com billing plan. Then add to ~/.zshrc or ~/.bashrc:"
      echo "        export OPENAI_API_KEY=\"sk-...\""
    else
      echo "OK: OPENAI_API_KEY is set."
    fi
  fi
  echo ""
fi

echo "Agent setup complete."
echo "See agents/.env.example in the repo for the full credential reference."
