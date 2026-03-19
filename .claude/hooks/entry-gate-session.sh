#!/usr/bin/env bash
# Hook: entry-gate-session.sh
# Event: PostToolUse — Write
# Purpose: When an Entry Gate report (S<N>_ENTRY_GATE.md) is created,
#          inject mandatory session boundary recommendation.
#
# Content quality (failure modes, verification plans, metrics) is validated
# semantically by the AI via AGENT-RULES.md — not by keyword scanning.
# Keyword scanning was removed (2026-03-16): "failure mode" keyword ≠ good analysis.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_ENTRY_GATE_SESSION" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || { echo "jq not found, skipping. Install: apt/brew/pacman/choco install jq" >&2; exit 0; }

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$TOOL" != "Write" ]] && exit 0
[[ "$FILE" != *"_ENTRY_GATE.md"* ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

SPRINT=$(basename "$FILE" | grep -oE 'S[0-9]+')

# --- Always inject session boundary (mandatory) ---
# This is the only mechanical check: Entry Gate written → recommend new session.
# This is deterministic (file event), not semantic (quality judgment).

jq -n \
  --arg sprint "$SPRINT" \
'{
  "additionalContext": (
    "=== MANDATORY SESSION BOUNDARY (WORKFLOW.md) ===\n" +
    "Entry Gate report for \($sprint) has been written.\n" +
    "REQUIRED: Recommend to the user that they start a new session before implementation.\n" +
    "Exact message to surface:\n" +
    "  \"Entry Gate complete. Context is heavy from the analysis phase.\n" +
    "   Recommend starting a new session for implementation — type '\''Continue sprint \($sprint)'\''.\"\n" +
    "Do NOT begin implementation in this session. Wait for user decision.\n" +
    "================================================="
  )
}'
