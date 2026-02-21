#!/bin/bash
# Hook: validate-sprint-close.sh
# Event: PostToolUse — Write
# Purpose: After a Sprint Close report (S<N>_SPRINT_CLOSE.md) is written,
#          validate required retrospective sections are present.
# WORKFLOW.md rules:
#   - Step 7: Failure mode retrospective must be present
#   - Step 5: Performance baseline update required if measurable metric exists
#   - Step 10: User handoff summary required
#   - Sprint Close checklist: all items must be addressed
# Exit: 1 (warning, non-blocking) on missing sections.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_VALIDATE_SPRINT_CLOSE" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$TOOL" != "Write" ]] && exit 0
[[ "$FILE" != *"_SPRINT_CLOSE.md"* ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

SPRINT=$(basename "$FILE" | grep -oE 'S[0-9]+')
WARNINGS=()

# --- Required sections ---

# Step 7: Failure mode retrospective
if ! grep -qi "retrospect\|failure mode\|step 7\|predicted.*failure\|actual.*failure" "$FILE" 2>/dev/null; then
    WARNINGS+=("Missing: Failure mode retrospective (Step 7) — were predicted failures encountered? Any unpredicted ones?")
fi

# Step 5: Baseline log
if ! grep -qi "baseline\|performance.*log\|metric.*log\|step 5" "$FILE" 2>/dev/null; then
    WARNINGS+=("Missing: Performance baseline update (Step 5) — record measurable metrics for next sprint comparison.")
fi

# Step 10: User handoff
if ! grep -qi "handoff\|what changed\|before.*after\|step 10\|verify.*running\|what to verify" "$FILE" 2>/dev/null; then
    WARNINGS+=("Missing: User handoff summary (Step 10) — what changed, where, what to verify in the running app.")
fi

# Check: roadmap checkmarks updated (look in Roadmap.md, not in Sprint Close file)
ROADMAP=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 3 -name "Roadmap.md" 2>/dev/null | head -1)
if [[ -f "$ROADMAP" ]]; then
    if ! grep -qE "\[x\]|\[~\]" "$ROADMAP" 2>/dev/null; then
        WARNINGS+=("Warning: No checked items ([x] or [~]) in Roadmap.md — sprint items should be marked complete at Sprint Close.")
    fi
fi

# Check: TRACKING.md deferred items acknowledged
TRACKING=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 -name "TRACKING.md" 2>/dev/null | head -1)
if [[ -f "$TRACKING" ]]; then
    DEFERRED=$(grep -E '^\| CORE-[0-9]+' "$TRACKING" \
        | awk -F'|' '{gsub(/^ +| +$/,"",$4); if ($4=="deferred") print}' \
        | wc -l | tr -d ' ')
    if [[ "$DEFERRED" -gt 0 ]]; then
        if ! grep -qi "deferred\|carry.*next\|next sprint" "$FILE" 2>/dev/null; then
            WARNINGS+=("Warning: $DEFERRED deferred item(s) in TRACKING.md — Sprint Close should acknowledge what carries to next sprint.")
        fi
    fi
fi

# --- Output ---
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "⚠ Sprint Close ($SPRINT) — missing sections:" >&2
    for w in "${WARNINGS[@]}"; do
        echo "  - $w" >&2
    done
    echo "  Complete these sections before handing off to the user." >&2
    exit 1
fi

exit 0
