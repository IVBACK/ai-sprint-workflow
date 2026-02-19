#!/bin/bash
# Hook: session-start.sh
# Event: SessionStart
# Purpose: Inject session start protocol context so the agent reads
#          TRACKING.md and CLAUDE.md before doing anything else.
#          WORKFLOW.md rule: "AI Agent Operational Rules — Session Start Protocol"

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_SESSION_START_PROTOCOL" != "true" ]] && exit 0

# Detect if TRACKING.md exists in working directory
TRACKING=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 -name "TRACKING.md" 2>/dev/null | head -1)
CLAUDE_MD=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 1 -name "CLAUDE.md" 2>/dev/null | head -1)

if [[ -z "$TRACKING" && -z "$CLAUDE_MD" ]]; then
    # No workflow files found — project may not be set up yet, skip
    exit 0
fi

# Output additional context for the agent via JSON
jq -n \
  --arg tracking "$TRACKING" \
  --arg claude_md "$CLAUDE_MD" \
'{
  "additionalContext": (
    "=== SESSION START PROTOCOL (WORKFLOW.md) ===\n" +
    "Before doing anything else:\n" +
    (if $claude_md != "" then "1. Read CLAUDE.md (\($claude_md)) — operational rules and last checkpoint.\n" else "" end) +
    (if $tracking != "" then "2. Read TRACKING.md (\($tracking)) — current sprint status, open items, blockers.\n" else "" end) +
    "3. State current sprint and last known status before proceeding.\n" +
    "Do NOT start implementation before completing this protocol.\n" +
    "============================================"
  )
}'
