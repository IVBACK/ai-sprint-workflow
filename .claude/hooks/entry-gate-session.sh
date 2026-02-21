#!/bin/bash
# Hook: entry-gate-session.sh
# Event: PostToolUse — Write
# Purpose: When an Entry Gate report (S<N>_ENTRY_GATE.md) is created:
#   1. Validate report has required content (failure modes, verification plans, metrics)
#   2. Inject mandatory session boundary recommendation
# WORKFLOW.md rules:
#   - Step 9a: Each item must have 3+ failure modes
#   - Step 9b: Each item must have a verification plan
#   - Step 9c: Each item must have a metric with threshold
#   - Step 12c: Verification quality review must be present
#   - After Entry Gate → mandatory new session before implementation

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_ENTRY_GATE_SESSION" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || { echo "WARNING: jq not found — entry-gate hook disabled." >&2; exit 0; }

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$TOOL" != "Write" ]] && exit 0
[[ "$FILE" != *"_ENTRY_GATE.md"* ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

SPRINT=$(basename "$FILE" | grep -oE 'S[0-9]+')

# --- Content validation ---
WARNINGS=()

# Check: failure modes section present (Step 9a)
if ! grep -qi "failure mode\|failure scenario\|9a\|fail mode" "$FILE" 2>/dev/null; then
    WARNINGS+=("Missing: Failure mode analysis (Step 9a) — each item needs 3+ failure modes.")
fi

# Check: verification plan present (Step 9b)
if ! grep -qi "verification plan\|verify\|test plan\|9b" "$FILE" 2>/dev/null; then
    WARNINGS+=("Missing: Verification plan (Step 9b) — each item needs inputs/outputs or invariants.")
fi

# Check: metric with threshold present (Step 9c / Step 10)
if ! grep -qi "metric\|threshold\|baseline\|target\|benchmark" "$FILE" 2>/dev/null; then
    WARNINGS+=("Missing: Metrics with thresholds (Step 9c) — each must item needs a measurable metric.")
fi

# Check: must item count is non-zero (Step 10 guard)
MUST_COUNT=$(grep -ciE "must" "$FILE" 2>/dev/null || true)
MUST_COUNT=${MUST_COUNT:-0}
if [[ "$MUST_COUNT" -eq 0 ]]; then
    WARNINGS+=("Warning: No 'must' items found. Entry Gate requires at least one must item to proceed.")
fi

# Check: scope check section (Step 10)
if ! grep -qi "scope\|step 10\|item count" "$FILE" 2>/dev/null; then
    WARNINGS+=("Missing: Scope check (Step 10) — must item count 1-8 required to proceed.")
fi

# --- Emit stderr warnings (non-blocking) ---
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "⚠ Entry Gate content warnings for $SPRINT:" >&2
    for w in "${WARNINGS[@]}"; do
        echo "  - $w" >&2
    done
    echo "  Review and complete missing sections before user approval." >&2
    echo "" >&2
fi

# --- Always inject session boundary (mandatory) ---
WARNING_TEXT=""
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    WARNING_TEXT="\nContent warnings were raised (see stderr). Address before implementation.\n"
fi

jq -n \
  --arg sprint "$SPRINT" \
  --arg warnings "$WARNING_TEXT" \
'{
  "additionalContext": (
    "=== MANDATORY SESSION BOUNDARY (WORKFLOW.md) ===\n" +
    "Entry Gate report for \($sprint) has been written.\n" +
    $warnings +
    "REQUIRED: Recommend to the user that they start a new session before implementation.\n" +
    "Exact message to surface:\n" +
    "  \"Entry Gate complete. Context is heavy from the analysis phase.\n" +
    "   Recommend starting a new session for implementation — type '\''Continue sprint \($sprint)'\''.\"\n" +
    "Do NOT begin implementation in this session. Wait for user decision.\n" +
    "================================================="
  )
}'
