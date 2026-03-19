#!/usr/bin/env bash
# setup-audit.sh — Cross-LLM Audit Setup
# Run in terminal: bash .claude/setup-audit.sh
#
# API keys must NEVER be pasted into an LLM conversation.
# This script collects your key via hidden input (read -s)
# and writes it to .env (git-ignored).

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"
PROTECT_HOOK="$PROJECT_DIR/.claude/hooks/protect-secrets.sh"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.json"

# ── Colors ──
_green()  { printf '\033[32m%s\033[0m' "$1"; }
_red()    { printf '\033[31m%s\033[0m' "$1"; }
_dim()    { printf '\033[2m%s\033[0m' "$1"; }
_bold()   { printf '\033[1m%s\033[0m' "$1"; }
_check()  { printf '  \033[32m✓\033[0m %s\n' "$1"; }
_fail()   { printf '  \033[31m✗\033[0m %s\n' "$1"; }

# ── Cleanup trap ──
_SETUP_TMPFILES=()
_setup_cleanup() { for f in "${_SETUP_TMPFILES[@]}"; do rm -f "$f" 2>/dev/null; done; }
trap _setup_cleanup EXIT INT TERM

# ── Safety check: protect-secrets hook must be active ──
if [[ ! -f "$PROTECT_HOOK" ]]; then
    _fail "protect-secrets.sh not found. Run bootstrap first."
    exit 1
elif [[ ! -f "$SETTINGS_FILE" ]] || ! grep -q "protect-secrets.sh" "$SETTINGS_FILE" 2>/dev/null; then
    _fail "protect-secrets.sh not registered in settings.json."
    echo "    API key protection is not active — aborting."
    exit 1
fi

# ── Provider selection ──
echo ""
echo "  $(_bold 'Cross-LLM Audit Setup')"
echo "  ─────────────────────"
echo ""
echo "  Select provider:"
echo ""
echo "    1) OpenAI          $(_dim '(gpt-4o)')"
echo "    2) Anthropic       $(_dim '(claude-sonnet)')"
echo "    3) GitHub Models   $(_dim '(free with Copilot)')"
echo "    4) OpenRouter      $(_dim '(any model)')"
echo "    5) Ollama          $(_dim '(local, free)')"
echo "    6) LM Studio       $(_dim '(local, free)')"
echo "    7) Custom endpoint"
echo ""
read -rp "  → [1-7]: " CHOICE

case "${CHOICE}" in
  1) PROVIDER="openai";    API_BASE="https://api.openai.com/v1";             DEFAULT_MODEL="gpt-4o";                    NEEDS_KEY=true ;;
  2) PROVIDER="anthropic"; API_BASE="https://api.anthropic.com";             DEFAULT_MODEL="claude-sonnet-4-20250514";   NEEDS_KEY=true ;;
  3) PROVIDER="openai";    API_BASE="https://models.inference.ai.azure.com"; DEFAULT_MODEL="gpt-4o";                    NEEDS_KEY=gh ;;
  4) PROVIDER="openai";    API_BASE="https://openrouter.ai/api/v1";         DEFAULT_MODEL="openai/gpt-4o";             NEEDS_KEY=true ;;
  5) PROVIDER="openai";    API_BASE="http://localhost:11434/v1";             DEFAULT_MODEL="llama3";                    NEEDS_KEY=false ;;
  6) PROVIDER="openai";    API_BASE="http://localhost:1234/v1";              DEFAULT_MODEL="default";                   NEEDS_KEY=false ;;
  7) PROVIDER="openai";    read -rp "  API base URL: " API_BASE; read -rp "  Model name: " DEFAULT_MODEL; NEEDS_KEY=true ;;
  *) echo "Invalid choice."; exit 1 ;;
esac

# ── Collect model + API key + verify (with retry) ──
_collect_and_verify() {
    read -rp "  Model [$DEFAULT_MODEL]: " MODEL_INPUT
    MODEL="${MODEL_INPUT:-$DEFAULT_MODEL}"

    API_KEY=""
    if [[ "$NEEDS_KEY" == "true" ]]; then
      echo ""
      echo "  Paste API key (hidden):"
      read -rs API_KEY
      echo "  $(_dim '(received)')"
      [[ -z "$API_KEY" ]] && { _fail "API key cannot be empty."; return 1; }
    elif [[ "$NEEDS_KEY" == "gh" ]]; then
      if command -v gh >/dev/null 2>&1; then
        API_KEY="$(gh auth token 2>/dev/null || true)"
        if [[ -n "$API_KEY" ]]; then
          _check "Using GitHub CLI token"
        else
          echo "  gh auth token empty. Paste a GitHub PAT:"
          read -rs API_KEY
          echo "  $(_dim '(received)')"
        fi
      else
        echo "  gh CLI not found. Paste a GitHub PAT:"
        read -rs API_KEY
        echo "  $(_dim '(received)')"
      fi
    else
      API_KEY="no-key-needed"
      _check "No API key needed (local)"
    fi

    # Verify connection
    [[ "$NEEDS_KEY" == "false" ]] && return 0

    echo ""
    echo "  Testing connection..."

    local TEST_RESPONSE HTTP_CODE RESPONSE_BODY ERROR_MSG
    if [[ "$PROVIDER" == "anthropic" ]]; then
        TEST_RESPONSE=$(curl -s --max-time 10 -w "\n%{http_code}" \
            -H "x-api-key: $API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d '{"model":"'"$MODEL"'","max_tokens":5,"messages":[{"role":"user","content":"hi"}]}' \
            "$API_BASE/v1/messages" 2>/dev/null) || true
    else
        TEST_RESPONSE=$(curl -s --max-time 10 -w "\n%{http_code}" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -d '{"model":"'"$MODEL"'","max_tokens":5,"messages":[{"role":"user","content":"hi"}]}' \
            "$API_BASE/chat/completions" 2>/dev/null) || true
    fi

    HTTP_CODE=$(echo "$TEST_RESPONSE" | tail -1)
    RESPONSE_BODY=$(echo "$TEST_RESPONSE" | sed '$d')
    ERROR_MSG=$(echo "$RESPONSE_BODY" | jq -r '.error.message // empty' 2>/dev/null)

    case "$HTTP_CODE" in
        200) _check "Connection OK"; return 0 ;;
        429) _check "Key valid (rate limited, temporary)"; return 0 ;;
        401|403) _fail "Unauthorized ($HTTP_CODE). Key may be wrong or expired." ;;
        404)     _fail "Model '$MODEL' not found ($HTTP_CODE)." ;;
        000|"")
            if [[ "$API_BASE" == *"localhost"* ]]; then
                _fail "Can't reach $API_BASE — is Ollama/LM Studio running?"
            else
                _fail "Can't reach $API_BASE — check network."
            fi ;;
        *)       _fail "API returned HTTP $HTTP_CODE." ;;
    esac
    [[ -n "$ERROR_MSG" ]] && echo "    $(_dim "$ERROR_MSG")"

    echo ""
    echo "    r) Retry   s) Save anyway   q) Quit"
    read -rp "    → " RETRY_CHOICE
    case "$RETRY_CHOICE" in
        [Rr]) return 1 ;;
        [Ss]) return 0 ;;
        *)    echo "  Aborted."; exit 1 ;;
    esac
}

while ! _collect_and_verify; do
    echo ""
    echo "  ─── Retrying ($PROVIDER / $API_BASE) ───"
    echo ""
done

# ── Write .env ──
EXISTING_VARS=""
if [[ -f "$ENV_FILE" ]]; then
  cp "$ENV_FILE" "${ENV_FILE}.bak" || { echo "ERROR: Failed to backup .env" >&2; exit 1; }
  EXISTING_VARS=$(grep -v '^\s*#' "$ENV_FILE" | grep -v '^CROSS_AUDIT_' | grep -v '^\s*$' || true)
fi

ENV_TMP=$(mktemp "${ENV_FILE}.tmp.XXXXXX") || { echo "ERROR: mktemp failed" >&2; exit 1; }
_SETUP_TMPFILES+=("$ENV_TMP")
{
  echo "# Cross-LLM Audit — generated $(date +%Y-%m-%d)"
  echo ""
  printf 'CROSS_AUDIT_API_KEY="%s"\n' "$API_KEY"
  echo "CROSS_AUDIT_PROVIDER=$PROVIDER"
  echo "CROSS_AUDIT_API_BASE=$API_BASE"
  echo "CROSS_AUDIT_MODEL=$MODEL"
  if [[ -n "$EXISTING_VARS" ]]; then
    echo ""
    echo "# Preserved from previous .env"
    echo "$EXISTING_VARS"
  fi
} > "$ENV_TMP" || { rm -f "$ENV_TMP"; echo "ERROR: write failed" >&2; exit 1; }
[[ -f "$ENV_FILE" ]] && chmod --reference="$ENV_FILE" "$ENV_TMP" 2>/dev/null || true
mv -f "$ENV_TMP" "$ENV_FILE" || { echo "ERROR: install failed" >&2; exit 1; }

# ── Done ──
echo ""
echo "  ─────────────────────"
_check "Done — $PROVIDER / $MODEL"
echo ""
if [[ "${CALLED_FROM_INIT:-}" != "1" ]]; then
  echo "    Go back to your AI conversation and continue."
  echo "    Reconfig: $(_dim 'bash .claude/setup-audit.sh')"
  echo ""
fi
