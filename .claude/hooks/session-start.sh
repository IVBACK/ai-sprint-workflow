#!/usr/bin/env bash
# Hook: session-start.sh
# Event: SessionStart
# Purpose: Inject session start protocol context so the agent reads
#          TRACKING.md and CLAUDE.md before doing anything else.
#          WORKFLOW.md rule: "AI Agent Operational Rules — Session Start Protocol"

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_SESSION_START_PROTOCOL" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || { echo "jq not found, skipping. Install: apt/brew/pacman/choco install jq" >&2; exit 0; }

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
        VERSION_WARNING="WORKFLOW VERSION MISMATCH: WORKFLOW.md is v${WF_VERSION} but hooks are v${HK_VERSION}. Read Docs/Workflow/ADAPTATION.md §Changelog and §Upgrade, then run the upgrade procedure to update hooks."
    elif [[ -n "$WF_VERSION" && -z "$HK_VERSION" ]]; then
        VERSION_WARNING="WORKFLOW VERSION MISMATCH: WORKFLOW.md is v${WF_VERSION} but hooks have no version (pre-version system). Read Docs/Workflow/ADAPTATION.md §Changelog and §Upgrade, then run the upgrade procedure (treat current as v1.0)."
    fi
fi

# Detect cross-audit status — activates when API key is present
CROSS_AUDIT_STATUS="no-key"
ENV_FILE="${CLAUDE_PROJECT_DIR:-.}/.env"
if [[ -f "$ENV_FILE" ]] && grep -q "^CROSS_AUDIT_API_KEY=" "$ENV_FILE" 2>/dev/null; then
    CROSS_AUDIT_STATUS="on"
fi

# Warn about removed ENABLE_CROSS_AUDIT variable
if [[ -f "$ENV_FILE" ]] && grep -q "^ENABLE_CROSS_AUDIT=" "$ENV_FILE" 2>/dev/null; then
    DEPRECATED_WARN="ENABLE_CROSS_AUDIT is no longer used. Cross-audit activates when API key is present. To disable: remove CROSS_AUDIT_API_KEY from .env. You can safely delete the ENABLE_CROSS_AUDIT line."
fi

# ── Available Tools section check ──
TOOLS_MISSING=""
if [[ -n "$CLAUDE_MD" ]] && [[ -f "$CLAUDE_MD" ]]; then
    if ! grep -q '## Available Tools' "$CLAUDE_MD" 2>/dev/null; then
        TOOLS_MISSING="CLAUDE.md is missing §Available Tools section. Without it, sprint-tools commands are invisible. Append the section from Docs/Workflow/TEMPLATES.md §Available Tools to CLAUDE.md now — do NOT overwrite existing content."
    fi
fi

# ── Sprint digest injection ──
SPRINT_TOOLS="${CLAUDE_PROJECT_DIR:-.}/Tools/sprint-tools"
DIGEST=""
if [[ -x "$SPRINT_TOOLS" ]] && [[ -n "$TRACKING" ]]; then
    PROJECT_ROOT=$(dirname "$TRACKING")
    DIGEST=$(bash "$SPRINT_TOOLS" state "$PROJECT_ROOT" 2>/dev/null) || DIGEST=""
fi

# Output additional context for the agent via JSON
if [[ -n "$DIGEST" ]]; then
    # Sprint-tools available: inject digest directly (saves LLM file-reading tokens)
    jq -n \
      --arg digest "$DIGEST" \
      --arg audit "$CROSS_AUDIT_STATUS" \
      --arg version_warn "$VERSION_WARNING" \
      --arg deprecated "${DEPRECATED_WARN:-}" \
      --arg tools_missing "${TOOLS_MISSING:-}" \
    '{
      "additionalContext": (
        "=== SPRINT STATUS (auto-generated) ===\n" +
        (if $version_warn != "" then "⚠ " + $version_warn + "\n\n" else "" end) +
        (if $deprecated != "" then "⚠ " + $deprecated + "\n\n" else "" end) +
        (if $tools_missing != "" then "⚠ " + $tools_missing + "\n\n" else "" end) +
        $digest + "\n\n" +
        "Read CLAUDE.md for operational rules if needed.\n" +
        (if $audit == "on" then "Cross-LLM Audit: ACTIVE.\n" else "" end) +
        "========================================="
      )
    }'
else
    # Fallback: no sprint-tools available — instruct agent to read files manually
    jq -n \
      --arg tracking "$TRACKING" \
      --arg claude_md "$CLAUDE_MD" \
      --arg audit "$CROSS_AUDIT_STATUS" \
      --arg version_warn "$VERSION_WARNING" \
      --arg deprecated "${DEPRECATED_WARN:-}" \
      --arg tools_missing "${TOOLS_MISSING:-}" \
    '{
      "additionalContext": (
        "=== SESSION START PROTOCOL (WORKFLOW.md) ===\n" +
        (if $version_warn != "" then "⚠ " + $version_warn + "\n\n" else "" end) +
        (if $deprecated != "" then "⚠ " + $deprecated + "\n\n" else "" end) +
        (if $tools_missing != "" then "⚠ " + $tools_missing + "\n\n" else "" end) +
        "Before doing anything else:\n" +
        (if $claude_md != "" then "1. Read CLAUDE.md (\($claude_md)) — operational rules and last checkpoint.\n" else "" end) +
        (if $tracking != "" then "2. Read TRACKING.md (\($tracking)) — current sprint status, open items, blockers.\n" else "" end) +
        "3. State current sprint and last known status before proceeding.\n" +
        "Do NOT start implementation before completing this protocol.\n" +
        (if $audit == "on" then "\nCross-LLM Audit: ACTIVE. External code reviews will appear inline after code changes.\nDo NOT attempt to read .env — the audit hook manages it automatically.\n" else "" end) +
        (if $audit == "no-key" then "\nCross-LLM Audit: no API key configured. To activate: user runs `bash .claude/setup-audit.sh` in their terminal.\n" else "" end) +
        "============================================"
      )
    }'
fi
