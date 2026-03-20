#!/usr/bin/env bash
# Hook: bootstrap-guard.sh
# Event: PostToolUse — Read|WebSearch|WebFetch|Agent
# Purpose: Two jobs during bootstrap:
#   (A) Inject phase-specific context after bootstrap phase file reads
#   (B) Create marker files when research/review tools are actually used
#
# Markers are written by THIS HOOK (code), not by the agent (prompt).
# Note: Bash can still create markers — hooks enforce intent, not adversarial resistance.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_BOOTSTRAP_GUARD" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
BOOTSTRAP_DIR="$PROJECT_DIR/.bootstrap"

# Detect bootstrap state: CLAUDE.md doesn't exist or still has [REQUIRED] placeholders
_is_bootstrap() {
    local claude_md="$PROJECT_DIR/CLAUDE.md"
    [[ ! -f "$claude_md" ]] && return 0
    grep -q '\[REQUIRED' "$claude_md" 2>/dev/null && return 0
    return 1
}

_is_bootstrap || exit 0

# ── (B) Marker creation on actual tool usage ──
# Only create markers if .bootstrap/ dir already exists (Phase 1 creates it).
# This prevents false markers from unrelated WebSearch/Agent usage before bootstrap starts.
if [[ -d "$BOOTSTRAP_DIR" ]]; then
    case "$TOOL" in
        WebSearch|WebFetch)
            touch "$BOOTSTRAP_DIR/research-done"
            ;;
        Agent)
            # Only set review-done if plan-draft.md exists (proves this is a Phase 4 review,
            # not an unrelated Agent call from Phase 1/2)
            [[ -f "$BOOTSTRAP_DIR/plan-draft.md" ]] && touch "$BOOTSTRAP_DIR/review-done"
            ;;
    esac
fi

# ── (A) Context injection after phase file reads ──
if [[ "$TOOL" == "Read" ]] && [[ "$FILE" == *"BOOTSTRAP-PHASE"*".md"* ]]; then
    PHASE_ID=$(echo "$FILE" | grep -oE 'PHASE[0-9]+[A-Z]?' | sed 's/PHASE//')

    # Phase 1 read: clean stale markers from previous interrupted bootstrap
    if [[ "$PHASE_ID" == "1" ]]; then
        if [[ -f "$BOOTSTRAP_DIR/plan-draft.md" ]]; then
            RECOVERY_MSG="WARNING: Previous bootstrap was interrupted — .bootstrap/plan-draft.md exists from a prior session. Starting fresh (old plan will be deleted). If you want to resume instead, tell the user."
        fi
        rm -rf "$BOOTSTRAP_DIR" 2>/dev/null
        mkdir -p "$BOOTSTRAP_DIR"
    fi

    # Phase 4: verify plan-draft.md exists before blind review
    PLAN_STATUS=""
    if [[ "$PHASE_ID" == "4" || "$PHASE_ID" == "4B" ]]; then
        if [[ ! -f "$BOOTSTRAP_DIR/plan-draft.md" ]]; then
            PLAN_STATUS=" PLAN-DRAFT MISSING — go back to Phase 3 and write the plan to .bootstrap/plan-draft.md before proceeding."
        fi
    fi

    R_STATUS="missing"
    V_STATUS="missing"
    [[ -f "$BOOTSTRAP_DIR/research-done" ]] && R_STATUS="done"
    [[ -f "$BOOTSTRAP_DIR/review-done" ]] && V_STATUS="done"

    case "$PHASE_ID" in
        1)
            MSG="BOOTSTRAP PHASE 1 ACTIVE — Ask ONE question at a time. Do NOT present a plan yet. Exit gate: summarize understanding, ask 'did I miss anything?', WAIT for user confirmation."
            [[ -n "${RECOVERY_MSG:-}" ]] && MSG="$RECOVERY_MSG $MSG"
            ;;
        2)
            MSG="BOOTSTRAP PHASE 2 ACTIVE — Research is MANDATORY. Use WebSearch/WebFetch NOW. Do NOT draft a plan until research is complete. Research marker: ${R_STATUS}."
            ;;
        3)
            MSG="BOOTSTRAP PHASE 3 ACTIVE — Draft plan internally using research findings. Write plan to .bootstrap/plan-draft.md (Phase 4 reads from this file). User does NOT see this. Research marker: ${R_STATUS}."
            ;;
        4)
            MSG="BOOTSTRAP PHASE 4a ACTIVE — Spawn a sub-agent for blind review (do NOT background). After review completes, read BOOTSTRAP-PHASE4B.md next. Review marker: ${V_STATUS}.${PLAN_STATUS}"
            ;;
        4B)
            MSG="BOOTSTRAP PHASE 4b ACTIVE — Offer cross-audit (different AI, not a repeat of blind review). WAIT for user response BEFORE proceeding to Phase 5. Do NOT combine this with the plan presentation. Review marker: ${V_STATUS}.${PLAN_STATUS}"
            ;;
        5)
            MSG="BOOTSTRAP PHASE 5 ACTIVE — Read .bootstrap/plan-draft.md and present to user. Research: ${R_STATUS}. Review: ${V_STATUS}. If either is 'missing', go back and complete it BEFORE presenting."
            ;;
        *)
            exit 0
            ;;
    esac

    jq -n --arg msg "$MSG" '{"additionalContext": $msg}'
    exit 0
fi

exit 0
