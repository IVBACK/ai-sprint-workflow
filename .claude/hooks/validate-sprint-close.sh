#!/usr/bin/env bash
# Hook: validate-sprint-close.sh
# Event: PostToolUse — Write
# Purpose: After a Sprint Close report (S<N>_SPRINT_CLOSE.md) is written,
#          validate DETERMINISTIC conditions only.
#
# Section quality (retrospective depth, baseline completeness, handoff clarity)
# is validated semantically by the AI via AGENT-RULES.md — not by keyword scanning.
# Keyword scanning was removed (2026-03-16): "retrospect" keyword ≠ good retrospective.
#
# What remains:
#   - Roadmap checkmarks (deterministic: [x] or [~] present?)
#   - Deferred items acknowledged (deterministic: deferred count > 0 in TRACKING?)

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_VALIDATE_SPRINT_CLOSE" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || { echo "jq not found, skipping. Install: apt/brew/pacman/choco install jq" >&2; exit 0; }

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$TOOL" != "Write" ]] && exit 0
[[ "$FILE" != *"_SPRINT_CLOSE.md"* ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

SPRINT=$(basename "$FILE" | grep -oE 'S[0-9]+')
WARNINGS=()

# --- Deterministic checks only ---

# Check: roadmap checkmarks updated
ROADMAP=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 3 -name "Roadmap.md" 2>/dev/null | head -1)
if [[ -f "$ROADMAP" ]]; then
    if ! grep -qE "\[x\]|\[~\]" "$ROADMAP" 2>/dev/null; then
        WARNINGS+=("No checked items ([x] or [~]) in Roadmap.md — sprint items should be marked complete.")
    fi
fi

# Check: deferred items count (deterministic — count from TRACKING.md table)
TRACKING=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 -name "TRACKING.md" 2>/dev/null | head -1)
if [[ -f "$TRACKING" ]]; then
    DEFERRED=$(grep -E '^\| CORE-[0-9]+' "$TRACKING" \
        | awk -F'|' '{gsub(/^ +| +$/,"",$4); if ($4=="deferred") print}' \
        | wc -l | tr -d ' ')
    if [[ "$DEFERRED" -gt 0 ]]; then
        WARNINGS+=("$DEFERRED deferred item(s) in TRACKING.md — Sprint Close should acknowledge what carries to next sprint.")
    fi
fi

# --- Output ---
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo "⚠ Sprint Close ($SPRINT) — structural checks:" >&2
    for w in "${WARNINGS[@]}"; do
        echo "  - $w" >&2
    done
    exit 1
fi

exit 0
