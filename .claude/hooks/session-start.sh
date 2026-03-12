#!/bin/bash
# Hook: session-start.sh
# Event: SessionStart
# Purpose: Inject session start protocol context so the agent reads
#          TRACKING.md and CLAUDE.md before doing anything else.
#          WORKFLOW.md rule: "AI Agent Operational Rules — Session Start Protocol"

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_SESSION_START_PROTOCOL" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || { echo "WARNING: jq not found — session-start hook disabled. Install jq to enable workflow enforcement." >&2; exit 0; }

# Detect if TRACKING.md exists in working directory
TRACKING=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 -name "TRACKING.md" 2>/dev/null | head -1)
CLAUDE_MD=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 1 -name "CLAUDE.md" 2>/dev/null | head -1)

if [[ -z "$TRACKING" && -z "$CLAUDE_MD" ]]; then
    # No workflow files found — guide user through first-time setup
    WORKFLOW_FILE=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 \( -name "WORKFLOW.md" -o -name "SPRINT_WORKFLOW.md" \) 2>/dev/null | head -1)
    if [[ -n "$WORKFLOW_FILE" ]]; then
        # WORKFLOW.md exists but project not bootstrapped yet
        jq -n --arg wf "$WORKFLOW_FILE" '{
          "additionalContext": (
            "=== FIRST-TIME SETUP DETECTED ===\n" +
            "WORKFLOW.md found but project is not bootstrapped yet.\n" +
            "No CLAUDE.md or TRACKING.md exists.\n\n" +
            "Guide the user:\n" +
            "  → \"Read \($wf) and bootstrap this project.\"\n" +
            "  → Or ask: \"Shall I bootstrap the sprint workflow for this project?\"\n\n" +
            "Do NOT start any implementation before bootstrap is complete.\n" +
            "================================="
          )
        }'
    fi
    # No WORKFLOW.md either — not a sprint workflow project, skip silently
    exit 0
fi

# ── Version mismatch detection ──
VERSION_WARNING=""
WORKFLOW_FILE=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 \( -name "WORKFLOW.md" -o -name "SPRINT_WORKFLOW.md" \) 2>/dev/null | head -1)
if [[ -n "$WORKFLOW_FILE" ]]; then
    # Extract workflow-version from WORKFLOW.md (<!-- workflow-version: X.Y -->)
    WF_VERSION=$(head -5 "$WORKFLOW_FILE" | sed -n 's/.*workflow-version: *\([0-9.]*\).*/\1/p')
    # HOOKS_VERSION is already sourced from hooks-config.sh
    HK_VERSION="${HOOKS_VERSION:-}"

    if [[ -n "$WF_VERSION" && -n "$HK_VERSION" && "$WF_VERSION" != "$HK_VERSION" ]]; then
        VERSION_WARNING="WORKFLOW VERSION MISMATCH: WORKFLOW.md is v${WF_VERSION} but hooks are v${HK_VERSION}. Read §Changelog and §Upgrade in WORKFLOW.md, then run the upgrade procedure to update hooks."
    elif [[ -n "$WF_VERSION" && -z "$HK_VERSION" ]]; then
        VERSION_WARNING="WORKFLOW VERSION MISMATCH: WORKFLOW.md is v${WF_VERSION} but hooks have no version (pre-version system). Read §Changelog and §Upgrade in WORKFLOW.md, then run the upgrade procedure (treat current as v1.0)."
    fi
fi

# Detect cross-audit status
# Enabled by default in hooks-config.sh — actual activation requires API key in .env
CROSS_AUDIT_STATUS="no-key"
ENV_FILE="${CLAUDE_PROJECT_DIR:-.}/.env"
if [[ -f "$ENV_FILE" ]] && grep -q "^CROSS_AUDIT_API_KEY=" "$ENV_FILE" 2>/dev/null; then
    # Has API key — check if explicitly disabled
    if [[ "${ENABLE_CROSS_AUDIT:-true}" == "true" ]]; then
        CROSS_AUDIT_STATUS="on"
    else
        CROSS_AUDIT_STATUS="disabled"
    fi
elif [[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/setup-audit.sh" ]]; then
    # Setup script exists but no API key yet
    CROSS_AUDIT_STATUS="no-key"
fi

# Output additional context for the agent via JSON
jq -n \
  --arg tracking "$TRACKING" \
  --arg claude_md "$CLAUDE_MD" \
  --arg audit "$CROSS_AUDIT_STATUS" \
  --arg version_warn "$VERSION_WARNING" \
'{
  "additionalContext": (
    "=== SESSION START PROTOCOL (WORKFLOW.md) ===\n" +
    (if $version_warn != "" then "⚠ " + $version_warn + "\n\n" else "" end) +
    "Before doing anything else:\n" +
    (if $claude_md != "" then "1. Read CLAUDE.md (\($claude_md)) — operational rules and last checkpoint.\n" else "" end) +
    (if $tracking != "" then "2. Read TRACKING.md (\($tracking)) — current sprint status, open items, blockers.\n" else "" end) +
    "3. State current sprint and last known status before proceeding.\n" +
    "Do NOT start implementation before completing this protocol.\n" +
    (if $audit == "on" then "\nCross-LLM Audit: ENABLED. External code reviews will appear inline after code changes.\nDo NOT attempt to read .env — the audit hook manages it automatically.\n" else "" end) +
    (if $audit == "disabled" then "\nCross-LLM Audit: explicitly DISABLED. To re-enable: remove ENABLE_CROSS_AUDIT=false from .env.\n" else "" end) +
    (if $audit == "no-key" then "\nCross-LLM Audit: enabled but no API key configured. To activate: user runs `bash .claude/setup-audit.sh` in their terminal.\n" else "" end) +
    "============================================"
  )
}'
