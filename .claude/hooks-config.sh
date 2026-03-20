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
HOOKS_VERSION="3.1"
#
# ── Per-Developer Overrides ──
# This file is git-tracked (shared by all team members).
# To override settings locally, add them to .env (git-ignored).
# .env is loaded AFTER this file — values there override defaults here.
# Example: put in .env:
#   WORKFLOW_MODE=lite
#   HOOK_ENTRY_GATE_SESSION=false
#   CROSS_AUDIT_MODEL=gpt-4o-mini
#
# ── Workflow Mode Presets ──
# Set WORKFLOW_MODE to auto-configure hooks and audit defaults for your project.
# Individual overrides below still take precedence over the mode preset.
#
#   freestyle — Safety only, zero workflow enforcement.
#   lite     — Solo dev, lightweight gates.
#   standard — Default. Full workflow, all hooks.
#   strict   — All hooks mandatory, no overrides, enforce-block.
#
#   See Docs/Workflow/WORKFLOW-MODES.md for full comparison table.
#
# Usage: set WORKFLOW_MODE and leave individual flags commented out to use the preset.
#        Or set WORKFLOW_MODE and override specific flags below.
#        strict mode ignores individual overrides — all hooks are forced on.

WORKFLOW_MODE="standard"  # ← "freestyle", "lite", "standard", or "strict"

# Allow .env to override WORKFLOW_MODE before the case block runs
_ENV_FILE_EARLY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"
if [[ -f "$_ENV_FILE_EARLY" ]]; then
  _env_mode=$(grep -E '^[[:space:]]*(export[[:space:]]+)?WORKFLOW_MODE=' "$_ENV_FILE_EARLY" 2>/dev/null | tail -1 | sed -E 's/.*=//; s/^[[:space:]]*["'"'"']?//; s/["'"'"']?[[:space:]]*$//')
  [[ -n "$_env_mode" ]] && WORKFLOW_MODE="$_env_mode"
fi

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
    _MEMORY_SYNC=true
    _CROSS_LLM_AUDIT=false
    _BOOTSTRAP_GUARD=true
    _BOOTSTRAP_PHASE_GATE=true
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
    _MEMORY_SYNC=true
    _CROSS_LLM_AUDIT=true
    _BOOTSTRAP_GUARD=true
    _BOOTSTRAP_PHASE_GATE=true
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
    _MEMORY_SYNC=true
    _CROSS_LLM_AUDIT=true
    _BOOTSTRAP_GUARD=true
    _BOOTSTRAP_PHASE_GATE=true
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
    _MEMORY_SYNC=true
    _CROSS_LLM_AUDIT=true
    _BOOTSTRAP_GUARD=true
    _BOOTSTRAP_PHASE_GATE=true
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

# Persist session context across compaction and session boundaries
HOOK_MEMORY_SYNC="${HOOK_MEMORY_SYNC:-$_MEMORY_SYNC}"

# Cross-LLM audit: external model reviews code changes (requires API key in .env)
HOOK_CROSS_LLM_AUDIT="${HOOK_CROSS_LLM_AUDIT:-$_CROSS_LLM_AUDIT}"

# Bootstrap phase guard: enforce research + review before project file creation
# PostToolUse: inject phase context + create markers on WebSearch/Agent usage
# PreToolUse: block CLAUDE.md/TRACKING.md writes until markers exist
HOOK_BOOTSTRAP_GUARD="${HOOK_BOOTSTRAP_GUARD:-$_BOOTSTRAP_GUARD}"

# Bootstrap phase gate: block CLAUDE.md/TRACKING.md creation until research+review phases complete
# PreToolUse: checks for .bootstrap/ markers before allowing Write|Edit on project files
HOOK_BOOTSTRAP_PHASE_GATE="${HOOK_BOOTSTRAP_PHASE_GATE:-$_BOOTSTRAP_PHASE_GATE}"

# ══════════════════════════════════════════════════════════════
# ── Cross-LLM Audit, Thresholds, Limits & Dashboard ──
# ══════════════════════════════════════════════════════════════
#
# HOW TO CHANGE A SETTING:
#   1. Edit the value in the "Defaults" table below      (applies to whole team)
#   2. Or put it in .env                                  (personal, git-ignored)
#   3. Or export as env var: export CROSS_AUDIT_TIMEOUT=120  (temporary, current shell)
#
#   Priority: env var > .env > defaults below
#
# API key lives in .env (git-ignored) — never paste into git-tracked files.
# Guided setup: bash .claude/setup-audit.sh
# Full guide:   Docs/Workflow/CROSS-LLM-AUDIT.md

# ── Defaults (_D_ = Default value) ────────────────────────────
# _D_ prefix marks the default value for each setting.
# Edit the values on the RIGHT side to change defaults.
#
# ┌─────────────────────────────────────────────────────────────┐
# │  COMMONLY CHANGED — most users only need to touch these     │
# └─────────────────────────────────────────────────────────────┘
_D_CROSS_AUDIT_PROVIDER=openai                           # "openai" or "anthropic"
_D_CROSS_AUDIT_MODEL=                                    # Empty = auto-set per provider (see examples below)
_D_CROSS_AUDIT_LANG=en                                   # "en" or "tr"
_D_CROSS_AUDIT_ENFORCE_BLOCK="${_D_CROSS_AUDIT_ENFORCE_BLOCK:-false}"  # Exit non-zero on BLOCK (mode-aware)
#
# ┌─────────────────────────────────────────────────────────────┐
# │  POWER USER — rarely changed, safe to ignore                │
# └─────────────────────────────────────────────────────────────┘
_D_CROSS_AUDIT_API_BASE=                                 # Empty = auto-set per provider (see examples below)
_D_CROSS_AUDIT_TIMEOUT=60                                # API timeout (seconds)
_D_CROSS_AUDIT_MAX_DIFF=32000                            # Base diff limit — derived: wave=×1, close-gate=×1.5, entry-gate=×1
_D_AUDIT_CP1_THRESHOLD=0.20                              # CP1: metric regression (0.20 = 20%)
_D_AUDIT_CP2_MIN_SPRINTS=2                               # CP2: recurring failure (sprint count)
_D_DASHBOARD_SEARCH_DEPTH=3                              # File search depth (directory levels)

# ── API Base & Model examples ──
# Leave _D_CROSS_AUDIT_API_BASE and _D_CROSS_AUDIT_MODEL empty (above) to auto-set per provider.
# Or set them to use a custom endpoint. Override per-developer in .env.
#
# API Base examples:
#   OpenAI:        https://api.openai.com/v1           (auto-set when provider=openai)
#   Anthropic:     https://api.anthropic.com            (auto-set when provider=anthropic)
#   GitHub Models: https://models.inference.ai.azure.com
#   OpenRouter:    https://openrouter.ai/api/v1
#   Ollama:        http://localhost:11434/v1
#   LM Studio:     http://localhost:1234/v1
#   Azure OpenAI:  https://{name}.openai.azure.com/openai/deployments/{deploy}
#
# Model examples:
#   OpenAI:     gpt-4o (auto-set), gpt-4o-mini, gpt-4.1
#   Anthropic:  claude-sonnet-4-20250514 (auto-set), claude-haiku-4-5-20251001
#   OpenRouter: openai/gpt-4o, anthropic/claude-3.5-sonnet
#   Ollama:     llama3, mistral, codellama

# ── Apply defaults (env vars and local overrides take precedence) ─────
CROSS_AUDIT_PROVIDER="${CROSS_AUDIT_PROVIDER:-$_D_CROSS_AUDIT_PROVIDER}"
CROSS_AUDIT_API_BASE="${CROSS_AUDIT_API_BASE:-$_D_CROSS_AUDIT_API_BASE}"
CROSS_AUDIT_MODEL="${CROSS_AUDIT_MODEL:-$_D_CROSS_AUDIT_MODEL}"
CROSS_AUDIT_LANG="${CROSS_AUDIT_LANG:-$_D_CROSS_AUDIT_LANG}"
CROSS_AUDIT_TIMEOUT="${CROSS_AUDIT_TIMEOUT:-$_D_CROSS_AUDIT_TIMEOUT}"
CROSS_AUDIT_ENFORCE_BLOCK="${CROSS_AUDIT_ENFORCE_BLOCK:-$_D_CROSS_AUDIT_ENFORCE_BLOCK}"
CROSS_AUDIT_MAX_DIFF="${CROSS_AUDIT_MAX_DIFF:-$_D_CROSS_AUDIT_MAX_DIFF}"
# Derived diff limits (base × multiplier) — override individual limits via env if needed
CROSS_AUDIT_MAX_DIFF_WAVE="${CROSS_AUDIT_MAX_DIFF_WAVE:-$CROSS_AUDIT_MAX_DIFF}"
CROSS_AUDIT_MAX_DIFF_ENTRY_GATE="${CROSS_AUDIT_MAX_DIFF_ENTRY_GATE:-$CROSS_AUDIT_MAX_DIFF}"
CROSS_AUDIT_MAX_DIFF_CLOSE_GATE="${CROSS_AUDIT_MAX_DIFF_CLOSE_GATE:-$(( CROSS_AUDIT_MAX_DIFF * 3 / 2 ))}"
AUDIT_CP1_THRESHOLD="${AUDIT_CP1_THRESHOLD:-$_D_AUDIT_CP1_THRESHOLD}"
AUDIT_CP2_MIN_SPRINTS="${AUDIT_CP2_MIN_SPRINTS:-$_D_AUDIT_CP2_MIN_SPRINTS}"
DASHBOARD_SEARCH_DEPTH="${DASHBOARD_SEARCH_DEPTH:-$_D_DASHBOARD_SEARCH_DEPTH}"

# ── Per-developer overrides from .env (git-ignored) ──
# Loaded here so .env values override defaults above,
# but BEFORE strict enforcement (strict cannot be overridden).
_ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.env"
if [[ -f "$_ENV_FILE" ]]; then
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    [[ -z "$_line" || "$_line" =~ ^[[:space:]]*# ]] && continue
    _key="${_line%%=*}"
    _val="${_line#*=}"
    _key=$(echo "$_key" | sed 's/^[[:space:]]*export[[:space:]]*//' | tr -d '[:space:]')
    _val=$(echo "$_val" | sed -E 's/[[:space:]]+#.*$//; s/^[[:space:]]*["'"'"']?//; s/["'"'"']?[[:space:]]*$//')
    [[ "$_key" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
    export "$_key=$_val"
  done < "$_ENV_FILE"
fi

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
  HOOK_MEMORY_SYNC=true
  HOOK_CROSS_LLM_AUDIT=true
  HOOK_BOOTSTRAP_GUARD=true
  HOOK_BOOTSTRAP_PHASE_GATE=true
fi
