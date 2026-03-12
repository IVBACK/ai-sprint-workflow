# Claude Code Hooks — Feature Flags
# Toggle individual hooks on/off without touching settings.json
# All hooks read this file first. Set to "false" to disable.
#
# These hooks enforce WORKFLOW.md rules for Claude Code users only.
# Other AI agents (GPT, Gemini, etc.) do not read this directory.
#
# ── Version ──
# Tracks which WORKFLOW.md version these hooks were generated from.
# session-start.sh compares this against WORKFLOW.md's workflow-version.
# Updated automatically during bootstrap and upgrade — do not edit manually.
HOOKS_VERSION="2.1"
#
# ── Per-Developer Overrides (Team Use) ──
# This file is git-tracked (shared by all team members).
# To override settings locally without affecting the team, create:
#   .claude/hooks-config.local.sh
# This file is git-ignored and sourced AFTER this file + strict enforcement.
# Example: override workflow mode for your own sessions:
#   echo 'WORKFLOW_MODE="lite"' > .claude/hooks-config.local.sh
# Or disable a specific hook:
#   echo 'HOOK_ENTRY_GATE_SESSION=false' >> .claude/hooks-config.local.sh
#
# ── Workflow Mode Presets ──
# Set WORKFLOW_MODE to auto-configure hooks and audit defaults for your project.
# Individual overrides below still take precedence over the mode preset.
#
#   freestyle — Hackathon, experiments, learning. Safety only, zero workflow enforcement.
#               Enables: protect-claude, protect-secrets, validate-tracking, session-start, id-uniqueness (5/11)
#               Disables: entry-gate-session, close-gate, sprint-close, audit-signals, test-regression
#               Gates: none enforced (AI follows WORKFLOW.md voluntarily)
#               Cross-audit defaults: N/A (not recommended)
#
#   lite     — Solo dev, small projects. Lightweight gates with basic enforcement.
#              Enables: 5 core + close-gate + test-regression (7/11)
#              Disables: entry-gate-session, sprint-close, audit-signals (CP1/CP2)
#              Gates: abbreviated Entry Gate, basic Close Gate (sprint-audit.sh + verdict)
#              Cross-audit defaults: wave-size 8, context minimal, min-changes 5
#
#   standard — Default. Full workflow with all hooks.
#              Enables: all hooks (11/11)
#              Cross-audit defaults: wave-size 5, context standard, min-changes 3
#
#   strict   — Team + critical systems. All hooks mandatory, no individual overrides.
#              Enables: all hooks (overrides ignored — see note below)
#              Cross-audit defaults: wave-size 3, context full, min-changes 1, enforce-block true
#
# Usage: set WORKFLOW_MODE and leave individual flags commented out to use the preset.
#        Or set WORKFLOW_MODE and override specific flags below.
#        strict mode ignores individual overrides — all hooks are forced on.

WORKFLOW_MODE="standard"  # ← "freestyle", "lite", "standard", or "strict"

# ── Mode-based defaults ──
case "${WORKFLOW_MODE}" in
  freestyle)
    # Safety only — zero workflow enforcement
    _PROTECT_CLAUDE_MD=true
    _PROTECT_SECRETS=true
    _VALIDATE_TRACKING=true
    _SESSION_START_PROTOCOL=true
    _VALIDATE_ID_UNIQUENESS=true
    _ENTRY_GATE_SESSION=false
    _DETECT_TEST_REGRESSION=false
    _VALIDATE_CLOSE_GATE=false
    _VALIDATE_SPRINT_CLOSE=false
    _DETECT_AUDIT_SIGNALS=false
    # Cross-audit: not tuned (use global defaults if enabled manually)
    ;;
  lite)
    # Core safety + close gate + test regression
    _PROTECT_CLAUDE_MD=true
    _PROTECT_SECRETS=true
    _VALIDATE_TRACKING=true
    _SESSION_START_PROTOCOL=true
    _VALIDATE_ID_UNIQUENESS=true
    _ENTRY_GATE_SESSION=false
    _DETECT_TEST_REGRESSION=true
    _VALIDATE_CLOSE_GATE=true
    _VALIDATE_SPRINT_CLOSE=false
    _DETECT_AUDIT_SIGNALS=false
    # Cross-audit: relaxed defaults for small projects
    _D_CROSS_AUDIT_WAVE_SIZE=8
    _D_CROSS_AUDIT_CONTEXT=minimal
    _D_CROSS_AUDIT_MIN_CHANGES=5
    _D_CROSS_AUDIT_ENFORCE_BLOCK=false
    ;;
  strict)
    # All hooks forced on (overrides ignored after local config load)
    _PROTECT_CLAUDE_MD=true
    _PROTECT_SECRETS=true
    _VALIDATE_TRACKING=true
    _SESSION_START_PROTOCOL=true
    _VALIDATE_ID_UNIQUENESS=true
    _ENTRY_GATE_SESSION=true
    _DETECT_TEST_REGRESSION=true
    _VALIDATE_CLOSE_GATE=true
    _VALIDATE_SPRINT_CLOSE=true
    _DETECT_AUDIT_SIGNALS=true
    # Cross-audit: tighter defaults for critical projects
    _D_CROSS_AUDIT_WAVE_SIZE=3
    _D_CROSS_AUDIT_CONTEXT=full
    _D_CROSS_AUDIT_MIN_CHANGES=1
    _D_CROSS_AUDIT_ENFORCE_BLOCK=true
    ;;
  *)  # standard (default)
    _PROTECT_CLAUDE_MD=true
    _PROTECT_SECRETS=true
    _VALIDATE_TRACKING=true
    _SESSION_START_PROTOCOL=true
    _VALIDATE_ID_UNIQUENESS=true
    _ENTRY_GATE_SESSION=true
    _DETECT_TEST_REGRESSION=true
    _VALIDATE_CLOSE_GATE=true
    _VALIDATE_SPRINT_CLOSE=true
    _DETECT_AUDIT_SIGNALS=true
    # Cross-audit: balanced defaults
    _D_CROSS_AUDIT_WAVE_SIZE=5
    _D_CROSS_AUDIT_CONTEXT=standard
    _D_CROSS_AUDIT_MIN_CHANGES=3
    _D_CROSS_AUDIT_ENFORCE_BLOCK=false
    ;;
esac

# ── Individual overrides ──
# Uncomment and set to override the mode preset.
# In strict mode, individual overrides are ignored (all hooks forced on).

# Prevent CLAUDE.md from being overwritten (highest priority rule)
HOOK_PROTECT_CLAUDE_MD="${HOOK_PROTECT_CLAUDE_MD:-$_PROTECT_CLAUDE_MD}"

# Prevent AI from reading .env, .key, .pem, credentials — secrets stay in hooks only
HOOK_PROTECT_SECRETS="${HOOK_PROTECT_SECRETS:-$_PROTECT_SECRETS}"

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

# ══════════════════════════════════════════════════════════════
# ── Cross-LLM Audit, Thresholds, Limits & Dashboard ──
# ══════════════════════════════════════════════════════════════
#
# HOW TO CHANGE A SETTING:
#   1. Edit the value in the "Defaults" table below      (applies to whole team)
#   2. Or put it in .claude/hooks-config.local.sh         (personal, git-ignored)
#   3. Or export as env var: export WAVE_SIZE=10          (temporary, current shell)
#
#   Priority: env var > hooks-config.local.sh > defaults below
#
# API key lives in .env (git-ignored) — never paste into git-tracked files.
# Guided setup: bash .claude/setup-audit.sh
# Full guide:   Docs/CROSS-LLM-AUDIT.md

# ── Defaults (_D_ = Default value) ────────────────────────────
# _D_ prefix marks the default value for each setting.
# Edit the values on the RIGHT side to change defaults.
#
#            Setting                          Value         Description
#            ───────                          ─────         ───────────
# Cross-LLM Audit
_D_ENABLE_CROSS_AUDIT=false                              # Master switch
_D_CROSS_AUDIT_PROVIDER=openai                           # "openai" or "anthropic"
_D_CROSS_AUDIT_TRIGGER=wave                              # "wave" (every N edits) or "item" (every edit)
_D_CROSS_AUDIT_CONTEXT="${_D_CROSS_AUDIT_CONTEXT:-standard}"  # "minimal", "standard", "full" (mode-aware)
_D_CROSS_AUDIT_LANG=en                                   # "en" or "tr"
_D_CROSS_AUDIT_MIN_CHANGES="${_D_CROSS_AUDIT_MIN_CHANGES:-3}"  # Min changed lines to trigger (mode-aware)
_D_CROSS_AUDIT_TIMEOUT=60                                # API timeout (seconds)
_D_CROSS_AUDIT_SKIP_SUBAGENT=true                        # Skip in worktree sub-agents
_D_CROSS_AUDIT_ENFORCE_BLOCK="${_D_CROSS_AUDIT_ENFORCE_BLOCK:-false}"  # Exit non-zero on BLOCK (mode-aware)
# Wave Batching
_D_CROSS_AUDIT_WAVE_SIZE="${_D_CROSS_AUDIT_WAVE_SIZE:-5}"  # Edits before wave fires (mode-aware)
_D_CROSS_AUDIT_LOCK_TIMEOUT=5                            # Flock timeout (seconds)
# Diff Truncation (max characters sent to external LLM)
_D_CROSS_AUDIT_MAX_DIFF_CLOSE_GATE=48000                 # Close Gate (holistic sprint)
_D_CROSS_AUDIT_MAX_DIFF_WAVE=32000                       # Wave review
_D_CROSS_AUDIT_MAX_DIFF_ENTRY_GATE=32000                 # Entry Gate (plan review)
_D_CROSS_AUDIT_MAX_DIFF_PER_EDIT=24000                   # Per-edit
# Audit Signal Thresholds
_D_AUDIT_CP1_THRESHOLD=0.20                              # CP1: metric regression (0.20 = 20%)
_D_AUDIT_CP2_MIN_SPRINTS=2                               # CP2: recurring failure (sprint count)
# Log & Health
_D_AUDIT_LOG_MAX_BYTES=1048576                           # Log rotation: max size (1MB)
_D_AUDIT_LOG_KEEP_LINES=500                              # Log rotation: lines to keep
_D_AUDIT_HEALTH_STALE_SECONDS=3600                       # Health: stale threshold (1 hour)
_D_AUDIT_HEALTH_ERROR_THRESHOLD=5                        # Health: error count threshold
# Dashboard
_D_DASHBOARD_SEARCH_DEPTH=3                              # File search depth (directory levels)

# ── API Base & Model (auto-set per provider, uncomment to override) ──
# Examples:
#   OpenAI:        https://api.openai.com/v1           (auto-set when provider=openai)
#   Anthropic:     https://api.anthropic.com            (auto-set when provider=anthropic)
#   GitHub Models: https://models.inference.ai.azure.com
#   OpenRouter:    https://openrouter.ai/api/v1
#   Ollama:        http://localhost:11434/v1
#   LM Studio:     http://localhost:1234/v1
#   Azure OpenAI:  https://{name}.openai.azure.com/openai/deployments/{deploy}
# CROSS_AUDIT_API_BASE=https://openrouter.ai/api/v1
#
# Model examples:
#   OpenAI:     gpt-4o (auto-set), gpt-4o-mini, gpt-4.1
#   Anthropic:  claude-sonnet-4-20250514 (auto-set), claude-haiku-4-5-20251001
#   OpenRouter: openai/gpt-4o, anthropic/claude-3.5-sonnet
#   Ollama:     llama3, mistral, codellama
# CROSS_AUDIT_MODEL=gpt-4o-mini

# ── Apply defaults (env vars and local overrides take precedence) ─────
ENABLE_CROSS_AUDIT="${ENABLE_CROSS_AUDIT:-$_D_ENABLE_CROSS_AUDIT}"
CROSS_AUDIT_PROVIDER="${CROSS_AUDIT_PROVIDER:-$_D_CROSS_AUDIT_PROVIDER}"
CROSS_AUDIT_TRIGGER="${CROSS_AUDIT_TRIGGER:-$_D_CROSS_AUDIT_TRIGGER}"
CROSS_AUDIT_CONTEXT="${CROSS_AUDIT_CONTEXT:-$_D_CROSS_AUDIT_CONTEXT}"
CROSS_AUDIT_LANG="${CROSS_AUDIT_LANG:-$_D_CROSS_AUDIT_LANG}"
CROSS_AUDIT_MIN_CHANGES="${CROSS_AUDIT_MIN_CHANGES:-$_D_CROSS_AUDIT_MIN_CHANGES}"
CROSS_AUDIT_TIMEOUT="${CROSS_AUDIT_TIMEOUT:-$_D_CROSS_AUDIT_TIMEOUT}"
CROSS_AUDIT_SKIP_SUBAGENT="${CROSS_AUDIT_SKIP_SUBAGENT:-$_D_CROSS_AUDIT_SKIP_SUBAGENT}"
CROSS_AUDIT_ENFORCE_BLOCK="${CROSS_AUDIT_ENFORCE_BLOCK:-$_D_CROSS_AUDIT_ENFORCE_BLOCK}"
CROSS_AUDIT_WAVE_SIZE="${CROSS_AUDIT_WAVE_SIZE:-$_D_CROSS_AUDIT_WAVE_SIZE}"
CROSS_AUDIT_LOCK_TIMEOUT="${CROSS_AUDIT_LOCK_TIMEOUT:-$_D_CROSS_AUDIT_LOCK_TIMEOUT}"
CROSS_AUDIT_MAX_DIFF_CLOSE_GATE="${CROSS_AUDIT_MAX_DIFF_CLOSE_GATE:-$_D_CROSS_AUDIT_MAX_DIFF_CLOSE_GATE}"
CROSS_AUDIT_MAX_DIFF_WAVE="${CROSS_AUDIT_MAX_DIFF_WAVE:-$_D_CROSS_AUDIT_MAX_DIFF_WAVE}"
CROSS_AUDIT_MAX_DIFF_ENTRY_GATE="${CROSS_AUDIT_MAX_DIFF_ENTRY_GATE:-$_D_CROSS_AUDIT_MAX_DIFF_ENTRY_GATE}"
CROSS_AUDIT_MAX_DIFF_PER_EDIT="${CROSS_AUDIT_MAX_DIFF_PER_EDIT:-$_D_CROSS_AUDIT_MAX_DIFF_PER_EDIT}"
AUDIT_CP1_THRESHOLD="${AUDIT_CP1_THRESHOLD:-$_D_AUDIT_CP1_THRESHOLD}"
AUDIT_CP2_MIN_SPRINTS="${AUDIT_CP2_MIN_SPRINTS:-$_D_AUDIT_CP2_MIN_SPRINTS}"
AUDIT_LOG_MAX_BYTES="${AUDIT_LOG_MAX_BYTES:-$_D_AUDIT_LOG_MAX_BYTES}"
AUDIT_LOG_KEEP_LINES="${AUDIT_LOG_KEEP_LINES:-$_D_AUDIT_LOG_KEEP_LINES}"
AUDIT_HEALTH_STALE_SECONDS="${AUDIT_HEALTH_STALE_SECONDS:-$_D_AUDIT_HEALTH_STALE_SECONDS}"
AUDIT_HEALTH_ERROR_THRESHOLD="${AUDIT_HEALTH_ERROR_THRESHOLD:-$_D_AUDIT_HEALTH_ERROR_THRESHOLD}"
DASHBOARD_SEARCH_DEPTH="${DASHBOARD_SEARCH_DEPTH:-$_D_DASHBOARD_SEARCH_DEPTH}"

# ── Per-developer local overrides (git-ignored) ──
# Sourced here so local settings override mode defaults above,
# but BEFORE strict enforcement (strict cannot be overridden locally).
_LOCAL_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hooks-config.local.sh"
[[ -f "$_LOCAL_CONFIG" ]] && source "$_LOCAL_CONFIG"

# ── Strict mode enforcement ──
# Applied AFTER local overrides — strict mode is team-wide and cannot be bypassed.
if [[ "${WORKFLOW_MODE}" == "strict" ]]; then
  HOOK_PROTECT_CLAUDE_MD=true
  HOOK_PROTECT_SECRETS=true
  HOOK_VALIDATE_TRACKING=true
  HOOK_SESSION_START_PROTOCOL=true
  HOOK_VALIDATE_ID_UNIQUENESS=true
  HOOK_ENTRY_GATE_SESSION=true
  HOOK_DETECT_TEST_REGRESSION=true
  HOOK_VALIDATE_CLOSE_GATE=true
  HOOK_VALIDATE_SPRINT_CLOSE=true
  HOOK_DETECT_AUDIT_SIGNALS=true
fi
