#!/bin/bash
# setup-audit.sh — Interactive Cross-LLM Audit Setup
# Run this script directly in your terminal: bash .claude/setup-audit.sh
#
# WHY: API keys must NEVER be pasted into an LLM conversation.
# This script collects your key via hidden terminal input (read -s)
# and writes it to .env (git-ignored). The LLM never sees the key.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$PROJECT_DIR/.env"
PROTECT_HOOK="$PROJECT_DIR/.claude/hooks/protect-secrets.sh"
SETTINGS_FILE="$PROJECT_DIR/.claude/settings.json"

# ── Cleanup trap: remove temp files on exit/interrupt ──
_SETUP_TMPFILES=()
_setup_cleanup() { for f in "${_SETUP_TMPFILES[@]}"; do rm -f "$f" 2>/dev/null; done; }
trap _setup_cleanup EXIT INT TERM

# ── Safety check: hook protection must be in place AND registered ──
_hook_safe=true
_fail_reason=""

# Check 1: Does protect-secrets.sh exist?
if [[ ! -f "$PROTECT_HOOK" ]]; then
    _hook_safe=false
    _fail_reason="protect-secrets.sh hook file not found"
# Check 2: Is it registered in settings.json?
elif [[ ! -f "$SETTINGS_FILE" ]]; then
    _hook_safe=false
    _fail_reason="settings.json not found — hooks are not registered"
elif ! grep -q "protect-secrets.sh" "$SETTINGS_FILE" 2>/dev/null; then
    _hook_safe=false
    _fail_reason="protect-secrets.sh exists but is NOT registered in settings.json"
fi

if [[ "$_hook_safe" != "true" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ERROR: API key protection is not active!           ║"
    echo "╠══════════════════════════════════════════════════════╣"
    echo "║                                                     ║"
    echo "║  Cross-LLM audit stores your API key in .env.       ║"
    echo "║  The protect-secrets.sh hook must be both present   ║"
    echo "║  AND registered in .claude/settings.json so that    ║"
    echo "║  Claude Code runs it before every Read/Bash call.   ║"
    echo "║                                                     ║"
    echo "║  Without this, the AI agent can read .env and       ║"
    echo "║  EXPOSE your API key in the conversation.           ║"
    echo "║                                                     ║"
    echo "║  This only works with Claude Code — other AI tools  ║"
    echo "║  (Copilot, Cursor, ChatGPT) do not support hooks.  ║"
    echo "║                                                     ║"
    echo "║  Reason: $( printf '%-38s' "$_fail_reason" )║"
    echo "║                                                     ║"
    echo "║  To fix: bootstrap the project with Claude Code     ║"
    echo "║  (Step 8.5 in WORKFLOW.md creates the hooks).       ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# ── Confirm Claude Code usage ──
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  IMPORTANT: Claude Code Required                    ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Cross-LLM audit relies on Claude Code hooks to     ║"
echo "║  protect your API key. These hooks ONLY work with   ║"
echo "║  Claude Code (CLI or VS Code extension).            ║"
echo "║                                                     ║"
echo "║  If you use Copilot, Cursor, or other AI tools,     ║"
echo "║  the hooks won't run and your API key may be        ║"
echo "║  exposed to the AI.                                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
read -rp "Are you using Claude Code? [y/N]: " USING_CLAUDE
if [[ ! "$USING_CLAUDE" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Cross-LLM audit cannot be safely used without Claude Code."
    echo "The protect-secrets.sh hook only runs inside Claude Code."
    echo "Aborting setup."
    echo ""
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║       Cross-LLM Audit — Interactive Setup           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  What is this?"
echo "  You're already using an AI (Claude, GPT, etc.) to write code."
echo "  Cross-LLM Audit adds a SECOND AI that silently reviews every"
echo "  code change your primary AI makes — like an automated code"
echo "  reviewer running in the background."
echo ""
echo "  How it works:"
echo "  1. Your primary AI writes/edits code as usual"
echo "  2. A hook automatically sends the diff to a second AI"
echo "  3. The second AI reviews for bugs, security issues, blind spots"
echo "  4. Results appear inline — your primary AI presents both opinions"
echo "  5. You decide what to act on"
echo ""
echo "  Cost: depends on model. Ollama/LM Studio = free (local)."
echo "        Cloud APIs charge per token — see your provider's pricing."
echo "  Frequency: every ~5 code edits by default (configurable)"
echo "  Privacy: only code diffs are sent, secrets are auto-scrubbed"
echo ""
echo "  Your API key stays local (.env, git-ignored) — never sent to the AI."
echo ""

# ── Provider selection ──
echo "Select a provider:"
echo ""
echo "  1) OpenAI          (gpt-4o)                  — recommended"
echo "  2) Anthropic       (claude-sonnet)           — if primary is non-Claude"
echo "  3) GitHub Models   (uses your gh auth token) — free with Copilot"
echo "  4) OpenRouter      (any model)               — multi-model gateway"
echo "  5) Ollama (local)  (no API key needed)       — fully offline"
echo "  6) LM Studio       (no API key needed)       — fully offline"
echo "  7) Custom endpoint                           — Azure, etc."
echo ""
read -rp "Choice [1-7]: " CHOICE

case "${CHOICE}" in
  1)
    PROVIDER="openai"
    API_BASE="https://api.openai.com/v1"
    DEFAULT_MODEL="gpt-4o"
    NEEDS_KEY=true
    ;;
  2)
    PROVIDER="anthropic"
    API_BASE="https://api.anthropic.com"
    DEFAULT_MODEL="claude-sonnet-4-20250514"
    NEEDS_KEY=true
    ;;
  3)
    PROVIDER="openai"
    API_BASE="https://models.inference.ai.azure.com"
    DEFAULT_MODEL="gpt-4o"
    NEEDS_KEY=gh
    ;;
  4)
    PROVIDER="openai"
    API_BASE="https://openrouter.ai/api/v1"
    DEFAULT_MODEL="openai/gpt-4o"
    NEEDS_KEY=true
    ;;
  5)
    PROVIDER="openai"
    API_BASE="http://localhost:11434/v1"
    DEFAULT_MODEL="llama3"
    NEEDS_KEY=false
    ;;
  6)
    PROVIDER="openai"
    API_BASE="http://localhost:1234/v1"
    DEFAULT_MODEL="default"
    NEEDS_KEY=false
    ;;
  7)
    PROVIDER="openai"
    read -rp "API base URL: " API_BASE
    read -rp "Model name: " DEFAULT_MODEL
    NEEDS_KEY=true
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# ── Collect model, API key, and verify — with retry on failure ──
_collect_and_verify() {
    # ── Model override ──
    read -rp "Model [$DEFAULT_MODEL]: " MODEL_INPUT
    MODEL="${MODEL_INPUT:-$DEFAULT_MODEL}"

    # ── API key ──
    API_KEY=""
    if [[ "$NEEDS_KEY" == "true" ]]; then
      echo ""
      echo "Paste your API key below (input is hidden):"
      read -rs API_KEY
      echo "(received)"
      if [[ -z "$API_KEY" ]]; then
        echo "Error: API key cannot be empty."
        return 1
      fi
    elif [[ "$NEEDS_KEY" == "gh" ]]; then
      if command -v gh >/dev/null 2>&1; then
        API_KEY="$(gh auth token 2>/dev/null || true)"
        if [[ -z "$API_KEY" ]]; then
          echo "Warning: 'gh auth token' returned empty. Run 'gh auth login' first."
          echo "Or paste a GitHub PAT with models:read scope:"
          read -rs API_KEY
          echo "(received)"
        else
          echo "Using GitHub CLI token (gh auth token)."
        fi
      else
        echo "'gh' CLI not found. Paste a GitHub PAT with models:read scope:"
        read -rs API_KEY
        echo "(received)"
      fi
    else
      API_KEY="no-key-needed"
      echo "No API key needed for local provider."
    fi

    # ── Verify connection ──
    if [[ "$NEEDS_KEY" == "false" ]]; then
        return 0
    fi

    echo ""
    echo "Testing connection..."

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

    # Extract error message from response body (before the HTTP code line)
    RESPONSE_BODY=$(echo "$TEST_RESPONSE" | sed '$d')
    ERROR_MSG=$(echo "$RESPONSE_BODY" | jq -r '.error.message // empty' 2>/dev/null)

    case "$HTTP_CODE" in
        200) echo "  Connection OK — API key and model are valid."; return 0 ;;
        401|403)
            echo "  WARNING: API returned $HTTP_CODE (unauthorized)."
            echo "  The key may be wrong, expired, or lack permissions."
            [[ -n "$ERROR_MSG" ]] && echo "  Detail: $ERROR_MSG"
            ;;
        404)
            echo "  WARNING: API returned 404 (not found)."
            echo "  The model '$MODEL' may not exist or is not available on this provider."
            [[ -n "$ERROR_MSG" ]] && echo "  Detail: $ERROR_MSG"
            echo ""
            echo "  Common model names:"
            echo "    OpenAI:     gpt-4o, gpt-4o-mini, gpt-4.1"
            echo "    Anthropic:  claude-sonnet-4-20250514"
            echo "    OpenRouter: openai/gpt-4o, anthropic/claude-3.5-sonnet"
            echo "    Ollama:     llama3, mistral, codellama (must be pulled first)"
            ;;
        400)
            echo "  WARNING: API returned 400 (bad request)."
            [[ -n "$ERROR_MSG" ]] && echo "  Detail: $ERROR_MSG"
            echo "  This usually means the model name is invalid for this provider."
            ;;
        000|"")
            echo "  WARNING: Could not reach $API_BASE"
            if [[ "$API_BASE" == *"localhost"* ]]; then
                echo "  Is your local model server (Ollama/LM Studio) running?"
            else
                echo "  Check your network connection."
            fi
            ;;
        429)
            echo "  WARNING: API returned 429 (rate limited)."
            echo "  The key is valid but you've hit the rate limit. This is temporary."
            echo "  Proceeding — the audit hook will retry automatically."
            return 0
            ;;
        *)
            echo "  WARNING: API returned HTTP $HTTP_CODE."
            [[ -n "$ERROR_MSG" ]] && echo "  Detail: $ERROR_MSG"
            ;;
    esac

    # If we got here, verification failed — offer retry or skip
    echo ""
    echo "  Options:"
    echo "    r) Retry — re-enter model name and/or API key"
    echo "    s) Skip — save current values anyway (you can fix later)"
    echo "    q) Quit — abort setup"
    read -rp "  Choice [r/s/q]: " RETRY_CHOICE
    case "$RETRY_CHOICE" in
        [Rr]) return 1 ;;   # signal retry
        [Ss]) return 0 ;;   # continue with current values
        *)    echo "Aborted."; exit 1 ;;
    esac
}

# Run with retry loop
while ! _collect_and_verify; do
    echo ""
    echo "--- Retrying (provider: $PROVIDER, base: $API_BASE) ---"
    echo ""
done

# ── Optional settings ──
echo ""
echo "Optional settings (press Enter for defaults):"
echo ""

echo "  Trigger mode — how often the 2nd LLM reviews your code:"
echo "    wave  = batches ~5 edits, then reviews (lower cost, recommended)"
echo "    item  = reviews after EVERY edit (thorough but higher API cost)"
echo "  Gate reviews (Entry/Close) always fire immediately regardless."
echo ""
read -rp "  Trigger mode [wave]: " TRIGGER
TRIGGER="${TRIGGER:-wave}"

echo ""
echo "  Context level — how much project info is sent with the diff:"
echo "    minimal  = diff + active items + critical axis (~2-4k tokens)"
echo "    standard = + coding guardrails + failure modes   (~4-8k tokens)"
echo "    full     = + full content of changed files       (~8-16k tokens)"
echo "  Higher context = better reviews but higher API cost per call."
echo ""
read -rp "  Context level [standard]: " CONTEXT
CONTEXT="${CONTEXT:-standard}"

echo ""
read -rp "  Review language — en or tr [en]: " LANG
LANG="${LANG:-en}"

echo ""
echo "  Min changed lines — edits smaller than this are skipped."
echo "  Prevents noisy reviews for trivial changes (typo fixes, etc.)."
echo ""
read -rp "  Min changed lines [3]: " MIN_CHANGES
MIN_CHANGES="${MIN_CHANGES:-3}"

# ── Write .env (secrets only — git-ignored) ──
# Preserve existing non-audit variables if .env exists
EXISTING_VARS=""
if [[ -f "$ENV_FILE" ]]; then
  # Backup existing .env before overwriting
  cp "$ENV_FILE" "${ENV_FILE}.bak" || { echo "ERROR: Failed to backup .env" >&2; exit 1; }
  EXISTING_VARS=$(grep -v '^\s*#' "$ENV_FILE" | grep -v '^ENABLE_CROSS_AUDIT' | grep -v '^CROSS_AUDIT_' | grep -v '^\s*$' || true)
fi

# Atomic write: build in temp file, then move into place
ENV_TMP=$(mktemp "${ENV_FILE}.tmp.XXXXXX") || { echo "ERROR: mktemp failed for .env" >&2; exit 1; }
_SETUP_TMPFILES+=("$ENV_TMP")
{
  echo "# Cross-LLM Audit — Secrets Only"
  echo "# Generated by setup-audit.sh on $(date +%Y-%m-%d)"
  echo "# All other settings are in .claude/hooks-config.local.sh"
  echo ""
  echo "ENABLE_CROSS_AUDIT=true"
  # Quote API key to prevent shell interpretation of special chars ($, `, etc.)
  printf 'CROSS_AUDIT_API_KEY="%s"\n' "$API_KEY"
  if [[ -n "$EXISTING_VARS" ]]; then
    echo ""
    echo "# Preserved from previous .env"
    echo "$EXISTING_VARS"
  fi
} > "$ENV_TMP" || { rm -f "$ENV_TMP"; echo "ERROR: Failed to write .env temp" >&2; exit 1; }
# Preserve original permissions
[[ -f "$ENV_FILE" ]] && chmod --reference="$ENV_FILE" "$ENV_TMP" 2>/dev/null || true
mv -f "$ENV_TMP" "$ENV_FILE" || { echo "ERROR: Failed to install .env" >&2; exit 1; }

# ── Write local config overrides (non-secret settings — git-ignored) ──
LOCAL_CONFIG="$PROJECT_DIR/.claude/hooks-config.local.sh"
# Backup existing local config before overwriting
if [[ -f "$LOCAL_CONFIG" ]]; then
  cp "$LOCAL_CONFIG" "${LOCAL_CONFIG}.bak" || { echo "ERROR: Failed to backup local config" >&2; exit 1; }
fi

LOCAL_TMP=$(mktemp "${LOCAL_CONFIG}.tmp.XXXXXX") || { echo "ERROR: mktemp failed for local config" >&2; exit 1; }
_SETUP_TMPFILES+=("$LOCAL_TMP")
{
  echo "# Cross-LLM Audit — Local Settings"
  echo "# Generated by setup-audit.sh on $(date +%Y-%m-%d)"
  echo "# Override any setting from hooks-config.sh here."
  echo "# See hooks-config.sh for all available settings."
  echo ""
  echo "CROSS_AUDIT_PROVIDER=$PROVIDER"
  echo "CROSS_AUDIT_API_BASE=$API_BASE"
  echo "CROSS_AUDIT_MODEL=$MODEL"
  echo "CROSS_AUDIT_TRIGGER=$TRIGGER"
  echo "CROSS_AUDIT_CONTEXT=$CONTEXT"
  echo "CROSS_AUDIT_LANG=$LANG"
  echo "CROSS_AUDIT_MIN_CHANGES=$MIN_CHANGES"
} > "$LOCAL_TMP" || { rm -f "$LOCAL_TMP"; echo "ERROR: Failed to write local config temp" >&2; exit 1; }
# Preserve original permissions
[[ -f "$LOCAL_CONFIG" ]] && chmod --reference="$LOCAL_CONFIG" "$LOCAL_TMP" 2>/dev/null || true
mv -f "$LOCAL_TMP" "$LOCAL_CONFIG" || { echo "ERROR: Failed to install local config" >&2; exit 1; }

echo ""
if [[ "${CALLED_FROM_INIT:-}" == "1" ]]; then
  # Compact summary when called from sprint-workflow init
  printf '  \033[32m✓\033[0m Audit configured: %s / %s / %s\n' "$PROVIDER" "$MODEL" "$TRIGGER"
else
  # Full banner when run standalone
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  Setup complete!                                    ║"
  echo "╠══════════════════════════════════════════════════════╣"
  echo "║                                                     ║"
  echo "║  API key:  .env (git-ignored)                       ║"
  echo "║  Settings: .claude/hooks-config.local.sh            ║"
  echo "║  Provider: $(printf '%-40s' "$PROVIDER")║"
  echo "║  Model:    $(printf '%-40s' "$MODEL")║"
  echo "║  Trigger:  $(printf '%-40s' "$TRIGGER")║"
  echo "║                                                     ║"
  echo "╠══════════════════════════════════════════════════════╣"
  echo "║  What happens now?                                  ║"
  echo "║                                                     ║"
  echo "║  1. Go back to your AI conversation                 ║"
  echo "║  2. Tell the AI: \"Cross-audit setup done\"           ║"
  echo "║  3. Continue coding as usual                        ║"
  echo "║  4. After ~5 code edits, the audit fires silently   ║"
  echo "║  5. The AI will show you the external review inline ║"
  echo "║                                                     ║"
  echo "║  You don't need to do anything else — the hook      ║"
  echo "║  runs automatically in the background.              ║"
  echo "║                                                     ║"
  echo "╠══════════════════════════════════════════════════════╣"
  echo "║  Useful commands:                                   ║"
  echo "║  Disable:  set ENABLE_CROSS_AUDIT=false in .env     ║"
  echo "║  Reconfig: bash .claude/setup-audit.sh (re-run)     ║"
  echo "║  Docs:     Docs/CROSS-LLM-AUDIT.md                 ║"
  echo "╚══════════════════════════════════════════════════════╝"
fi
echo ""
