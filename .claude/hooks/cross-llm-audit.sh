#!/bin/bash
# Hook: cross-llm-audit.sh
# Event: PostToolUse — Edit|Write
# Purpose: After wave/item implementation, send changes to an external LLM
#          for independent code review. Returns structured findings as
#          additionalContext so Claude can present them alongside its own assessment.
#
# OPTIONAL — disabled by default. Enable via:
#   ENABLE_CROSS_AUDIT=true + CROSS_AUDIT_API_KEY in .env (project root, git-ignored)
#   or in shell profile (~/.bashrc, ~/.config/fish/config.fish)
#
# Supports any OpenAI-compatible API (OpenAI, GitHub Models, Azure, Ollama, OpenRouter, etc.)
#
# Configuration (env vars or hooks-config.sh):
#   ENABLE_CROSS_AUDIT=true|false      — Master switch (default: false)
#   CROSS_AUDIT_PROVIDER               — "openai" or "anthropic" (default: openai)
#   CROSS_AUDIT_API_BASE               — API base URL (auto-set per provider)
#   CROSS_AUDIT_API_KEY                — API key (required when enabled)
#   CROSS_AUDIT_MODEL                  — Model to use (default: gpt-4o / claude-sonnet-4-20250514)
#   CROSS_AUDIT_TRIGGER                — "wave" or "item" (default: wave)
#   CROSS_AUDIT_CONTEXT                — "minimal", "standard", "full" (default: standard)
#   CROSS_AUDIT_LANG                   — Review language: "en" or "tr" (default: en)
#   CROSS_AUDIT_MIN_CHANGES            — Minimum changed lines to trigger (default: 10)
#   CROSS_AUDIT_TIMEOUT                — API timeout in seconds (default: 60)
#
# Exit: 0 always (non-blocking). Injects additionalContext on findings.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Load .env BEFORE hooks-config.sh ──
# Order: shell env (highest) > .env > hooks-config.sh (lowest)
# .env only fills in values not already set in shell environment.
# hooks-config.sh uses ${VAR:-default} so it respects both shell env and .env.
_ENV_FILE="${CLAUDE_PROJECT_DIR:-.}/.env"
if [[ -f "$_ENV_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Split on first '=' only (values may contain '=')
    key="${line%%=*}"
    value="${line#*=}"
    # Strip "export " prefix and whitespace from key
    key=$(echo "$key" | sed 's/^[[:space:]]*export[[:space:]]*//' | tr -d '[:space:]')
    # Strip surrounding quotes, whitespace, and inline comments from value
    value=$(echo "$value" | sed -E 's/[[:space:]]+#.*$//; s/^[[:space:]]*["'"'"']?//; s/["'"'"']?[[:space:]]*$//')
    # Only import CROSS_AUDIT_* and ENABLE_CROSS_AUDIT — don't pollute env
    # Shell env vars take precedence over .env (don't override already-set values)
    if [[ "$key" == CROSS_AUDIT_* || "$key" == "ENABLE_CROSS_AUDIT" ]]; then
      # Use eval-free indirect expansion compatible with bash 3.2+
      eval "_cur_val=\${$key:-}"
      [[ -z "$_cur_val" ]] && export "$key=$value"
    fi
  done < "$_ENV_FILE"
fi

source "$HOOKS_DIR/../hooks-config.sh"

# ── Master switch ──
[[ "${ENABLE_CROSS_AUDIT:-false}" != "true" ]] && exit 0

# ── Dependencies ──
command -v jq >/dev/null 2>&1 || exit 0
command -v curl >/dev/null 2>&1 || exit 0

# ── API key required ──
[[ -z "${CROSS_AUDIT_API_KEY:-}" ]] && exit 0

# ── Safety: reject keys that look like they were hardcoded (not from env) ──
# If the key is found verbatim in hooks-config.sh, someone pasted it into a git-tracked file.
# Only check real keys (20+ chars) to avoid false positives on short test values.
_CONFIG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks-config.sh"
if [[ ${#CROSS_AUDIT_API_KEY} -ge 20 && -f "$_CONFIG_FILE" ]] \
   && grep -qF "${CROSS_AUDIT_API_KEY}" "$_CONFIG_FILE" 2>/dev/null; then
  echo "Cross-audit: BLOCKED — your API key is in hooks-config.sh (git-tracked!)." >&2
  echo "  Move it to your shell profile (~/.bashrc or ~/.config/fish/config.fish) instead." >&2
  exit 0
fi

# ── Read hook input ──
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only trigger on Edit or Write
[[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]] && exit 0

# ── Detect audit mode ──
# Close Gate file → holistic sprint review (full sprint diff against main)
# Entry Gate file → plan review
# Source file → per-edit review (existing behavior)
AUDIT_MODE="per-edit"
case "$FILE" in
  *_CLOSE_GATE*.md) AUDIT_MODE="close-gate" ;;
  *_ENTRY_GATE*.md) AUDIT_MODE="entry-gate" ;;
  *TRACKING*.md|*CLAUDE.md|*WORKFLOW*.md|*[Rr]oadmap*.md|*ROADMAP*.md|*SPRINT_CLOSE*|\
  *GUARDRAILS*|*LESSONS*|*.json|*.yaml|*.yml|*.toml|*.lock|*.env*) exit 0 ;;
esac

# ── Configuration defaults ──
PROVIDER="${CROSS_AUDIT_PROVIDER:-openai}"  # "openai" or "anthropic"
API_BASE="${CROSS_AUDIT_API_BASE:-}"
MODEL="${CROSS_AUDIT_MODEL:-}"
# Set provider-specific defaults
if [[ "$PROVIDER" == "anthropic" ]]; then
  API_BASE="${API_BASE:-https://api.anthropic.com}"
  MODEL="${MODEL:-claude-sonnet-4-20250514}"
else
  API_BASE="${API_BASE:-https://api.openai.com/v1}"
  MODEL="${MODEL:-gpt-4o}"
fi
TRIGGER="${CROSS_AUDIT_TRIGGER:-wave}"
CONTEXT_LEVEL="${CROSS_AUDIT_CONTEXT:-standard}"
AUDIT_LANG="${CROSS_AUDIT_LANG:-en}"
MIN_CHANGES="${CROSS_AUDIT_MIN_CHANGES:-10}"
TIMEOUT="${CROSS_AUDIT_TIMEOUT:-60}"

# ── Trigger control: wave vs item ──
# For "wave" mode, we use a counter file to batch changes.
# The audit fires after the Nth source file edit (default: when user is asked for approval).
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# Counter file uses project dir hash + username for stable identity across hook invocations.
# Per-user counters prevent race conditions when multiple developers share a machine.
# Override with CROSS_AUDIT_COUNTER_FILE env var for testing.
_PROJECT_HASH=$(echo "$PROJECT_DIR" | sha256sum 2>/dev/null | cut -c1-8 \
  || echo "$PROJECT_DIR" | md5sum 2>/dev/null | cut -c1-8 \
  || echo "$PROJECT_DIR" | md5 -q 2>/dev/null | cut -c1-8 \
  || echo "$PROJECT_DIR" | shasum 2>/dev/null | cut -c1-8 \
  || echo "default")
_USER_ID="${USER:-${LOGNAME:-unknown}}"
COUNTER_FILE="${CROSS_AUDIT_COUNTER_FILE:-/tmp/.cross-audit-counter-${_PROJECT_HASH}-${_USER_ID}}"

# Gate reviews always fire immediately — wave counting only applies to per-edit
if [[ "$AUDIT_MODE" == "per-edit" && "$TRIGGER" == "wave" ]]; then
  # Increment counter (atomic via flock if available)
  # Returns exit code 0 = threshold reached (continue to audit),
  #                    7 = below threshold (skip audit).
  # Uses code 7 (not 0/1) so callers can distinguish "skip" from errors.
  _do_wave_count() {
    COUNT=0
    [[ -f "$COUNTER_FILE" ]] && COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
    COUNT=$((COUNT + 1))
    echo "$COUNT" > "$COUNTER_FILE"

    # In wave mode, only fire every 5th edit (approximating wave completion)
    # OR when explicitly signaled via CROSS_AUDIT_FIRE=true
    if [[ "$COUNT" -lt 5 && "${CROSS_AUDIT_FIRE:-}" != "true" ]]; then
      return 7
    fi
    # Reset counter after firing
    echo "0" > "$COUNTER_FILE"
    return 0
  }

  # Use flock for atomic counter access if available; fallback to direct access
  if command -v flock >/dev/null 2>&1; then
    _wave_skip=false
    (
      flock -w 5 200 || exit 1
      _do_wave_count
    ) 200>"${COUNTER_FILE}.lock"
    [[ $? -eq 7 ]] && exit 0
  else
    _do_wave_count || exit 0
  fi
fi

# ── Gather diff (strategy depends on audit mode) ──
cd "$PROJECT_DIR" 2>/dev/null || exit 0

if [[ "$AUDIT_MODE" == "close-gate" ]]; then
  # Holistic: full sprint diff against main branch
  MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
  # Try common main branch names
  for branch in "$MAIN_BRANCH" main master; do
    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
      COMBINED_DIFF=$(git diff "$branch"...HEAD -- ':!*.env' ':!*.env.*' ':!*.key' ':!*.pem' ':!*.p12' ':!*credentials*' ':!*secrets*' 2>/dev/null || true)
      break
    fi
  done
  # Increase truncation limit for holistic review (more context needed)
  MAX_DIFF_CHARS=48000
elif [[ "$AUDIT_MODE" == "entry-gate" ]]; then
  # Entry Gate: send the gate report content itself, not code diff
  COMBINED_DIFF=""
  [[ -f "$FILE" ]] && COMBINED_DIFF=$(cat "$FILE" 2>/dev/null || true)
  MAX_DIFF_CHARS=32000
else
  # Per-edit: current uncommitted changes (staged + unstaged vs HEAD)
  # Exclude sensitive files from diff sent to external LLM
  COMBINED_DIFF=$(git diff HEAD -- ':!*.env' ':!*.env.*' ':!*.key' ':!*.pem' ':!*.p12' ':!*credentials*' ':!*secrets*' 2>/dev/null || true)
  MAX_DIFF_CHARS=24000
fi

# Check minimum change threshold (skip for entry-gate — always review the plan)
if [[ -z "$COMBINED_DIFF" ]]; then
  exit 0
fi
if [[ "$AUDIT_MODE" == "per-edit" ]]; then
  CHANGED_LINES=$(echo "$COMBINED_DIFF" | grep -cE '^\+[^+]|^-[^-]' 2>/dev/null || echo 0)
  if [[ "$CHANGED_LINES" -lt "$MIN_CHANGES" ]]; then
    exit 0
  fi
else
  CHANGED_LINES=$(echo "$COMBINED_DIFF" | wc -l | tr -d ' ')
fi

# Truncate if too large
if [[ ${#COMBINED_DIFF} -gt $MAX_DIFF_CHARS ]]; then
  COMBINED_DIFF="${COMBINED_DIFF:0:$MAX_DIFF_CHARS}

... [TRUNCATED — diff exceeded ${MAX_DIFF_CHARS} chars] ..."
fi

# ── Secret scrubbing ──
# Strip lines that look like they contain secrets before sending to external LLM.
# Matches: API keys, tokens, passwords, private keys, connection strings.
# Conservative: replaces the value portion only, preserves the key name for context.
# Well-known token prefixes (any context — bare, quoted, assigned)
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E 's/sk-ant-[a-zA-Z0-9_-]{20,}/[REDACTED]/g' 2>/dev/null || echo "$COMBINED_DIFF")
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E 's/sk-[a-zA-Z0-9_-]{20,}/[REDACTED]/g' 2>/dev/null || echo "$COMBINED_DIFF")
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E 's/ghp_[a-zA-Z0-9]{36,}/[REDACTED]/g' 2>/dev/null || echo "$COMBINED_DIFF")
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E 's/gho_[a-zA-Z0-9]{36,}/[REDACTED]/g' 2>/dev/null || echo "$COMBINED_DIFF")
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E 's/ghu_[a-zA-Z0-9]{36,}/[REDACTED]/g' 2>/dev/null || echo "$COMBINED_DIFF")
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E 's/xox[bpsar]-[a-zA-Z0-9-]{10,}/[REDACTED]/g' 2>/dev/null || echo "$COMBINED_DIFF")
# Key=value assignments (API_KEY="...", password: "...", secret = '...', token: "...")
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E "s/(api[_-]?key|secret[_-]?key|secret_?|password|passwd|token|credential|auth[_-]?token|access[_-]?key)(['\"]?[[:space:]]*[:=][[:space:]]*['\"]?)([^'\" ]{8,})/\1\2[REDACTED]/gi" 2>/dev/null || echo "$COMBINED_DIFF")
# Bearer tokens
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E 's/(Bearer )[a-zA-Z0-9_.=-]{20,}/\1[REDACTED]/g' 2>/dev/null || echo "$COMBINED_DIFF")
# Private key blocks
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E 's/-----BEGIN [A-Z ]* PRIVATE KEY-----/[PRIVATE KEY REDACTED]/g' 2>/dev/null || echo "$COMBINED_DIFF")
# Connection strings with embedded passwords
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | sed -E 's#(mysql|postgres|postgresql|mongodb|redis|amqp)(://[^:]+:)[^@]+(@)#\1\2[REDACTED]\3#g' 2>/dev/null || echo "$COMBINED_DIFF")

# ── Build context layers ──

# Layer 1: Always — active item from TRACKING.md
ITEM_CONTEXT=""
TRACKING=$(find "$PROJECT_DIR" -maxdepth 2 -name "TRACKING*.md" 2>/dev/null | sort | head -1)
if [[ -f "$TRACKING" ]]; then
  ACTIVE_ITEMS=$(grep -E '^\| CORE-[0-9]+' "$TRACKING" \
    | awk -F'|' '{gsub(/^ +| +$/,"",$4); if ($4=="in_progress" || $4=="fixed") print $0}' \
    | head -5 2>/dev/null || true)
  [[ -n "$ACTIVE_ITEMS" ]] && ITEM_CONTEXT="## Active Items (from TRACKING.md)
$ACTIVE_ITEMS"
fi

# Layer 1: Critical axis from CLAUDE.md
CRITICAL_AXIS=""
CLAUDE_MD=$(find "$PROJECT_DIR" -maxdepth 1 -name "CLAUDE.md" 2>/dev/null | head -1)
if [[ -f "$CLAUDE_MD" ]]; then
  AXIS_LINE=$(grep -i "critical.*axis\|#1 priority\|critical priority" "$CLAUDE_MD" 2>/dev/null | head -1)
  [[ -n "$AXIS_LINE" ]] && CRITICAL_AXIS="## Critical Axis
$AXIS_LINE"
fi

# Layer 2: Guardrails (standard + full)
GUARDRAILS_CONTEXT=""
if [[ "$CONTEXT_LEVEL" == "standard" || "$CONTEXT_LEVEL" == "full" ]]; then
  GUARDRAILS=$(find "$PROJECT_DIR" -maxdepth 3 -name "*GUARDRAILS*" -o -name "*guardrails*" 2>/dev/null | sort | head -1)
  if [[ -f "$GUARDRAILS" ]]; then
    # Send first 3000 chars of guardrails
    GUARDRAILS_CONTENT=$(head -c 3000 "$GUARDRAILS")
    GUARDRAILS_CONTEXT="## Coding Rules (project guardrails)
$GUARDRAILS_CONTENT"
  fi
fi

# Layer 2: Failure modes from Entry Gate (standard + full)
FAILURE_MODES=""
if [[ "$CONTEXT_LEVEL" == "standard" || "$CONTEXT_LEVEL" == "full" ]]; then
  ENTRY_GATE=$(find "$PROJECT_DIR" -maxdepth 3 -name "S*_ENTRY_GATE.md" 2>/dev/null | sort -r | head -1)
  if [[ -f "$ENTRY_GATE" ]]; then
    FM_SECTION=$(sed -n '/[Ff]ailure [Mm]ode/,/^##/p' "$ENTRY_GATE" | head -40)
    [[ -n "$FM_SECTION" ]] && FAILURE_MODES="## Predicted Failure Modes (from Entry Gate)
$FM_SECTION"
  fi
fi

# Layer 3: Full file context (full only)
FULL_FILE_CONTEXT=""
if [[ "$CONTEXT_LEVEL" == "full" && -f "$FILE" ]]; then
  FILE_CONTENT=$(head -c 8000 "$FILE")
  FULL_FILE_CONTEXT="## Full File Context ($FILE)
\`\`\`
$FILE_CONTENT
\`\`\`"
fi

# ── Language directive ──
LANG_DIRECTIVE="Respond in English."
[[ "$AUDIT_LANG" == "tr" ]] && LANG_DIRECTIVE="Respond in Turkish (Türkçe)."

# ── Build review prompt (mode-specific) ──
if [[ "$AUDIT_MODE" == "close-gate" ]]; then
  MODE_INSTRUCTIONS="You are performing a HOLISTIC SPRINT REVIEW. This is the complete diff of all changes in this sprint (all items merged). ${LANG_DIRECTIVE}

${CRITICAL_AXIS}

${ITEM_CONTEXT}

${GUARDRAILS_CONTEXT}

${FAILURE_MODES}

## Full Sprint Changes
\`\`\`diff
${COMBINED_DIFF}
\`\`\`

## Instructions
This is a holistic review of the ENTIRE sprint, not a single edit. Focus on:
1. Cross-item consistency — do items work together correctly? API contracts match between producer/consumer?
2. Naming and pattern consistency across all changed files
3. Critical axis violations (if specified above)
4. Architectural coherence — is the overall design sound?
5. Missing integration points — do new components connect properly?
6. Security issues across the full change set
7. Coding rules violations (if guardrails provided)

Return JSON: {\"verdict\":\"PASS|WARN|BLOCK\",\"summary\":\"...\",\"findings\":[{\"severity\":\"high|medium|low\",\"file\":\"path\",\"line\":N,\"issue\":\"...\",\"suggestion\":\"...\"}]}
Focus on cross-cutting concerns that per-edit reviews would miss. Be concise."

elif [[ "$AUDIT_MODE" == "entry-gate" ]]; then
  MODE_INSTRUCTIONS="You are reviewing a SPRINT PLAN (Entry Gate report) for completeness and risks. ${LANG_DIRECTIVE}

${CRITICAL_AXIS}

## Entry Gate Report
${COMBINED_DIFF}

## Instructions
Review this sprint plan for:
1. Missing failure modes — are there obvious risks not covered?
2. Scope realism — is this achievable in one sprint? Too many must items?
3. Dependency gaps — are item dependencies identified?
4. Acceptance criteria quality — are they specific and testable?
5. Critical axis coverage — do items touching the critical axis have deeper analysis?
6. Missing items — is there an obvious gap in the plan?

Return JSON: {\"verdict\":\"PASS|WARN|BLOCK\",\"summary\":\"...\",\"findings\":[{\"severity\":\"high|medium|low\",\"item\":\"CORE-NNN\",\"issue\":\"...\",\"suggestion\":\"...\"}]}
Be concise. Focus on real planning gaps, not formatting."

else
  MODE_INSTRUCTIONS="You are a code reviewer performing an independent audit. ${LANG_DIRECTIVE}

${CRITICAL_AXIS}

${ITEM_CONTEXT}

${GUARDRAILS_CONTEXT}

${FAILURE_MODES}

${FULL_FILE_CONTEXT}

## Changes to Review
\`\`\`diff
${COMBINED_DIFF}
\`\`\`

## Instructions
Review the changes for:
1. Acceptance criteria coverage — are the active items properly addressed?
2. Critical axis violations (if specified above)
3. Coding rules violations (if guardrails provided)
4. Bugs, edge cases, missed error handling
5. Predicted risks — are failure modes addressed?
6. Security issues (injection, auth bypass, data exposure)

Return JSON: {\"verdict\":\"PASS|WARN|BLOCK\",\"summary\":\"...\",\"findings\":[{\"severity\":\"high|medium|low\",\"file\":\"path\",\"line\":N,\"issue\":\"...\",\"suggestion\":\"...\"}]}
Only use BLOCK for critical bugs or security issues. Be concise."
fi

REVIEW_PROMPT="$MODE_INSTRUCTIONS"

# ── API call (provider-specific) ──
if [[ "$PROVIDER" == "anthropic" ]]; then
  REQUEST_BODY=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$REVIEW_PROMPT" \
    '{
      "model": $model,
      "messages": [{"role": "user", "content": $prompt}],
      "max_tokens": 2000,
      "temperature": 0.1
    }')

  RESPONSE=$(curl -s --max-time "$TIMEOUT" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CROSS_AUDIT_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    "${API_BASE}/v1/messages" \
    -d "$REQUEST_BODY" 2>/dev/null) || {
    echo "Cross-audit: API call failed (timeout or network error)" >&2
    exit 0
  }
else
  REQUEST_BODY=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$REVIEW_PROMPT" \
    '{
      "model": $model,
      "messages": [{"role": "user", "content": $prompt}],
      "temperature": 0.1,
      "max_tokens": 2000
    }')

  RESPONSE=$(curl -s --max-time "$TIMEOUT" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${CROSS_AUDIT_API_KEY}" \
    "${API_BASE}/chat/completions" \
    -d "$REQUEST_BODY" 2>/dev/null) || {
    echo "Cross-audit: API call failed (timeout or network error)" >&2
    exit 0
  }
fi

# ── Parse response (provider-specific) ──
if [[ "$PROVIDER" == "anthropic" ]]; then
  API_ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null)
  [[ -z "$API_ERROR" ]] && API_ERROR=$(echo "$RESPONSE" | jq -r '.error.type // empty' 2>/dev/null)
  CONTENT=$(echo "$RESPONSE" | jq -r '[.content[] | select(.type=="text") | .text] | join("")' 2>/dev/null)
  PROMPT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.input_tokens // "?"' 2>/dev/null)
  COMPLETION_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.output_tokens // "?"' 2>/dev/null)
else
  API_ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null)
  CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  PROMPT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.prompt_tokens // "?"' 2>/dev/null)
  COMPLETION_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens // "?"' 2>/dev/null)
fi

if [[ -n "$API_ERROR" ]]; then
  echo "Cross-audit: API error — $API_ERROR" >&2
  exit 0
fi
if [[ -z "$CONTENT" ]]; then
  echo "Cross-audit: Empty response from API" >&2
  exit 0
fi

# Try to parse verdict from JSON response
VERDICT=$(echo "$CONTENT" | jq -r '.verdict // empty' 2>/dev/null || true)
[[ -z "$VERDICT" ]] && VERDICT="UNKNOWN"

# ── Emit additionalContext ──
# Claude sees this and presents it alongside its own assessment.

DIRECTIVE=""
case "$VERDICT" in
  BLOCK)
    DIRECTIVE="DIRECTIVE: This external audit found BLOCKING issues. Present these findings to the user. Do NOT proceed until the user reviews and decides."
    ;;
  WARN)
    DIRECTIVE="DIRECTIVE: This external audit found warnings. Present these findings alongside your own assessment. Let the user decide whether to address them now or proceed."
    ;;
  PASS)
    DIRECTIVE="DIRECTIVE: External audit passed. Mention this to the user as additional confidence signal."
    ;;
  *)
    DIRECTIVE="DIRECTIVE: Present these external audit findings to the user for review."
    ;;
esac

CONFLICT_RULE="If your assessment conflicts with the external audit on any point, present both perspectives clearly and let the user decide. Do not silently override either opinion."

jq -n \
  --arg content "$CONTENT" \
  --arg verdict "$VERDICT" \
  --arg model "$MODEL" \
  --arg prompt_tokens "$PROMPT_TOKENS" \
  --arg completion_tokens "$COMPLETION_TOKENS" \
  --arg directive "$DIRECTIVE" \
  --arg conflict "$CONFLICT_RULE" \
  --arg changed "$CHANGED_LINES" \
'{
  "additionalContext": (
    "=== CROSS-LLM AUDIT RESULT ===\n" +
    "Model: " + $model + " | Lines changed: " + $changed + " | Tokens: ~" + $prompt_tokens + " in / ~" + $completion_tokens + " out\n" +
    "Verdict: " + $verdict + "\n\n" +
    $content + "\n\n" +
    $directive + "\n" +
    $conflict + "\n" +
    "================================"
  )
}'

exit 0
