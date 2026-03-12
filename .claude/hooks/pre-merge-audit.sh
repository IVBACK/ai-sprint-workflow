#!/bin/bash
# Script: pre-merge-audit.sh
# Purpose: Audit sub-agent work BEFORE coordinator merges it into sprint branch.
# Usage: bash .claude/hooks/pre-merge-audit.sh <worktree-path-or-branch>
# Exit: 0 = PASS/WARN (safe to merge), 1 = BLOCK (do not merge)
#
# Not a hook — called explicitly by the coordinator between waves.
# Uses the same API configuration as cross-llm-audit.sh.
#
# Example:
#   bash .claude/hooks/pre-merge-audit.sh /tmp/worktree-agent-1
#   bash .claude/hooks/pre-merge-audit.sh sprint-1-agent-branch

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# ── Load shared library ──
source "$SCRIPT_DIR/_audit-lib.sh"
_load_audit_env "$PROJECT_DIR/.env"
source "$SCRIPT_DIR/../hooks-config.sh"

AUDIT_MODE="pre-merge"

# ── Validate arguments ──
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <worktree-path-or-branch>" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 /tmp/.worktree-agent-1     # diff from worktree" >&2
  echo "  $0 sprint-1-agent-branch      # diff from branch" >&2
  _log_audit "error" "no-argument"
  exit 1
fi

SOURCE="$1"

# ── Check prerequisites ──
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
[[ -z "${CROSS_AUDIT_API_KEY:-}" ]] && { echo "CROSS_AUDIT_API_KEY not set" >&2; exit 1; }

# ── Generate diff ──
cd "$PROJECT_DIR" 2>/dev/null || exit 1

COMBINED_DIFF=""
if [[ -d "$SOURCE" ]]; then
  # Worktree path: diff between current HEAD and worktree state
  echo "Generating diff from worktree: $SOURCE" >&2
  # Get the worktree's branch/HEAD
  WT_HEAD=$(git -C "$SOURCE" rev-parse HEAD 2>/dev/null || true)
  MY_HEAD=$(git rev-parse HEAD 2>/dev/null || true)
  if [[ -n "$WT_HEAD" && -n "$MY_HEAD" && "$WT_HEAD" != "$MY_HEAD" ]]; then
    COMBINED_DIFF=$(git diff "$MY_HEAD"..."$WT_HEAD" -- \
      ':!*.env' ':!*.env.*' ':!*.key' ':!*.pem' ':!*.p12' \
      ':!*credentials*' ':!*secrets*' ':!*TRACKING*.md' \
      ':!*.json' ':!*.yaml' ':!*.yml' 2>/dev/null || true)
  fi
  # Also include uncommitted changes in worktree
  WT_UNCOMMITTED=$(git -C "$SOURCE" diff HEAD -- \
    ':!*.env' ':!*.env.*' ':!*.key' ':!*.pem' ':!*.p12' \
    ':!*credentials*' ':!*secrets*' ':!*TRACKING*.md' 2>/dev/null || true)
  [[ -n "$WT_UNCOMMITTED" ]] && COMBINED_DIFF="${COMBINED_DIFF}
${WT_UNCOMMITTED}"
elif git rev-parse --verify "$SOURCE" >/dev/null 2>&1; then
  # Branch name: diff between HEAD and branch
  echo "Generating diff from branch: $SOURCE" >&2
  COMBINED_DIFF=$(git diff HEAD..."$SOURCE" -- \
    ':!*.env' ':!*.env.*' ':!*.key' ':!*.pem' ':!*.p12' \
    ':!*credentials*' ':!*secrets*' ':!*TRACKING*.md' \
    ':!*.json' ':!*.yaml' ':!*.yml' 2>/dev/null || true)
else
  echo "Error: '$SOURCE' is not a valid worktree path or branch name" >&2
  _log_audit "error" "invalid-source"
  exit 1
fi

if [[ -z "$COMBINED_DIFF" ]]; then
  echo "No changes found in $SOURCE" >&2
  _log_audit "skip" "empty-diff"
  exit 0
fi

CHANGED_LINES=$(echo "$COMBINED_DIFF" | grep -cE '^\+[^+]|^-[^-]' 2>/dev/null || echo 0)

# Truncate
MAX_DIFF_CHARS="${CROSS_AUDIT_MAX_DIFF_WAVE:-${CROSS_AUDIT_MAX_DIFF:-32000}}"
if [[ ${#COMBINED_DIFF} -gt $MAX_DIFF_CHARS ]]; then
  COMBINED_DIFF="${COMBINED_DIFF:0:$MAX_DIFF_CHARS}

... [TRUNCATED — diff exceeded ${MAX_DIFF_CHARS} chars] ..."
fi

# Secret scrubbing
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | _scrub_secrets)

# ── Build context ──
ITEM_CONTEXT=""
TRACKING=$(find "$PROJECT_DIR" -maxdepth 2 -name "TRACKING*.md" 2>/dev/null | sort | head -1)
if [[ -f "$TRACKING" ]]; then
  ACTIVE_ITEMS=$(grep -E '^\| CORE-[0-9]+' "$TRACKING" \
    | awk -F'|' '{gsub(/^ +| +$/,"",$4); if ($4=="in_progress" || $4=="fixed") print $0}' \
    | head -5 2>/dev/null || true)
  [[ -n "$ACTIVE_ITEMS" ]] && ITEM_CONTEXT="## Active Items
$ACTIVE_ITEMS"
fi

CRITICAL_AXIS=""
CLAUDE_MD=$(find "$PROJECT_DIR" -maxdepth 1 -name "CLAUDE.md" 2>/dev/null | head -1)
if [[ -f "$CLAUDE_MD" ]]; then
  AXIS_LINE=$(grep -i "critical.*axis\|#1 priority\|critical priority" "$CLAUDE_MD" 2>/dev/null | head -1)
  [[ -n "$AXIS_LINE" ]] && CRITICAL_AXIS="## Critical Axis
$AXIS_LINE"
fi

# Layer: Guardrails
GUARDRAILS_CONTEXT=""
GUARDRAILS=$(find "$PROJECT_DIR" -maxdepth 3 -name "*GUARDRAILS*" -o -name "*guardrails*" 2>/dev/null | sort | head -1)
if [[ -f "$GUARDRAILS" ]]; then
  GUARDRAILS_CONTENT=$(head -c 3000 "$GUARDRAILS")
  GUARDRAILS_CONTEXT="## Coding Rules (project guardrails)
$GUARDRAILS_CONTENT"
fi

# Layer: Failure modes from Entry Gate
FAILURE_MODES=""
ENTRY_GATE=$(find "$PROJECT_DIR" -maxdepth 3 -name "S*_ENTRY_GATE.md" 2>/dev/null | sort -r | head -1)
if [[ -f "$ENTRY_GATE" ]]; then
  FM_SECTION=$(sed -n '/[Ff]ailure [Mm]ode/,/^##/p' "$ENTRY_GATE" | head -40)
  [[ -n "$FM_SECTION" ]] && FAILURE_MODES="## Predicted Failure Modes (from Entry Gate)
$FM_SECTION"
fi

# ── Build prompt ──
AUDIT_LANG="${CROSS_AUDIT_LANG:-en}"
LANG_DIRECTIVE="Respond in English."
[[ "$AUDIT_LANG" == "tr" ]] && LANG_DIRECTIVE="Respond in Turkish (Türkçe)."

REVIEW_PROMPT="You are reviewing sub-agent work BEFORE it is merged into the sprint branch. ${LANG_DIRECTIVE}

${CRITICAL_AXIS}

${ITEM_CONTEXT}

${GUARDRAILS_CONTEXT}

${FAILURE_MODES}

## Sub-Agent Changes (PRE-MERGE review)
\`\`\`diff
${COMBINED_DIFF}
\`\`\`

## Instructions
This code was written by a sub-agent in an isolated worktree. It has NOT been merged yet.
Your verdict determines whether the coordinator should proceed with the merge.

Focus on:
1. Correctness — bugs, logic errors, missed edge cases
2. API contract compliance — do new/changed functions match expected signatures?
3. Security — injection, auth bypass, data exposure
4. Incomplete implementation — distinguish:
   - BLOCK: placeholder code that will break at runtime (empty functions, hardcoded dummy values, panic/todo!() macros)
   - WARN: TODO comments noting future improvements that don't affect current functionality
   - PASS: intentionally deferred work documented in tracking
5. Test coverage — are there tests for the changed code? Missing tests for new public APIs = WARN
6. Critical axis violations (if specified above)
7. Coding rules violations (if guardrails provided above)
8. Predicted risk mitigation — are failure modes (if listed above) addressed?

SEVERITY DECISION TREE:
- BLOCK: security issue (injection, auth bypass, data exposure), runtime crash (null deref, unhandled error, missing import), API contract break (signature mismatch, missing required field), placeholder code that will fail at runtime, critical axis violation
- WARN: logic bug in non-critical path, missing edge case handling, missing tests for new code, TODO comments, performance concern, style violation
- PASS: clean implementation, no issues found

Return JSON: {\"verdict\":\"PASS|WARN|BLOCK\",\"summary\":\"...\",\"findings\":[{\"severity\":\"high|medium|low\",\"file\":\"path\",\"line\":N,\"issue\":\"...\",\"suggestion\":\"...\"}]}
BLOCK = do not merge (critical issues). WARN = merge with caution. PASS = safe to merge.
Be concise."

# ── API call ──
FILE="$SOURCE"
if _call_audit_api "$REVIEW_PROMPT"; then
  _log_audit "success" "" "$_AUDIT_VERDICT"

  echo "" >&2
  echo "=== PRE-MERGE AUDIT RESULT ===" >&2
  echo "Source: $SOURCE" >&2
  echo "Model: $_AUDIT_MODEL | Lines: $CHANGED_LINES | Tokens: ~$_AUDIT_PROMPT_TOKENS in / ~$_AUDIT_COMPLETION_TOKENS out" >&2
  echo "Verdict: $_AUDIT_VERDICT" >&2
  echo "" >&2
  echo "$_AUDIT_CONTENT" >&2
  echo "===============================" >&2

  # Output structured JSON to stdout (for coordinator consumption)
  jq -n \
    --arg content "$_AUDIT_CONTENT" \
    --arg verdict "$_AUDIT_VERDICT" \
    --arg source "$SOURCE" \
    --arg changed "$CHANGED_LINES" \
    '{verdict:$verdict,source:$source,changed_lines:($changed|tonumber),content:$content}'

  if [[ "$_AUDIT_VERDICT" == "BLOCK" ]]; then
    echo "" >&2
    echo "BLOCK: Do not merge this sub-agent's work until issues are resolved." >&2
    exit 1
  fi
  exit 0
else
  _log_audit "error" "api-call-failed"
  echo "Pre-merge audit failed (API error). Proceeding with caution." >&2
  exit 0
fi
