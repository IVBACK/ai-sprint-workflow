<instructions>

# Hook & Audit Templates

CRITICAL: Only create hooks if project uses Claude Code. Run `chmod +x .claude/hooks/*.sh` after creation. Code templates below are AUTHORITATIVE — copy exactly.

---

## 1. hooks-config.sh — Centralized Configuration

`.claude/hooks-config.sh`:

```bash
# Claude Code Hooks — Feature Flags
# Toggle individual hooks on/off without touching settings.json
#
# HOW TO CHANGE A SETTING:
#   1. Edit the value in the "Defaults" table below      (applies to whole team)
#   2. Or put it in .env                                  (personal, git-ignored)
#   3. Or export as env var: export CROSS_AUDIT_TIMEOUT=120  (temporary, current shell)

# Version — tracks which WORKFLOW.md version these hooks were generated from.
HOOKS_VERSION="3.0"

WORKFLOW_MODE="standard"  # "freestyle", "lite", "standard", or "strict"

# Mode-based defaults are set automatically (see actual file for case block).
# See Docs/Workflow/WORKFLOW-MODES.md for mode details and hook counts.
# Cross-audit defaults also vary by mode (enforce-block).
# Hook flags use mode preset; individual HOOK_* overrides are below the case block.

# ── Defaults ──────────────────────────────────────────────────
# Edit the values on the RIGHT side to change defaults.
#
# ┌─────────────────────────────────────────────────────────────┐
# │  COMMONLY CHANGED — most users only need to touch these     │
# └─────────────────────────────────────────────────────────────┘
_D_CROSS_AUDIT_PROVIDER=openai                           # "openai" or "anthropic"
_D_CROSS_AUDIT_MODEL=                                    # Empty = auto-set per provider
_D_CROSS_AUDIT_LANG=en                                   # "en" or "tr"
_D_CROSS_AUDIT_ENFORCE_BLOCK="${_D_CROSS_AUDIT_ENFORCE_BLOCK:-false}"  # Exit non-zero on BLOCK (mode-aware)
#
# ┌─────────────────────────────────────────────────────────────┐
# │  POWER USER — rarely changed, safe to ignore                │
# └─────────────────────────────────────────────────────────────┘
_D_CROSS_AUDIT_API_BASE=                                 # Empty = auto-set per provider
_D_CROSS_AUDIT_TIMEOUT=60                                # API timeout (seconds)
_D_CROSS_AUDIT_MAX_DIFF=32000                            # Base diff limit — derived: wave=×1, close-gate=×1.5, entry-gate=×1
_D_AUDIT_CP1_THRESHOLD=0.20                              # CP1: metric regression (20%)
_D_AUDIT_CP2_MIN_SPRINTS=2                               # CP2: recurring failure (sprints)
_D_DASHBOARD_SEARCH_DEPTH=3                              # File search depth (dir levels)

# ── Apply defaults (env vars and local overrides take precedence) ──
# ... (all variables follow this pattern — see actual file for full list)

# Strict mode enforcement (overrides all individual flags to true)
```

## 2. settings.json — Hook Registrations

`.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/session-start.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/detect-audit-signals.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/memory-sync.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-claude.sh" }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/bootstrap-phase-gate.sh" }]
      },
      {
        "matcher": "Read|Bash",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-secrets.sh" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-tracking.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-id-uniqueness.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/cross-llm-audit.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/detect-audit-signals.sh" }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/entry-gate-session.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-close-gate.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/validate-sprint-close.sh" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/detect-test-regression.sh" },
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/memory-sync.sh" }
        ]
      },
      {
        "matcher": "Read|WebSearch|WebFetch|Agent",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/bootstrap-guard.sh" }]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/memory-sync.sh" }]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/memory-sync.sh" }]
      }
    ]
  }
}
```

## 3. protect-claude.sh — Hard Block on CLAUDE.md Write

Exit 2 aborts the Write.

```bash
#!/bin/bash
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_PROTECT_CLAUDE_MD" != "true" ]] && exit 0
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
if [[ "$TOOL" == "Write" ]] && [[ "$FILE" == *"CLAUDE.md"* ]]; then
    if [[ -f "$FILE" ]]; then
        echo "BLOCKED: Writing to CLAUDE.md is not allowed (would overwrite existing content)." >&2
        echo "Use the Edit tool to append or modify specific sections." >&2
        exit 2
    fi
fi
exit 0
```

## 4. protect-secrets.sh — Hard Block on Secret Files

Prevents AI from reading `.env`, `.key`, `.pem`, `credentials.json`. 6-layer Bash protection.

```bash
#!/bin/bash
# Hook: protect-secrets.sh
# Event: PreToolUse — Read, Bash
# Purpose: Prevent the AI from reading files that contain secrets.
#          API keys are managed by shell hooks (cross-llm-audit.sh) —
#          the AI should never see them directly.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_PROTECT_SECRETS" != "true" ]] && exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# ── Block Read tool on secret files ──
if [[ "$TOOL" == "Read" ]]; then
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    BASE=$(basename "$FILE")

    # Allow .env.example (template, no secrets)
    [[ "$BASE" == ".env.example" ]] && exit 0

    case "$BASE" in
        .env|.env.*|*.key|*.pem|*.p12)
            echo "BLOCKED: Reading $BASE is not allowed — it may contain API keys or secrets." >&2
            echo "The cross-LLM audit hook reads .env automatically. You don't need to access it." >&2
            exit 2
            ;;
        credentials.json|secrets.yaml|secrets.yml)
            echo "BLOCKED: Reading $BASE is not allowed — it may contain secrets." >&2
            exit 2
            ;;
    esac
fi

# ── Block Bash commands that would expose secrets ──
if [[ "$TOOL" == "Bash" ]]; then
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

    # Helper: does the command reference a secret file?
    _has_secret_ref() {
        local cmd="$1"
        if echo "$cmd" | grep -qE '\.env([^a-zA-Z0-9_-]|$)'; then
            if ! echo "$cmd" | grep -qE '\.env\.example'; then
                return 0
            fi
        fi
        if echo "$cmd" | grep -qE 'credentials\.json|secrets\.ya?ml'; then return 0; fi
        if echo "$cmd" | grep -qE '\.(key|pem|p12)([^a-zA-Z0-9_-]|$)'; then return 0; fi
        return 1
    }

    # Layer 1: Direct read commands
    if echo "$CMD" | grep -qE '(cat|head|tail|less|more|bat|source)\s' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents." >&2
        exit 2
    fi

    # Layer 2: Scripting languages
    if echo "$CMD" | grep -qE '(python|python3|perl|ruby|node|php)' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents via scripting." >&2
        exit 2
    fi

    # Layer 3: Encoding/dump tools
    if echo "$CMD" | grep -qE '(base64|xxd|od|hexdump|strings)\s' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents." >&2
        exit 2
    fi

    # Layer 4: Text processing tools
    if echo "$CMD" | grep -qE '(awk|sed|grep|rg|jq|yq)\s' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents." >&2
        exit 2
    fi

    # Layer 5: File redirects: < .env, $(<.env)
    if echo "$CMD" | grep -qE '<\s*\.env([^a-zA-Z0-9_-]|$)'; then
        if ! echo "$CMD" | grep -qE '\.env\.example'; then
            echo "BLOCKED: File redirect on .env detected." >&2
            exit 2
        fi
    fi

    # Layer 6: Explicit env var exposure
    if echo "$CMD" | grep -qiE '(echo|printf|printenv|env\s).*\$?\{?(CROSS_AUDIT_API_KEY|CROSS_AUDIT_.*KEY)'; then
        echo "BLOCKED: This command would expose the API key." >&2
        exit 2
    fi
fi

exit 0
```

## 5. validate-tracking.sh — Soft Warn on TRACKING.md Edit

Exit 1 on validation issues.

```bash
#!/bin/bash
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_VALIDATE_TRACKING" != "true" ]] && exit 0
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
# Match TRACKING.md and TRACKING-[name].md (team per-person files)
BASENAME=$(basename "$FILE")
[[ "$BASENAME" != TRACKING*.md ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0
ERRORS=()
LEGAL="open|in_progress|fixed|verified|deferred|blocked"
ILLEGAL=$(grep -E '^\| CORE-[0-9]+' "$FILE" | awk -F'|' '{gsub(/ /,"",$4); print NR": "$4}' | grep -Ev "^[0-9]+:($LEGAL)$")
[[ -n "$ILLEGAL" ]] && ERRORS+=("Illegal status values: $ILLEGAL")
MISSING_EV=$(grep -E '^\| CORE-[0-9]+' "$FILE" | awk -F'|' '{gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$6); if ($4=="verified" && $6=="") print $2}')
[[ -n "$MISSING_EV" ]] && ERRORS+=("'verified' items missing evidence: $MISSING_EV")
MISSING_RS=$(grep -E '^\| CORE-[0-9]+' "$FILE" | awk -F'|' '{gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$6); if ($4=="deferred" && $6=="") print $2}')
[[ -n "$MISSING_RS" ]] && ERRORS+=("'deferred' items missing reason: $MISSING_RS")
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "TRACKING.md validation warnings:" >&2
    for e in "${ERRORS[@]}"; do echo "  $e" >&2; done
    exit 1
fi
exit 0
```

## 6. validate-id-uniqueness.sh — Soft Warn on Duplicate CORE-###

```bash
#!/bin/bash
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_VALIDATE_ID_UNIQUENESS" != "true" ]] && exit 0
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
# Match TRACKING.md and TRACKING-[name].md (team per-person files)
BASENAME=$(basename "$FILE")
[[ "$BASENAME" != TRACKING*.md ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0
DUPES=$(grep -oE 'CORE-[0-9]+' "$FILE" | sort | uniq -d)
if [[ -n "$DUPES" ]]; then
    echo "TRACKING.md ID uniqueness violation — duplicate CORE-### IDs found (never reuse an ID):" >&2
    while IFS= read -r id; do
        echo "  $id appears $(grep -oE "$id" "$FILE" | wc -l) times" >&2
    done <<< "$DUPES"
    exit 1
fi
exit 0
```

## 7. session-start.sh — Session Start Protocol Injection

Handles: existing project (protocol), first-time setup (bootstrap guidance), cross-audit status, version mismatch detection.

```bash
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
    WORKFLOW_FILE=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 \( -name "WORKFLOW.md" -o -name "SPRINT_WORKFLOW.md" -o -name "BOOTSTRAP.md" -path "*/Docs/Workflow/*" \) 2>/dev/null | head -1)
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
WORKFLOW_FILE=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 \( -name "WORKFLOW.md" -o -name "SPRINT_WORKFLOW.md" -o -name "BOOTSTRAP.md" -path "*/Docs/Workflow/*" \) 2>/dev/null | head -1)
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

# Detect cross-audit status (check .env without exposing contents)
CROSS_AUDIT_STATUS="off"
ENV_FILE="${CLAUDE_PROJECT_DIR:-.}/.env"
if [[ -f "$ENV_FILE" ]] && grep -q "^CROSS_AUDIT_API_KEY=" "$ENV_FILE" 2>/dev/null; then
    CROSS_AUDIT_STATUS="on"
elif [[ -f "${CLAUDE_PROJECT_DIR:-.}/.claude/setup-audit.sh" ]]; then
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
    (if $audit == "available" then "\nCross-LLM Audit: available but not configured. To enable: user runs `bash .claude/setup-audit.sh` in their terminal.\n" else "" end) +
    "============================================"
  )
}'
```

## 8. entry-gate-session.sh — Mandatory Session Boundary

Injects session boundary after `S<N>_ENTRY_GATE.md` is written.

```bash
#!/bin/bash
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_ENTRY_GATE_SESSION" != "true" ]] && exit 0
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[[ "$TOOL" != "Write" ]] && exit 0
[[ "$FILE" != *"_ENTRY_GATE.md"* ]] && exit 0
SPRINT=$(basename "$FILE" | grep -oE 'S[0-9]+')
jq -n --arg s "$SPRINT" '{
  "additionalContext": (
    "=== MANDATORY SESSION BOUNDARY (WORKFLOW.md) ===\n" +
    "Entry Gate for \($s) written. REQUIRED: tell the user:\n" +
    "  \"Entry Gate complete. Recommend starting a new session for implementation.\"\n" +
    "Do NOT begin implementation in this session.\n" +
    "================================================="
  )
}'
```

## 9. Abbreviated Hook Templates

> Template snippets below are ABBREVIATED. They show header, config loading, and feature-gate logic only. Authoritative full scripts: `.claude/hooks/*.sh`. Do NOT copy as-is — use bootstrap-created files.

### detect-audit-signals.sh — CP1+CP2 Detector

Event: SessionStart + PostToolUse (Edit|Write on TRACKING.md). Exit 0 always. Injects additionalContext on findings.

```bash
#!/bin/bash
# Hook: detect-audit-signals.sh
# Event: SessionStart + PostToolUse (Edit|Write on TRACKING.md)
# CP1: Metric regression ≥20% between consecutive sprints (§Performance Baseline Log)
# CP2: Same failure category in 2+ sprints (§Failure History)
# Warns when structured tables are missing (AUDIT DATA GAP).
# On PostToolUse, only fires for TRACKING.md edits (other files → exit 0).
# Exit: 0 always. Injects additionalContext on findings.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_DETECT_AUDIT_SIGNALS" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# PostToolUse filter: only re-run when TRACKING.md is edited
INPUT=$(cat)
if [[ -n "$INPUT" ]]; then
  TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  if [[ -n "$TOOL" ]]; then
    case "$FILE" in *TRACKING*.md) ;; *) exit 0 ;; esac
  fi
fi

TRACKING=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 -name "TRACKING.md" 2>/dev/null | head -1)
[[ -z "$TRACKING" || ! -f "$TRACKING" ]] && exit 0

# Full script: .claude/hooks/detect-audit-signals.sh (authoritative source)
# Parses §Performance Baseline Log for ≥20% regression (CP1)
# Parses §Failure Mode History for recurring categories across sprints (CP2)
# Warns when structured tables are missing (AUDIT DATA GAP)
# Sanitizes all output. Uses jq --arg for JSON-safe injection.
# Emits additionalContext with ⚠ AUDIT SIGNAL directives.
```

### detect-test-regression.sh — CP3: Test Failure Detection

Event: PostToolUse — Bash. Exit 0 always. Injects additionalContext on findings.

```bash
#!/bin/bash
# Hook: detect-test-regression.sh
# Event: PostToolUse — Bash
# Only triggers on known test runner commands (pytest, jest, go test, cargo test, etc.)
# Scans output for failure patterns. Injects CP3 AUDIT SIGNAL.
# Exit: 0 always. Injects additionalContext on findings.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_DETECT_TEST_REGRESSION" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Full script: .claude/hooks/detect-test-regression.sh (authoritative source)
# Gate 1: Checks command against 25+ test runner patterns
# Gate 2: Scans output for framework-specific failure patterns
# Emits CP3 AUDIT SIGNAL with matched failure lines
```

### validate-close-gate.sh — CP4: Close Gate Validation

Event: PostToolUse — Write (S*_CLOSE_GATE.md). Exit 1 on issues.

```bash
#!/bin/bash
# Hook: validate-close-gate.sh
# Event: PostToolUse — Write (S*_CLOSE_GATE.md)
# Checks TRACKING.md for must items without evidence (CP4)
# Blocks if ALL items are DEFERRED (blocking guard)
# Exit: 1 (warning) on issues, 0 otherwise.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_VALIDATE_CLOSE_GATE" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Full script: .claude/hooks/validate-close-gate.sh (authoritative source)
# Scans TRACKING.md for unverified must items → CP4 AUDIT SIGNAL
# Guards against all-DEFERRED verdict (at least one item must be verified)
```

### validate-sprint-close.sh — Sprint Close Report Validation

Event: PostToolUse — Write (S*_SPRINT_CLOSE.md). Exit 1 on missing sections.

```bash
#!/bin/bash
# Hook: validate-sprint-close.sh
# Event: PostToolUse — Write (S*_SPRINT_CLOSE.md)
# Validates required sections: failure mode retrospective (Step 7),
# performance baseline (Step 5), user handoff (Step 14).
# Also checks Roadmap.md checkmarks and deferred item acknowledgment.
# Exit: 1 (warning) on missing sections, 0 otherwise.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"
[[ "$HOOK_VALIDATE_SPRINT_CLOSE" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Full script: .claude/hooks/validate-sprint-close.sh (authoritative source)
# Checks for: retrospective, baseline log, handoff summary
# Checks Roadmap.md for completed checkmarks
# Checks TRACKING.md for unacknowledged deferred items
```

### cross-llm-audit.sh — External LLM Code Review

Requires API key to activate (silently skips if no key). See [CROSS-LLM-AUDIT.md](CROSS-LLM-AUDIT.md) for setup.

Design:
- **Three audit modes:** wave-review (item completion → `git diff HEAD~1`), close-gate (holistic → `git diff main...HEAD`), entry-gate (plan review → gate file content). Other source file edits are skipped.
- **Two providers:** OpenAI-compatible (default), native Anthropic API
- **Sub-agent skip:** worktree-based sub-agents auto-detected and skipped
- **Context:** always sends full context (diff + active items + guardrails + failure modes + AC + contracts + sprint goal/progress + file content)
- **Exit 0 always.** Only BLOCK verdict can enforce blocking (via `CROSS_AUDIT_ENFORCE_BLOCK`)
- **Config:** `CROSS_AUDIT_PROVIDER`, `CROSS_AUDIT_API_KEY`, `CROSS_AUDIT_MODEL`, `CROSS_AUDIT_LANG`, `CROSS_AUDIT_TIMEOUT`, `CROSS_AUDIT_ENFORCE_BLOCK`

---

## 10. sprint-audit.sh — Generic Audit Script

Adapt to any language/framework. Replace grep patterns with project-specific equivalents.

```bash
#!/usr/bin/env bash
set -uo pipefail
# Note: -e is intentionally omitted. Individual check failures should not abort
# the entire audit. Each section handles its own errors with || true.

# sprint-audit.sh — Automated sprint close gate checks
# Adapt the patterns below to your project's language and framework.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/src"         # ← adjust to your source directory
TEST_DIR="$ROOT/tests"      # ← adjust to your test directory

total=0
errors=0
blockers=0    # Non-dismissible findings (cannot be marked as false positive)

# Verify required directories exist
for dir_var in SRC_DIR TEST_DIR; do
  dir_val="${!dir_var}"
  if [[ ! -d "$dir_val" ]]; then
    echo "ERROR  $dir_var ($dir_val) does not exist. Adjust path in script header."
    errors=$((errors + 1))
  fi
done

check() {
  local name="$1" pattern="$2" dir="${3:-$SRC_DIR}"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP  $name — directory $dir not found"
    return
  fi
  local results count
  results=$(grep -rn "$pattern" --include="*.${EXT:-*}" "$dir" 2>/dev/null || true)
  count=$(echo "$results" | grep -c . 2>/dev/null || echo 0)
  if [[ $count -gt 0 ]]; then
    echo "WARN  $name — $count finding(s):"
    echo "$results" | head -20
    total=$((total + count))
  else
    echo "PASS  $name"
  fi
}

check_blocker() {
  local name="$1" pattern="$2" dir="${3:-$SRC_DIR}"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP  $name — directory $dir not found"
    return
  fi
  local results count
  results=$(grep -rn "$pattern" --include="*.${EXT:-*}" "$dir" 2>/dev/null || true)
  count=$(echo "$results" | grep -c . 2>/dev/null || echo 0)
  if [[ $count -gt 0 ]]; then
    echo "BLOCK $name — $count finding(s) (non-dismissible):"
    echo "$results" | head -20
    total=$((total + count))
    blockers=$((blockers + count))
  else
    echo "PASS  $name"
  fi
}

# ── Adapt these checks to your project ──

# 1. Formalized debt tags (linked to tracked items)
check "TEMP_TAGS" "TEMP(CORE-\|TEMP(S"

# 1b. Naked TODO/HACK/FIXME without a tracked CORE-ID — blocks Close Gate.
# Excludes lines with formalized TEMP(CORE- or TEMP(S to avoid double-counting.
if [[ -d "$SRC_DIR" ]]; then
  _untracked=$(grep -rn "TODO\|HACK\|FIXME" --include="*.${EXT:-*}" "$SRC_DIR" 2>/dev/null \
    | grep -v "TEMP(CORE-" | grep -v "TEMP(S" || true)
  _ucount=$(echo "$_untracked" | grep -c . 2>/dev/null || echo 0)
  if [[ $_ucount -gt 0 ]]; then
    echo "BLOCK UNTRACKED_DEBT — $_ucount finding(s) (non-dismissible):"
    echo "$_untracked" | head -20
    total=$((total + _ucount))
    blockers=$((blockers + _ucount))
  else
    echo "PASS  UNTRACKED_DEBT"
  fi
fi

# 2. Hot path allocations (example: Java/C#/TypeScript)
# check "HOT_ALLOC" "new ArrayList\|new HashMap\|new List<"

# 3. Cached reference violations
# check "UNCACHED" "getElementById\|querySelector" # web
# check "UNCACHED" "GetComponent\|Camera.main"      # Unity

# 4. Framework anti-patterns
# check "ANTIPATTERN" "dangerouslySetInnerHTML"     # React
# check "ANTIPATTERN" "AppendStructuredBuffer"      # Unity compute

# 5. Resource guard
# check "RESOURCE" "new FileStream\|new SqlConnection" # check for using/dispose

# 6. Test coverage gap
echo ""
echo "TEST COVERAGE:"
missing=0
while IFS= read -r f; do
  base=$(basename "$f" ".${f##*.}")
  if ! find "$TEST_DIR" -name "${base}*test*" -o -name "${base}*spec*" \
       -o -name "test_${base}*" -o -name "*${base}Test*" 2>/dev/null | grep -q .; then
    echo "  NO TEST: $base"
    missing=$((missing + 1))
  fi
done < <(find "$SRC_DIR" -name "*.${EXT:-*}" -not -path "*/test*" 2>/dev/null)
total=$((total + missing))

# 11. Roadmap ↔ TRACKING.md sync
echo ""
echo "ROADMAP SYNC:"
# Team: pass TRACKING_FILE as env var or arg; solo: defaults to TRACKING.md
TRACKING_FILE="${TRACKING_FILE:-$ROOT/TRACKING.md}"
ROADMAP_FILE="$ROOT/Docs/Planning/Roadmap.md"  # ← adjust path
ID_PATTERN="CORE-[0-9]+"                        # ← adjust to your item ID format
sync=0

if [[ -f "$TRACKING_FILE" ]] && [[ -f "$ROADMAP_FILE" ]]; then
  declare -A tracking_status
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    if [[ -n "$item_id" ]]; then
      if echo "$line" | grep -qiw "verified"; then
        tracking_status["$item_id"]="verified"
      elif echo "$line" | grep -qiw "fixed"; then
        tracking_status["$item_id"]="fixed"
      elif echo "$line" | grep -qiw "in_progress"; then
        tracking_status["$item_id"]="in_progress"
      elif echo "$line" | grep -qiw "blocked"; then
        tracking_status["$item_id"]="blocked"
      elif echo "$line" | grep -qiw "deferred"; then
        tracking_status["$item_id"]="deferred"
      elif echo "$line" | grep -qiw "open"; then
        tracking_status["$item_id"]="open"
      fi
    fi
  done < <(grep -E "$ID_PATTERN" "$TRACKING_FILE" | grep -E "open|in_progress|fixed|verified|deferred|blocked" || true)

  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    is_checked=false
    is_skipped=false
    echo "$line" | grep -qE "^\s*-\s*\[x\]" && is_checked=true
    echo "$line" | grep -qE "^\s*-\s*\[~\]" && is_skipped=true
    t_status="${tracking_status[$item_id]:-unknown}"
    if $is_checked && [[ "$t_status" != "verified" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[x] but TRACKING=$t_status (premature tick)"
      sync=$((sync + 1))
    elif ! $is_checked && ! $is_skipped && [[ "$t_status" == "verified" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[ ] but TRACKING=verified (forgotten tick)"
      sync=$((sync + 1))
    elif $is_skipped && [[ "$t_status" != "deferred" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[~] but TRACKING=$t_status (should be deferred)"
      sync=$((sync + 1))
    elif ! $is_skipped && [[ "$t_status" == "deferred" ]]; then
      echo "  MISMATCH $item_id: Roadmap=[ ] but TRACKING=deferred (missing [~] mark)"
      sync=$((sync + 1))
    fi
  done < <(grep -E "\- \[.\].*$ID_PATTERN" "$ROADMAP_FILE" || true)
  [[ $sync -eq 0 ]] && echo "  All checkboxes consistent."

  # 11b. Orphan detection — items in one file but not the other
  echo ""
  echo "ORPHAN CHECK:"
  orphans=0

  # Items in TRACKING but not in Roadmap
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    if ! grep -q "$item_id" "$ROADMAP_FILE" 2>/dev/null; then
      echo "  ORPHAN $item_id: exists in TRACKING but not in Roadmap"
      orphans=$((orphans + 1))
    fi
  done < <(grep -E "$ID_PATTERN" "$TRACKING_FILE" 2>/dev/null | head -200 || true)

  # Items in Roadmap but not in TRACKING
  # Team: check all TRACKING-*.md files to avoid false positive orphans
  _all_tracking="$TRACKING_FILE"
  for _tf in "$ROOT"/TRACKING-*.md; do
    [[ -f "$_tf" ]] && _all_tracking="$_all_tracking $_tf"
  done
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    _found=false
    for _tf in $_all_tracking; do
      grep -q "$item_id" "$_tf" 2>/dev/null && _found=true && break
    done
    if ! $_found; then
      echo "  ORPHAN $item_id: exists in Roadmap but not in any TRACKING file"
      orphans=$((orphans + 1))
    fi
  done < <(grep -E "$ID_PATTERN" "$ROADMAP_FILE" 2>/dev/null | head -200 || true)

  [[ $orphans -eq 0 ]] && echo "  No orphan items found."
  total=$((total + orphans))

  # 11c. Checkbox format check — detect CORE-### items without checkbox
  echo ""
  echo "CHECKBOX FORMAT CHECK:"
  fmt_errors=0
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    # Skip lines that already have checkbox format
    echo "$line" | grep -qE "^\s*-\s*\[.\]" && continue
    echo "  FORMAT $item_id: missing checkbox — use '- [ ] $item_id: ...' (breaks close gate tracking)"
    fmt_errors=$((fmt_errors + 1))
  done < <(grep -E "$ID_PATTERN" "$ROADMAP_FILE" 2>/dev/null | grep -E "^\s*-\s" | head -200 || true)
  [[ $fmt_errors -eq 0 ]] && echo "  All roadmap items have checkbox format."
  total=$((total + fmt_errors))
fi
total=$((total + sync))

# 12. Metric ↔ Test Coverage
# Each roadmap metric must have a matching test in TEST_DIR.
# Handles two formats:
#   Format A: "Metric: description" or "**Metric:** description"
#   Format B: Bullet lines under "**Metric gates:**" header
echo ""
echo "METRIC COVERAGE:"
metric_gaps=0

if [[ -f "$ROADMAP_FILE" ]]; then
  metric_lines=$(awk '
    /[Mm]etric[s]?[[:space:]]*[:：]/ && !/[Mm]etric[[:space:]]+gate/ { print; next }
    /[Mm]etric[[:space:]]+gate/ { in_gate=1; next }
    in_gate && /^[[:space:]]*-[[:space:]]/ { print; next }
    in_gate && /^[[:space:]]*$/ { next }
    in_gate { in_gate=0 }
  ' "$ROADMAP_FILE" 2>/dev/null)

  if [[ -z "$metric_lines" ]]; then
    echo "  (no metric lines found in Roadmap — check format)"
  else
    while IFS= read -r mline; do
      if echo "$mline" | grep -qiE "[Mm]etric[s]?\s*[:：]"; then
        metric_desc=$(echo "$mline" | sed -E 's/.*[Mm]etric[s]?\s*[:：]\s*//' | sed 's/[*`]//g' | xargs)
      else
        metric_desc=$(echo "$mline" | sed -E 's/^\s*-\s*//' | sed 's/[*`]//g' | xargs)
      fi
      [[ -z "$metric_desc" ]] && continue
      keywords=$(echo "$metric_desc" | tr '[:upper:]' '[:lower:]' | \
        sed -E 's/[^a-z0-9 ]/ /g' | tr ' ' '\n' | \
        grep -vE '^(the|a|an|is|are|be|to|of|in|for|and|or|no|not|with|must|should|each|per|all|any|same|than|from|has|have|does|when|will|can|at|by)$' | \
        grep -E '.{3,}' | sort -u | head -8)
      found=false
      for kw in $keywords; do
        if grep -rli "$kw" "$TEST_DIR" --include="*.${EXT:-*}" 2>/dev/null | grep -q .; then
          found=true; break
        fi
      done
      if ! $found; then
        echo "  BLOCKER  NO TEST: $metric_desc"
        metric_gaps=$((metric_gaps + 1))
      fi
    done <<< "$metric_lines"
  fi
  [[ $metric_gaps -eq 0 ]] && echo "  All metrics have test coverage."
  [[ $metric_gaps -gt 0 ]] && echo "  $metric_gaps BLOCKER(s) — not false-positive-eligible. Write tests or escalate."
fi
total=$((total + metric_gaps))
blockers=$((blockers + metric_gaps))

# 13. Change Log completeness
# At least one Change Log entry should exist if sprint items are tracked.
echo ""
echo "CHANGE LOG:"
if [[ -f "$TRACKING_FILE" ]]; then
  cl_entries=$(sed -n '/^## Change Log/,/^## [^C]/p' "$TRACKING_FILE" | grep -cE '^- ' 2>/dev/null || echo 0)
  has_items=$(grep -cE "$ID_PATTERN.*(open|in_progress|fixed|verified)" "$TRACKING_FILE" 2>/dev/null || echo 0)
  if [[ $has_items -gt 0 ]] && [[ $cl_entries -eq 0 ]]; then
    echo "  WARN  Sprint Board has $has_items tracked items but Change Log is empty"
    total=$((total + 1))
  else
    echo "  PASS  Change Log has $cl_entries entries"
  fi
else
  echo "  SKIP  TRACKING.md not found"
fi

# 14. Entry Gate log presence
# If Sprint Board has items, an Entry Gate should have been run.
echo ""
echo "ENTRY GATE LOG:"
if [[ -f "$TRACKING_FILE" ]]; then
  has_items=$(grep -cE "$ID_PATTERN.*(open|in_progress|fixed|verified)" "$TRACKING_FILE" 2>/dev/null || echo 0)
  if [[ $has_items -gt 0 ]]; then
    if grep -qiE "Entry Gate" "$TRACKING_FILE" 2>/dev/null; then
      echo "  PASS  Entry Gate execution logged in TRACKING.md"
    else
      echo "  WARN  Sprint has $has_items items but no Entry Gate log found in TRACKING.md"
      total=$((total + 1))
    fi
  else
    echo "  SKIP  No tracked items — Entry Gate check not applicable"
  fi
else
  echo "  SKIP  TRACKING.md not found"
fi

# 15. Failure transfer check
# If Failure Encounters has entries, they should be transferred to Failure Mode History
# at Sprint Close step 7. Untransferred entries suggest Sprint Close was incomplete.
echo ""
echo "FAILURE TRANSFER:"
if [[ -f "$TRACKING_FILE" ]]; then
  encounters=$(sed -n '/^## Failure Encounters/,/^## [^F]/p' "$TRACKING_FILE" | grep -cE '^\|[^-]' 2>/dev/null || echo 0)
  encounters=$((encounters > 1 ? encounters - 1 : 0))  # subtract header row
  history=$(sed -n '/^## Failure Mode History/,/^## [^F]/p' "$TRACKING_FILE" | grep -cE '^\|[^-]' 2>/dev/null || echo 0)
  history=$((history > 1 ? history - 1 : 0))  # subtract header row
  if [[ $encounters -gt 0 ]] && [[ $history -eq 0 ]]; then
    echo "  WARN  Failure Encounters has $encounters entries but Failure Mode History is empty"
    echo "        Transfer at Sprint Close step 7 (retrospective comparison)"
    total=$((total + 1))
  else
    echo "  PASS  Failure transfer consistent (encounters=$encounters, history=$history)"
  fi
else
  echo "  SKIP  TRACKING.md not found"
fi

# 16. CLAUDE.md Last Checkpoint staleness
# Last Checkpoint should exist and not be empty template values.
echo ""
echo "LAST CHECKPOINT:"
CLAUDE_FILE="$ROOT/CLAUDE.md"
if [[ -f "$CLAUDE_FILE" ]]; then
  if grep -qE '## Last Checkpoint' "$CLAUDE_FILE" 2>/dev/null; then
    cp_content=$(sed -n '/^## Last Checkpoint/,/^## /p' "$CLAUDE_FILE" | grep -E '^- ' 2>/dev/null || true)
    if [[ -z "$cp_content" ]]; then
      echo "  WARN  §Last Checkpoint section exists but has no entries"
      total=$((total + 1))
    elif echo "$cp_content" | grep -qE '\[YYYY-MM-DD\]|\[Sprint N'; then
      echo "  WARN  §Last Checkpoint still contains template placeholders — update at gate boundaries"
      total=$((total + 1))
    else
      echo "  PASS  §Last Checkpoint populated"
    fi
  else
    echo "  WARN  No §Last Checkpoint section found in CLAUDE.md"
    total=$((total + 1))
  fi
else
  echo "  SKIP  CLAUDE.md not found"
fi

# ── Summary ──
echo ""
if [[ $errors -gt 0 ]]; then
  echo "Sprint audit: $errors setup error(s) — fix script configuration before audit."
  exit 2
elif [[ $total -eq 0 ]]; then
  echo "Sprint audit CLEAN — 0 findings."
  exit 0
elif [[ $blockers -gt 0 ]]; then
  echo "Sprint audit: $total finding(s), $blockers BLOCKER(s) — gate cannot close."
  echo "BLOCKER findings require action (write test or escalate). Cannot be dismissed."
  exit 1
else
  echo "Sprint audit: $total finding(s) — review needed."
  exit 1
fi
```

## Language-Specific Pattern Examples

| Language | Hot Path Alloc | Cached Ref | Anti-Pattern |
|----------|---------------|-----------|-------------|
| **C#/Unity** | `new List<`, `new Dictionary<` | `Camera.main`, `GetComponent` | `AppendStructuredBuffer`, `SetFloats` |
| **TypeScript/React** | `new Array(`, `[...spread]` in render | `document.querySelector` in loop | `dangerouslySetInnerHTML`, `any` type |
| **Python** | list comprehension in hot loop | repeated `os.path.exists` | `eval()`, `exec()`, bare `except:` |
| **Java** | `new ArrayList<>` in loop | repeated `getBean()` | `e.printStackTrace()`, raw types |
| **Go** | `append` in tight loop (pre-alloc) | repeated `os.Getenv` | `panic()` in library code, `interface{}` |
| **Rust** | `.clone()` in hot path | repeated `.unwrap()` | `unsafe` without comment, `.expect("")` |
| **C++** | `new`/`malloc` in loop | repeated `dynamic_cast` | raw `new` without smart pointer |

CRITICAL: Only create hooks if project uses Claude Code. Run `chmod +x .claude/hooks/*.sh` after creation. Code templates are AUTHORITATIVE — copy exactly.

</instructions>
