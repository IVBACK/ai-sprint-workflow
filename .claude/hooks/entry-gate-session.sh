#!/bin/bash
# Hook: entry-gate-session.sh
# Event: PostToolUse — Write
# Purpose: When an Entry Gate report (S<N>_ENTRY_GATE.md) is created,
#          inject a mandatory session boundary recommendation.
#          WORKFLOW.md rule: "After Entry Gate approval → recommend new session
#          for implementation. AI cannot assess its own context usage —
#          recommendations are mandatory at known heavy-context points."

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_ENTRY_GATE_SESSION" != "true" ]] && exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Trigger only on Write of S<N>_ENTRY_GATE.md
[[ "$TOOL" != "Write" ]] && exit 0
[[ "$FILE" != *"_ENTRY_GATE.md"* ]] && exit 0

SPRINT=$(basename "$FILE" | grep -oE 'S[0-9]+')

jq -n --arg sprint "$SPRINT" '{
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
