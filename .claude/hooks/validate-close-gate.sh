#!/bin/bash
# Hook: validate-close-gate.sh
# Event: PostToolUse — Write
# Purpose: After a Close Gate report (S<N>_CLOSE_GATE.md) is written:
#   1. Check TRACKING.md for must items that are unverified (CP4)
#   2. Warn if all metrics are DEFERRED (blocking guard)
# WORKFLOW.md rules:
#   - Close Gate Phase 1b: "Must item unverifiable → surface CP4 AUDIT SIGNAL"
#   - Close Gate Pre-Verdict Guard: 7-point checklist must pass before verdict
#   - Close Gate Guard: "Blocked if ALL metrics are DEFERRED"
# Exit: 1 (warning, non-blocking) on issues.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_VALIDATE_CLOSE_GATE" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$TOOL" != "Write" ]] && exit 0
[[ "$FILE" != *"_CLOSE_GATE.md"* ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

SPRINT=$(basename "$FILE" | grep -oE 'S[0-9]+')
WARNINGS=()
CP4_SIGNALS=()

# --- CP4: Scan TRACKING.md for must items without evidence ---
TRACKING=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 -name "TRACKING.md" 2>/dev/null | head -1)

if [[ -f "$TRACKING" ]]; then
    # Must items: open or in_progress status with no evidence
    # Table format: | CORE-### | summary | status | sprint | priority | evidence |
    # Look for rows where status=open/in_progress AND evidence column is empty
    UNVERIFIED=$(grep -E '^\| CORE-[0-9]+' "$TRACKING" \
        | awk -F'|' '{
            gsub(/^ +| +$/,"",$4); # status
            gsub(/^ +| +$/,"",$6); # evidence (col: ID|summary|status|sprint|evidence)
            if (($4=="open" || $4=="in_progress" || $4=="fixed") && $6=="") {
                print $2" ["$4"]"
            }
        }')

    if [[ -n "$UNVERIFIED" ]]; then
        while IFS= read -r item; do
            CP4_SIGNALS+=("  $item")
        done <<< "$UNVERIFIED"
    fi

    # Check if ALL metrics are DEFERRED (blocking guard)
    TOTAL_METRICS=$(grep -cE '^\| CORE-[0-9]+' "$TRACKING" 2>/dev/null || echo 0)
    DEFERRED_COUNT=$(grep -E '^\| CORE-[0-9]+' "$TRACKING" \
        | awk -F'|' '{gsub(/^ +| +$/,"",$4); if ($4=="deferred") print}' \
        | wc -l | tr -d ' ')

    if [[ "$TOTAL_METRICS" -gt 0 && "$DEFERRED_COUNT" -eq "$TOTAL_METRICS" ]]; then
        WARNINGS+=("BLOCKING GUARD: All $TOTAL_METRICS items are DEFERRED — Close Gate verdict cannot proceed.")
        WARNINGS+=("  At least one item must be verified before Close Gate can close.")
    fi
fi

# --- Output ---
HAS_ISSUES=false

if [[ ${#CP4_SIGNALS[@]} -gt 0 ]]; then
    HAS_ISSUES=true
    echo "⚠ CP4 AUDIT SIGNAL — Unverified items in TRACKING.md:" >&2
    for sig in "${CP4_SIGNALS[@]}"; do
        echo "$sig" >&2
    done
    echo "  These items have no evidence. Close Gate verdict should not proceed" >&2
    echo "  until each item is verified, deferred with reason, or explicitly escalated." >&2
    echo "" >&2
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    HAS_ISSUES=true
    for w in "${WARNINGS[@]}"; do
        echo "⚠ $w" >&2
    done
    echo "" >&2
fi

if [[ "$HAS_ISSUES" == "true" ]]; then
    echo "Resolve the above before declaring Close Gate verdict." >&2
    exit 1
fi

exit 0
