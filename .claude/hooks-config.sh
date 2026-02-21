# Claude Code Hooks — Feature Flags
# Toggle individual hooks on/off without touching settings.json
# All hooks read this file first. Set to "false" to disable.
#
# These hooks enforce WORKFLOW.md rules for Claude Code users only.
# Other AI agents (GPT, Gemini, etc.) do not read this directory.
#
# ── Workflow Mode Presets ──
# Set WORKFLOW_MODE to auto-configure hooks for your project's needs.
# Individual overrides below still take precedence over the mode preset.
#
#   lite     — Solo dev, fast iteration. Core safety only.
#              Enables: protect-claude, validate-tracking, session-start
#              Disables: entry-gate-session, close-gate, sprint-close, audit-signals, test-regression
#
#   standard — Default. Full workflow with all hooks.
#              Enables: all hooks
#
#   strict   — Team + critical systems. All hooks mandatory, no individual overrides.
#              Enables: all hooks (overrides ignored — see note below)
#
# Usage: set WORKFLOW_MODE and leave individual flags commented out to use the preset.
#        Or set WORKFLOW_MODE and override specific flags below.
#        strict mode ignores individual overrides — all hooks are forced on.

WORKFLOW_MODE="standard"  # ← "lite", "standard", or "strict"

# ── Mode-based defaults ──
case "${WORKFLOW_MODE}" in
  lite)
    _PROTECT_CLAUDE_MD=true
    _VALIDATE_TRACKING=true
    _SESSION_START_PROTOCOL=true
    _VALIDATE_ID_UNIQUENESS=true
    _ENTRY_GATE_SESSION=false
    _DETECT_TEST_REGRESSION=false
    _VALIDATE_CLOSE_GATE=false
    _VALIDATE_SPRINT_CLOSE=false
    _DETECT_AUDIT_SIGNALS=false
    ;;
  strict)
    _PROTECT_CLAUDE_MD=true
    _VALIDATE_TRACKING=true
    _SESSION_START_PROTOCOL=true
    _VALIDATE_ID_UNIQUENESS=true
    _ENTRY_GATE_SESSION=true
    _DETECT_TEST_REGRESSION=true
    _VALIDATE_CLOSE_GATE=true
    _VALIDATE_SPRINT_CLOSE=true
    _DETECT_AUDIT_SIGNALS=true
    ;;
  *)  # standard (default)
    _PROTECT_CLAUDE_MD=true
    _VALIDATE_TRACKING=true
    _SESSION_START_PROTOCOL=true
    _VALIDATE_ID_UNIQUENESS=true
    _ENTRY_GATE_SESSION=true
    _DETECT_TEST_REGRESSION=true
    _VALIDATE_CLOSE_GATE=true
    _VALIDATE_SPRINT_CLOSE=true
    _DETECT_AUDIT_SIGNALS=true
    ;;
esac

# ── Individual overrides ──
# Uncomment and set to override the mode preset.
# In strict mode, individual overrides are ignored (all hooks forced on).

# Prevent CLAUDE.md from being overwritten (highest priority rule)
HOOK_PROTECT_CLAUDE_MD="${HOOK_PROTECT_CLAUDE_MD:-$_PROTECT_CLAUDE_MD}"

# Validate TRACKING.md status values are legal after every edit
HOOK_VALIDATE_TRACKING="${HOOK_VALIDATE_TRACKING:-$_VALIDATE_TRACKING}"

# Remind agent to read TRACKING.md at session start
HOOK_SESSION_START_PROTOCOL="${HOOK_SESSION_START_PROTOCOL:-$_SESSION_START_PROTOCOL}"

# Detect duplicate CORE-### IDs in TRACKING.md after every edit
HOOK_VALIDATE_ID_UNIQUENESS="${HOOK_VALIDATE_ID_UNIQUENESS:-$_VALIDATE_ID_UNIQUENESS}"

# Inject mandatory session boundary recommendation after Entry Gate report is written
# Also validates Entry Gate content: failure modes, verification plans, metrics
HOOK_ENTRY_GATE_SESSION="${HOOK_ENTRY_GATE_SESSION:-$_ENTRY_GATE_SESSION}"

# CP3: Detect test failures in Bash output and surface AUDIT SIGNAL
HOOK_DETECT_TEST_REGRESSION="${HOOK_DETECT_TEST_REGRESSION:-$_DETECT_TEST_REGRESSION}"

# CP4: Validate Close Gate report completeness and check for unverified must items
HOOK_VALIDATE_CLOSE_GATE="${HOOK_VALIDATE_CLOSE_GATE:-$_VALIDATE_CLOSE_GATE}"

# Validate Sprint Close report: retrospective, baseline, handoff sections
HOOK_VALIDATE_SPRINT_CLOSE="${HOOK_VALIDATE_SPRINT_CLOSE:-$_VALIDATE_SPRINT_CLOSE}"

# CP1+CP2: Self-activating metric regression and failure pattern detector (SessionStart)
# Requires structured §Performance Baseline Log and §Failure History tables in TRACKING.md
# Silent if sections missing or data insufficient — zero false positives without structured data
HOOK_DETECT_AUDIT_SIGNALS="${HOOK_DETECT_AUDIT_SIGNALS:-$_DETECT_AUDIT_SIGNALS}"

# ── Strict mode enforcement ──
if [[ "${WORKFLOW_MODE}" == "strict" ]]; then
  HOOK_PROTECT_CLAUDE_MD=true
  HOOK_VALIDATE_TRACKING=true
  HOOK_SESSION_START_PROTOCOL=true
  HOOK_VALIDATE_ID_UNIQUENESS=true
  HOOK_ENTRY_GATE_SESSION=true
  HOOK_DETECT_TEST_REGRESSION=true
  HOOK_VALIDATE_CLOSE_GATE=true
  HOOK_VALIDATE_SPRINT_CLOSE=true
  HOOK_DETECT_AUDIT_SIGNALS=true
fi
