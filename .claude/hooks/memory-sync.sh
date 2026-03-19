#!/usr/bin/env bash
# Hook: memory-sync.sh
# Simple memory sync: remind AI to read/update TRACKING.md at key moments.
#
# Events:
#   SessionStart      → "Read TRACKING.md"
#   PreCompact        → "Compaction happening. Read TRACKING.md after."
#   PostToolUse(Bash) → After git commit: "Update TRACKING.md"
#   Stop              → Block if TRACKING not updated
#
# Works for both:
#   - User projects (TRACKING.md at project root)
#   - Dev/dogfooding (.dev/TRACKING.md)

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# ── Toggle check ──
source "$HOOKS_DIR/../hooks-config.sh" 2>/dev/null || true
[[ "$HOOK_MEMORY_SYNC" != "true" ]] && exit 0

if ! command -v jq >/dev/null 2>&1; then
    echo "WARNING: jq not found — memory-sync hook disabled" >&2
    exit 0
fi

# ── Detect tracking file location ──
TRACKING=""
DEV_MODE=false
if [[ -f "$PROJECT_DIR/.dev/TRACKING.md" ]]; then
    TRACKING="$PROJECT_DIR/.dev/TRACKING.md"
    DEV_MODE=true
elif [[ -f "$PROJECT_DIR/TRACKING.md" ]]; then
    TRACKING="$PROJECT_DIR/TRACKING.md"
fi

[[ -z "$TRACKING" ]] && exit 0

TRACKING_REL="${TRACKING#$PROJECT_DIR/}"

# ── Read input from stdin ──
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // .event // empty')

# ── Helper: check if work was done but TRACKING not updated ──
# Checks both uncommitted changes AND today's commits.
tracking_needs_update() {
    local today
    today=$(date +%Y-%m-%d)

    # If TRACKING has today's date in changelog, assume it was updated
    if grep -q "$today" "$TRACKING" 2>/dev/null; then
        return 1
    fi

    # Check 1: uncommitted changes to non-TRACKING files
    if git -C "$PROJECT_DIR" diff --name-only 2>/dev/null | grep -qv "TRACKING.md"; then
        return 0
    fi

    # Check 2: commits today but no TRACKING update (catches post-commit case)
    if git -C "$PROJECT_DIR" log --since="$today" --oneline 2>/dev/null | grep -q .; then
        return 0
    fi

    return 1
}


# ══════════════════════════════════════════════════════════════
# SessionStart — read TRACKING
# ══════════════════════════════════════════════════════════════
if [[ "$EVENT" == "SessionStart" ]]; then
    # Detect available sprint-tools
    TOOLS_LINE=""
    TOOLS_BIN="$PROJECT_DIR/Tools/sprint-tools"
    if [[ -x "$TOOLS_BIN" ]]; then
        TOOLS_LINE="\nTools (anytime): sprint-tools state (sprint digest), note (session journal), learn (classify finding), review (blind external LLM review of any file/diff)"
        TOOLS_LINE="$TOOLS_LINE\nTools (workflow step): item, checkpoint, baseline, metrics, close, index, git — see workflow docs for usage"
    fi

    jq -n --arg tracking "$TRACKING_REL" --arg tools "$TOOLS_LINE" '{
      "additionalContext": (
        "Read " + $tracking + " for sprint state, Working Context, and risks." +
        $tools
      )
    }'
    exit 0
fi


# ══════════════════════════════════════════════════════════════
# PreCompact — remind to re-read TRACKING after compaction
# ══════════════════════════════════════════════════════════════
if [[ "$EVENT" == "PreCompact" ]]; then
    TOOLS_LINE=""
    TOOLS_BIN="$PROJECT_DIR/Tools/sprint-tools"
    if [[ -x "$TOOLS_BIN" ]]; then
        TOOLS_LINE="\nTools (anytime): sprint-tools state (sprint digest), note (session journal), learn (classify finding), review (blind external LLM review of any file/diff)"
        TOOLS_LINE="$TOOLS_LINE\nTools (workflow step): item, checkpoint, baseline, metrics, close, index, git — see workflow docs for usage"
    fi

    # Inject last 5 session notes to survive compaction
    SESSION_NOTES=""
    if [[ -f "$TRACKING" ]]; then
        # Extract last 5 data rows from §Session Notes table
        NOTES_RAW=$(sed -n '/^## Session Notes/,/^## /{/^|[^-]/p}' "$TRACKING" 2>/dev/null \
            | grep -v '^| #' | tail -5)
        if [[ -n "$NOTES_RAW" ]]; then
            SESSION_NOTES="\n\nSession notes (last 5, pre-compaction):\n$NOTES_RAW"
        fi
    fi

    jq -n --arg tracking "$TRACKING_REL" --arg tools "$TOOLS_LINE" --arg notes "$SESSION_NOTES" '{
      "additionalContext": (
        "Context is being compacted. After compaction, read " + $tracking + " to restore sprint state and Working Context." +
        $tools + $notes
      )
    }'
    exit 0
fi


# ══════════════════════════════════════════════════════════════
# PostToolUse/Bash — git commit detected → remind to update
# ══════════════════════════════════════════════════════════════
if [[ "$TOOL" == "Bash" ]]; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.output // empty')

    if echo "$COMMAND" | grep -qE "git commit" 2>/dev/null; then
        if echo "$OUTPUT" | grep -qE "^\[.+ [a-f0-9]+\]" 2>/dev/null; then
            COMMIT_HASH=$(echo "$OUTPUT" | grep -oE '[a-f0-9]{7,}' | head -1)

            TOOL_HINT=""
            if [[ -x "$PROJECT_DIR/Tools/sprint-tools" ]]; then
                TOOL_HINT=" Use: sprint-tools item CORE-NNN status \"evidence\" (NOT manual edit)."
            fi

            jq -n --arg hash "$COMMIT_HASH" --arg tracking "$TRACKING_REL" --arg hint "$TOOL_HINT" '{
              "additionalContext": (
                "Commit " + $hash + " done. Update " + $tracking + ": board status+evidence, changelog entry, resolved risks, Working Context." + $hint
              )
            }'
        fi
    fi
    exit 0
fi


# ══════════════════════════════════════════════════════════════
# Stop — Block if TRACKING needs update
# ══════════════════════════════════════════════════════════════
if [[ "$EVENT" == "Stop" ]]; then
    STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
    if [[ "$STOP_ACTIVE" == "true" ]]; then
        exit 0
    fi

    if tracking_needs_update; then
        jq -n --arg tracking "$TRACKING_REL" '{
          "decision": "block",
          "reason": (
            $tracking + " has not been updated with this session'\''s work.\n" +
            "Before ending, update:\n" +
            "- Sprint Board: status + evidence for completed items\n" +
            "- Change Log: dated entry summarizing what was done\n" +
            "- Open Risks: add new or remove resolved\n" +
            "Then you may stop."
          )
        }'
    fi

    exit 0
fi


exit 0
