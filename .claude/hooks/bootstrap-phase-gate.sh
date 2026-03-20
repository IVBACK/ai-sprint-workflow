#!/usr/bin/env bash
# Hook: bootstrap-phase-gate.sh
# Event: PreToolUse — Write|Edit
# Purpose: During bootstrap, block CLAUDE.md and TRACKING.md creation
#          until research and review phases are complete.
#
# Complements protect-claude.sh:
#   protect-claude.sh → blocks OVERWRITE of existing CLAUDE.md
#   this hook         → blocks CREATION of new CLAUDE.md without completing phases
#
# Markers (.bootstrap/research-done, .bootstrap/review-done) are written by
# bootstrap-guard.sh (PostToolUse hook) when actual WebSearch/Agent tools are used.
# The agent cannot fake these markers.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_BOOTSTRAP_PHASE_GATE" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
BASE=$(basename "$FILE" 2>/dev/null)

# Only gate CLAUDE.md and TRACKING.md
case "$BASE" in
    CLAUDE.md|TRACKING.md|TRACKING-*.md) ;;
    *) exit 0 ;;
esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
BOOTSTRAP_DIR="$PROJECT_DIR/.bootstrap"

# Not in bootstrap if CLAUDE.md exists and is filled (no [REQUIRED] markers)
if [[ -f "$PROJECT_DIR/CLAUDE.md" ]] && ! grep -q '\[REQUIRED' "$PROJECT_DIR/CLAUDE.md" 2>/dev/null; then
    exit 0
fi

# Not a sprint workflow project if WORKFLOW.md is missing
[[ ! -f "$PROJECT_DIR/WORKFLOW.md" ]] && exit 0

# We're in bootstrap. Check markers.
RESEARCH_DONE=false
REVIEW_DONE=false
[[ -f "$BOOTSTRAP_DIR/research-done" ]] && RESEARCH_DONE=true
[[ -f "$BOOTSTRAP_DIR/review-done" ]] && REVIEW_DONE=true

if [[ "$RESEARCH_DONE" == "false" ]] || [[ "$REVIEW_DONE" == "false" ]]; then
    R_STATUS="missing"
    V_STATUS="missing"
    [[ "$RESEARCH_DONE" == "true" ]] && R_STATUS="done"
    [[ "$REVIEW_DONE" == "true" ]] && V_STATUS="done"

    echo "BLOCKED: Bootstrap phases incomplete. Cannot write $BASE yet." >&2
    echo "  Research: $R_STATUS (use WebSearch/WebFetch in Phase 2)" >&2
    echo "  Review:   $V_STATUS (spawn sub-agent in Phase 4a)" >&2
    echo "Complete all bootstrap phases before creating project files." >&2
    exit 2
fi

exit 0
