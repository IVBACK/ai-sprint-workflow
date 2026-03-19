#!/usr/bin/env bash
# Hook: cross-llm-audit.sh
# Event: PostToolUse — Edit|Write
# Purpose: After wave/item implementation, send changes to an external LLM
#          for independent code review. Returns structured findings as
#          additionalContext so Claude can present them alongside its own assessment.
#
# Enabled by default — requires CROSS_AUDIT_API_KEY to be set.
#   API key goes in .env (project root, git-ignored)
#   or in shell profile (~/.bashrc, ~/.config/fish/config.fish)
#   Silently skips if no API key is configured.
#
# Supports any OpenAI-compatible API (OpenAI, GitHub Models, Azure, Ollama, OpenRouter, etc.)
#
# Configuration (env vars or hooks-config.sh):
#   CROSS_AUDIT_API_KEY                — API key (required)
#   CROSS_AUDIT_PROVIDER               — "openai" or "anthropic" (default: openai)
#   CROSS_AUDIT_API_BASE               — API base URL (auto-set per provider)
#   CROSS_AUDIT_MODEL                  — Model to use (default: gpt-4o / claude-sonnet-4-20250514)
#   CROSS_AUDIT_LANG                   — Review language: "en" or "tr" (default: en)
#   CROSS_AUDIT_WAVE_SIZE              — Edits before wave fires (default: 5)
#   CROSS_AUDIT_TIMEOUT                — API timeout in seconds (default: 60)
#
# Exit: 0 normally. If CROSS_AUDIT_ENFORCE_BLOCK=true and verdict=BLOCK, exits 1.
# Injects additionalContext on findings. All invocations are logged to .claude/.state/cross-audit-log.jsonl.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Load shared audit library (logging, secret scrubbing, API helpers) ──
if [[ ! -f "$HOOKS_DIR/_audit-lib.sh" ]]; then
  echo "Cross-audit: _audit-lib.sh not found — hook cannot run." >&2
  exit 0
fi
source "$HOOKS_DIR/_audit-lib.sh"

# ── Load config (hooks-config.sh loads .env automatically) ──
source "$HOOKS_DIR/../hooks-config.sh"

# ── Toggle check ──
[[ "$HOOK_CROSS_LLM_AUDIT" != "true" ]] && exit 0

# ── Sub-agent detection: skip cross-audit in worktree-based sub-agents ──
# Sub-agents run in isolated worktrees (CLAUDE_PROJECT_DIR differs from git toplevel).
# Cross-audit in sub-agents is wasteful (narrow scope, results don't reach coordinator).
# The coordinator reviews the full diff at wave/gate boundaries instead.
_GIT_TOPLEVEL=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --show-toplevel 2>/dev/null || true)
_REAL_PROJECT=$(cd "${CLAUDE_PROJECT_DIR:-.}" && pwd -P 2>/dev/null || true)
if [[ -n "$_GIT_TOPLEVEL" && -n "$_REAL_PROJECT" ]]; then
  _REAL_TOPLEVEL=$(cd "$_GIT_TOPLEVEL" && pwd -P 2>/dev/null || true)
  if [[ "$_REAL_PROJECT" != "$_REAL_TOPLEVEL" ]]; then
    _log_audit "skip" "sub-agent"
    exit 0
  fi
fi

# ── Dependencies ──
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found, skipping. Install: apt/brew/pacman/choco install jq" >&2
  _log_audit "skip" "missing-jq"; exit 0
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "Cross-audit: DISABLED — 'curl' is not installed. Install curl to enable cross-LLM audit." >&2
  _log_audit "skip" "missing-curl"; exit 0
fi

# ── API key required ──
if [[ -z "${CROSS_AUDIT_API_KEY:-}" ]]; then
  echo "Cross-audit: DISABLED — no API key configured. Run 'bash .claude/setup-audit.sh' to set up." >&2
  _log_audit "skip" "no-api-key"; exit 0
fi

# ── Safety: reject keys that look like they were hardcoded (not from env) ──
# If the key is found verbatim in hooks-config.sh, someone pasted it into a git-tracked file.
# Only check real keys (20+ chars) to avoid false positives on short test values.
_CONFIG_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/hooks-config.sh"
if [[ ${#CROSS_AUDIT_API_KEY} -ge 20 && -f "$_CONFIG_FILE" ]] \
   && grep -qF "${CROSS_AUDIT_API_KEY}" "$_CONFIG_FILE" 2>/dev/null; then
  echo "Cross-audit: BLOCKED — your API key is in hooks-config.sh (git-tracked!)." >&2
  echo "  Move it to your shell profile (~/.bashrc or ~/.config/fish/config.fish) instead." >&2
  _log_audit "skip" "key-in-config"
  exit 0
fi

# ── Read hook input ──
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only trigger on Edit or Write
if [[ "$TOOL" != "Edit" && "$TOOL" != "Write" ]]; then _log_audit "skip" "wrong-tool"; exit 0; fi

# ── Detect audit mode ──
# Close Gate file → holistic sprint review (full sprint diff against main)
# Entry Gate file → plan review
# Source file → per-edit review (existing behavior)
AUDIT_MODE="per-edit"
case "$FILE" in
  *_CLOSE_GATE*.md) AUDIT_MODE="close-gate" ;;
  *_ENTRY_GATE*.md) AUDIT_MODE="entry-gate" ;;
  *TRACKING*.md)    AUDIT_MODE="wave-review" ;;
  *CLAUDE.md|*WORKFLOW*.md|*[Rr]oadmap*.md|*ROADMAP*.md|*SPRINT_CLOSE*|\
  *GUARDRAILS*|*LESSONS*|*.json|*.yaml|*.yml|*.toml|*.lock|*.env*) _log_audit "skip" "excluded-file"; exit 0 ;;
esac

# ── Configuration defaults ──
PROVIDER="${CROSS_AUDIT_PROVIDER:-openai}"  # "openai" or "anthropic"
API_BASE="${CROSS_AUDIT_API_BASE:-}"
MODEL="${CROSS_AUDIT_MODEL:-}"
# Auto-set provider-specific defaults when not configured
if [[ -z "$API_BASE" || -z "$MODEL" ]]; then
  if [[ "$PROVIDER" == "anthropic" ]]; then
    API_BASE="${API_BASE:-https://api.anthropic.com}"
    MODEL="${MODEL:-claude-sonnet-4-20250514}"
  else
    API_BASE="${API_BASE:-https://api.openai.com/v1}"
    MODEL="${MODEL:-gpt-4o}"
  fi
fi
AUDIT_LANG="${CROSS_AUDIT_LANG:-en}"
TIMEOUT="${CROSS_AUDIT_TIMEOUT:-60}"
WAVE_SIZE="${CROSS_AUDIT_WAVE_SIZE:-5}"
LOCK_TIMEOUT="${CROSS_AUDIT_LOCK_TIMEOUT:-5}"

# ── Trigger control: wave vs item ──
# For "wave" mode, we use a counter file to batch changes.
# The audit fires after the Nth source file edit (default: when user is asked for approval).
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
# Counter file uses .claude/.state/ for persistence (survives /tmp/ cleanup, container restarts).
# Per-user counters prevent race conditions when multiple developers share a machine.
# Override with CROSS_AUDIT_COUNTER_FILE env var for testing.
_STATE_DIR="${PROJECT_DIR}/.claude/.state"
mkdir -p "$_STATE_DIR" 2>/dev/null
_USER_ID="${USER:-${LOGNAME:-unknown}}"
COUNTER_FILE="${CROSS_AUDIT_COUNTER_FILE:-${_STATE_DIR}/cross-audit-counter-${_USER_ID}}"

# Gate and wave-review always fire immediately — wave counting only applies to per-edit
if [[ "$AUDIT_MODE" == "per-edit" ]]; then
  # Increment counter (atomic via flock if available)
  # Returns exit code 0 = threshold reached (continue to audit),
  #                    7 = below threshold (skip audit).
  # Uses code 7 (not 0/1) so callers can distinguish "skip" from errors.
  _do_wave_count() {
    COUNT=0
    [[ -f "$COUNTER_FILE" ]] && COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
    COUNT=$((COUNT + 1))
    echo "$COUNT" > "$COUNTER_FILE"

    # In wave mode, only fire every Nth edit (configured via CROSS_AUDIT_WAVE_SIZE)
    # OR when explicitly signaled via CROSS_AUDIT_FIRE=true
    if [[ "$COUNT" -lt "$WAVE_SIZE" && "${CROSS_AUDIT_FIRE:-}" != "true" ]]; then
      return 7
    fi
    # Reset counter after firing
    echo "0" > "$COUNTER_FILE"
    return 0
  }

  # Use flock for atomic counter access if available; fallback to direct access
  if command -v flock >/dev/null 2>&1; then
    _wave_result=0
    (
      flock -w "$LOCK_TIMEOUT" 200 || exit 1
      _do_wave_count
    ) 200>"${COUNTER_FILE}.lock"
    _wave_result=$?
    # 7 = below threshold (skip audit), 1 = flock failed (skip safely), 0 = fire
    if [[ $_wave_result -ne 0 ]]; then _log_audit "skip" "wave-below-threshold"; exit 0; fi
  else
    _do_wave_count || { _log_audit "skip" "wave-below-threshold"; exit 0; }
  fi
fi

# ── Gather diff (strategy depends on audit mode) ──
cd "$PROJECT_DIR" 2>/dev/null || {
  echo "Cross-audit: ERROR — project directory '$PROJECT_DIR' not found." >&2
  _log_audit "error" "bad-project-dir"
  exit 0
}

# HEAD fallback: if no commits yet, use empty tree as base
if git rev-parse --verify HEAD >/dev/null 2>&1; then
  _DIFF_BASE="HEAD"
  _DIFF_BASE_PREV="HEAD~1"
else
  _DIFF_BASE="$(git hash-object -t tree /dev/null)"  # empty tree
  _DIFF_BASE_PREV="$_DIFF_BASE"
fi

if [[ "$AUDIT_MODE" == "close-gate" ]]; then
  # Holistic: full sprint diff against main branch
  MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
  # Try common main branch names
  for branch in "$MAIN_BRANCH" main master; do
    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
      COMBINED_DIFF=$(git diff "$branch"..."$_DIFF_BASE" -- ':!*.env' ':!*.env.*' ':!*.key' ':!*.pem' ':!*.p12' ':!*credentials*' ':!*secrets*' 2>/dev/null || true)
      break
    fi
  done
  # Increase truncation limit for holistic review (more context needed)
  MAX_DIFF_CHARS="${CROSS_AUDIT_MAX_DIFF_CLOSE_GATE:-48000}"
elif [[ "$AUDIT_MODE" == "wave-review" ]]; then
  # Wave boundary: coordinator just merged sub-agent work and updated TRACKING.md
  # Review the recent uncommitted + last commit changes (wave merge typically just committed)
  # Use diff of HEAD~1..HEAD (last commit = wave merge) + any uncommitted changes
  COMBINED_DIFF=$(git diff "$_DIFF_BASE_PREV" -- ':!*.env' ':!*.env.*' ':!*.key' ':!*.pem' ':!*.p12' ':!*credentials*' ':!*secrets*' ':!*TRACKING*.md' ':!*.json' ':!*.yaml' ':!*.yml' 2>/dev/null || true)
  # Fallback: if no previous commit or diff is empty, use uncommitted changes
  if [[ -z "$COMBINED_DIFF" ]]; then
    COMBINED_DIFF=$(git diff "$_DIFF_BASE" -- ':!*.env' ':!*.env.*' ':!*.key' ':!*.pem' ':!*.p12' ':!*credentials*' ':!*secrets*' ':!*TRACKING*.md' 2>/dev/null || true)
  fi
  MAX_DIFF_CHARS="${CROSS_AUDIT_MAX_DIFF_WAVE:-32000}"
elif [[ "$AUDIT_MODE" == "entry-gate" ]]; then
  # Entry Gate: send the gate report content itself, not code diff
  COMBINED_DIFF=""
  [[ -f "$FILE" ]] && COMBINED_DIFF=$(cat "$FILE" 2>/dev/null || true)
  MAX_DIFF_CHARS="${CROSS_AUDIT_MAX_DIFF_ENTRY_GATE:-32000}"
else
  # Per-edit: current uncommitted changes (staged + unstaged vs HEAD)
  # Exclude sensitive files from diff sent to external LLM
  COMBINED_DIFF=$(git diff "$_DIFF_BASE" -- ':!*.env' ':!*.env.*' ':!*.key' ':!*.pem' ':!*.p12' ':!*credentials*' ':!*secrets*' 2>/dev/null || true)
  MAX_DIFF_CHARS="${CROSS_AUDIT_MAX_DIFF_PER_EDIT:-24000}"
fi

# Check minimum change threshold (skip for entry-gate — always review the plan)
if [[ -z "$COMBINED_DIFF" ]]; then
  # One-time warning: if repo has no commits, explain why audit can't run
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    _NO_COMMIT_MARKER="${_STATE_DIR}/.no-commit-warned"
    if [[ ! -f "$_NO_COMMIT_MARKER" ]]; then
      echo "Cross-audit: No commits yet — git diff is empty. Make your first commit so the audit has a diff to review." >&2
      touch "$_NO_COMMIT_MARKER" 2>/dev/null
    fi
  fi
  _log_audit "skip" "empty-diff"
  exit 0
fi
if [[ "$AUDIT_MODE" == "per-edit" || "$AUDIT_MODE" == "wave-review" ]]; then
  CHANGED_LINES=$(echo "$COMBINED_DIFF" | grep -cE '^\+[^+]|^-[^-]' 2>/dev/null || echo 0)
else
  CHANGED_LINES=$(echo "$COMBINED_DIFF" | wc -l | tr -d ' ')
fi

# Truncate if too large
if [[ ${#COMBINED_DIFF} -gt $MAX_DIFF_CHARS ]]; then
  COMBINED_DIFF="${COMBINED_DIFF:0:$MAX_DIFF_CHARS}

... [TRUNCATED — diff exceeded ${MAX_DIFF_CHARS} chars] ..."
fi

# ── Secret scrubbing (via shared library) ──
COMBINED_DIFF=$(echo "$COMBINED_DIFF" | _scrub_secrets)

# ── Build context layers ──

# Layer 1: Always — active item from TRACKING.md
ITEM_CONTEXT=""
TRACKING=$(find "$PROJECT_DIR" -maxdepth 2 -name "TRACKING*.md" 2>/dev/null | sort | head -1)
if [[ -f "$TRACKING" ]]; then
  ACTIVE_ITEMS=$(grep -E '^\| CORE-[0-9]+' "$TRACKING" \
    | awk -F'|' '{gsub(/^ +| +$/,"",$4); if ($4=="in_progress" || $4=="fixed") print $0}' \
    | head -5 2>/dev/null || true)
  [[ -n "$ACTIVE_ITEMS" ]] && ITEM_CONTEXT="## Active Items (from TRACKING.md)
$ACTIVE_ITEMS"
fi

# Layer 1: Critical axis from CLAUDE.md
CRITICAL_AXIS=""
CLAUDE_MD=$(find "$PROJECT_DIR" -maxdepth 1 -name "CLAUDE.md" 2>/dev/null | head -1)
if [[ -f "$CLAUDE_MD" ]]; then
  AXIS_LINE=$(grep -i "critical.*axis\|#1 priority\|critical priority" "$CLAUDE_MD" 2>/dev/null | head -1)
  [[ -n "$AXIS_LINE" ]] && CRITICAL_AXIS="## Critical Axis
$AXIS_LINE"
fi

# Layer 1b: Sprint goal from Roadmap (all modes)
SPRINT_GOAL=""
ROADMAP=$(find "$PROJECT_DIR" -maxdepth 3 -name "*Roadmap*.md" -o -name "*ROADMAP*.md" 2>/dev/null | head -1)
if [[ -f "${ROADMAP:-}" ]]; then
  GOAL_LINE=$(grep -A3 'Sprint.*[Gg]oal\|## Sprint' "$ROADMAP" 2>/dev/null | head -4)
  [[ -n "$GOAL_LINE" ]] && SPRINT_GOAL="## Sprint Goal
$GOAL_LINE"
fi

# Layer 1c: Immutable contracts from CLAUDE.md (all modes)
CONTRACTS=""
if [[ -f "${CLAUDE_MD:-}" ]]; then
  CONTRACT_SECTION=$(sed -n '/[Ii]mmutable [Cc]ontract/,/^##/{/^##/!p;}' "$CLAUDE_MD" | head -20)
  [[ -n "$CONTRACT_SECTION" ]] && CONTRACTS="## Immutable Contracts
$CONTRACT_SECTION"
fi

# Layer 1d: Sprint progress (all modes)
SPRINT_PROGRESS=""
if [[ -f "${TRACKING:-}" ]]; then
  _TOTAL=$(grep -cE '^\| CORE-' "$TRACKING" 2>/dev/null || echo 0)
  _DONE=$(grep -cE '^\| CORE-.*\| (verified|fixed)' "$TRACKING" 2>/dev/null || echo 0)
  [[ "$_TOTAL" -gt 0 ]] && SPRINT_PROGRESS="Sprint progress: ${_DONE}/${_TOTAL} items completed"
fi

# Guardrails
GUARDRAILS_CONTEXT=""
GUARDRAILS=$(find "$PROJECT_DIR" -maxdepth 3 -name "*GUARDRAILS*" -o -name "*guardrails*" 2>/dev/null | sort | head -1)
if [[ -f "$GUARDRAILS" ]]; then
  GUARDRAILS_CONTENT=$(head -c 3000 "$GUARDRAILS")
  GUARDRAILS_CONTEXT="## Coding Rules (project guardrails)
$GUARDRAILS_CONTENT"
fi

# Failure modes from Entry Gate
FAILURE_MODES=""
ENTRY_GATE=$(find "$PROJECT_DIR" -maxdepth 3 -name "S*_ENTRY_GATE.md" 2>/dev/null | sort -r | head -1)
if [[ -f "$ENTRY_GATE" ]]; then
  FM_SECTION=$(sed -n '/[Ff]ailure [Mm]ode/,/^##/{/^##/!p;}' "$ENTRY_GATE" | head -40)
  [[ -n "$FM_SECTION" ]] && FAILURE_MODES="## Predicted Failure Modes (from Entry Gate)
$FM_SECTION"
fi

# Acceptance criteria from Entry Gate
AC_CONTEXT=""
if [[ -f "${ENTRY_GATE:-}" ]]; then
  AC_SECTION=$(sed -n '/[Aa]cceptance [Cc]riteria\|[Vv]erification [Pp]lan/,/^##/{/^##/!p;}' "$ENTRY_GATE" | head -30)
  [[ -n "$AC_SECTION" ]] && AC_CONTEXT="## Acceptance Criteria (from Entry Gate)
$AC_SECTION"
fi

# Full file context (for per-edit mode)
FULL_FILE_CONTEXT=""
if [[ -f "$FILE" ]]; then
  FILE_CONTENT=$(head -c 8000 "$FILE")
  FULL_FILE_CONTEXT="## Full File Context ($FILE)
\`\`\`
$FILE_CONTENT
\`\`\`"
fi

# ── Language directive ──
LANG_DIRECTIVE="Respond in English."
[[ "$AUDIT_LANG" == "tr" ]] && LANG_DIRECTIVE="Respond in Turkish (Türkçe)."

# ── Build review prompt (mode-specific) ──
if [[ "$AUDIT_MODE" == "close-gate" ]]; then
  MODE_INSTRUCTIONS="You are performing a HOLISTIC SPRINT REVIEW. This is the complete diff of all changes in this sprint (all items merged). ${LANG_DIRECTIVE}

${SPRINT_GOAL}

${SPRINT_PROGRESS}

${CRITICAL_AXIS}

${CONTRACTS}

${ITEM_CONTEXT}

${GUARDRAILS_CONTEXT}

${FAILURE_MODES}

${AC_CONTEXT}

## Full Sprint Changes
\`\`\`diff
${COMBINED_DIFF}
\`\`\`

## Instructions
This is a holistic review of the ENTIRE sprint, not a single edit. Focus on:
1. Cross-item consistency — do items work together correctly? API contracts match between producer/consumer?
2. Naming and pattern consistency across all changed files
3. Critical axis violations (if specified above)
4. Architectural coherence — is the overall design sound?
5. Missing integration points — do new components connect properly?
6. Security issues across the full change set
7. Coding rules violations (if guardrails provided)
8. Failure mode coverage — were predicted failure modes (listed above, if any) actually mitigated in the implementation? Flag any predicted risk that appears unaddressed.

SEVERITY DECISION TREE:
- BLOCK: acceptance criteria not met, security issue, critical axis violation, predicted failure mode not mitigated (if marked MUST)
- WARN: architectural debt, missing test coverage for failure modes, style inconsistencies, predicted failure mode not mitigated (if marked SHOULD/COULD), performance concern
- PASS: no cross-cutting issues found

Return JSON: {\"verdict\":\"PASS|WARN|BLOCK\",\"summary\":\"...\",\"findings\":[{\"severity\":\"high|medium|low\",\"file\":\"path\",\"line\":N,\"issue\":\"...\",\"suggestion\":\"...\"}]}
Focus on cross-cutting concerns that per-edit reviews would miss. Be concise."

elif [[ "$AUDIT_MODE" == "wave-review" ]]; then
  MODE_INSTRUCTIONS="You are reviewing a WAVE MERGE — the coordinator just merged parallel sub-agent work into the main branch. ${LANG_DIRECTIVE}

${SPRINT_GOAL}

${SPRINT_PROGRESS}

${CRITICAL_AXIS}

${CONTRACTS}

${ITEM_CONTEXT}

${GUARDRAILS_CONTEXT}

${FAILURE_MODES}

${AC_CONTEXT}

## Wave Merge Changes
\`\`\`diff
${COMBINED_DIFF}
\`\`\`

## Instructions
This is code from parallel sub-agents merged by the coordinator. Sub-agents work in isolation, so review BOTH integration AND code quality:

### A. Integration (primary focus)
1. Integration conflicts — do merged changes from different sub-agents work together correctly?
2. API contract consistency — do producer/consumer interfaces match across merged items?
3. Shared state conflicts — are there race conditions or conflicting writes to the same resources?
4. Import/dependency coherence — are all needed imports present? Any duplicate or conflicting dependencies?
5. Naming consistency — do newly added functions/variables follow the same conventions?

### B. Code quality (secondary — catch what per-edit reviews may have missed)
6. Bugs, edge cases, or missed error handling in the merged code
7. Security issues (injection, auth bypass, data exposure)
8. Critical axis violations (if specified above)

SEVERITY DECISION TREE:
- BLOCK: API contract mismatch between merged items, security issue, unhandled crash, shared state conflict that causes data corruption, incomplete API update (callers missing new signature)
- WARN: naming inconsistency across items, missing edge case, import duplication, style divergence between agents
- PASS: integration is clean, no code quality issues

Return JSON: {\"verdict\":\"PASS|WARN|BLOCK\",\"summary\":\"...\",\"findings\":[{\"severity\":\"high|medium|low\",\"file\":\"path\",\"line\":N,\"issue\":\"...\",\"suggestion\":\"...\",\"axis\":\"integration|quality\"}]}
Use the 'axis' field to indicate whether a finding is an integration or quality issue. Focus on cross-item problems but don't ignore obvious code bugs. Be concise."

elif [[ "$AUDIT_MODE" == "entry-gate" ]]; then
  MODE_INSTRUCTIONS="You are reviewing a SPRINT PLAN (Entry Gate report) for completeness and risks. ${LANG_DIRECTIVE}

${SPRINT_GOAL}

${SPRINT_PROGRESS}

${CRITICAL_AXIS}

${ITEM_CONTEXT}

${GUARDRAILS_CONTEXT}

## Entry Gate Report
${COMBINED_DIFF}

## Instructions
Review this sprint plan for:
1. Missing failure modes — are there risks not covered? Compare against item descriptions and dependencies.
2. Scope realism — 5-8 items is medium. If 4+ items are large refactors, or 3+ sequential dependencies exist, flag as risky.
3. Dependency gaps — are item dependencies identified? If A depends on B, is the order explicit?
4. Acceptance criteria quality — must be testable with clear pass/fail:
   ✓ 'GET /health returns 200 with {success:true}' (testable)
   ✓ 'Migration idempotent: running twice succeeds' (testable)
   ✗ 'System is stable' (unmeasurable)
   ✗ 'Performance is good' (no baseline)
   If 2+ ACs are unmeasurable, BLOCK.
5. Critical axis coverage — do items touching the critical axis have deeper analysis?
6. Missing items — compare items against sprint goal (above). Does the plan cover the stated scope?

SEVERITY DECISION TREE:
- BLOCK: unmeasurable acceptance criteria, missing failure mode for critical path, scope clearly unrealistic (10+ must items)
- WARN: dependency not explicit, missing failure mode for non-critical path, scope tight but feasible, AC could be more specific
- PASS: plan is complete and realistic

Return JSON: {\"verdict\":\"PASS|WARN|BLOCK\",\"summary\":\"...\",\"findings\":[{\"severity\":\"high|medium|low\",\"item\":\"CORE-NNN\",\"issue\":\"...\",\"suggestion\":\"...\"}]}
Be concise. Focus on real planning gaps, not formatting."

else
  MODE_INSTRUCTIONS="You are a code reviewer performing an independent audit. ${LANG_DIRECTIVE}

${SPRINT_GOAL}

${SPRINT_PROGRESS}

${CRITICAL_AXIS}

${CONTRACTS}

${ITEM_CONTEXT}

${GUARDRAILS_CONTEXT}

${FAILURE_MODES}

${AC_CONTEXT}

${FULL_FILE_CONTEXT}

## Changes to Review
\`\`\`diff
${COMBINED_DIFF}
\`\`\`

## Instructions
Review the changes for:
1. Acceptance criteria coverage — are the active items properly addressed?
2. Critical axis violations (if specified above)
3. Coding rules violations (if guardrails provided)
4. Bugs, edge cases, missed error handling
5. Predicted risks — are failure modes addressed?
6. Security issues (injection, auth bypass, data exposure)
7. Integration risk — could this change conflict with other active items listed above? Flag potential API mismatches, shared state mutations, or import conflicts that would surface when parallel work is merged.

SEVERITY DECISION TREE:
- BLOCK: security issue (injection, auth bypass, data exposure), unhandled crash, acceptance criteria violation, API contract break, critical axis violation
- WARN: logic bug in non-critical path, missing edge case, performance regression, style/naming violation, missing test coverage
- PASS: no issues found

Return JSON: {\"verdict\":\"PASS|WARN|BLOCK\",\"summary\":\"...\",\"findings\":[{\"severity\":\"high|medium|low\",\"file\":\"path\",\"line\":N,\"issue\":\"...\",\"suggestion\":\"...\"}]}
Be concise."
fi

REVIEW_PROMPT="$MODE_INSTRUCTIONS"

# ── API call (provider-specific) ──
# Write prompt to tmpfile to avoid ARG_MAX limits with large diffs (up to 48KB).
# jq --rawfile reads from file instead of passing as shell argument.
_PROMPT_TMPFILE=$(mktemp "${TMPDIR:-/tmp}/.cross-audit-prompt-XXXXXX")
trap 'rm -f "$_PROMPT_TMPFILE"' EXIT
printf '%s' "$REVIEW_PROMPT" > "$_PROMPT_TMPFILE"

if [[ "$PROVIDER" == "anthropic" ]]; then
  REQUEST_BODY=$(jq -n \
    --arg model "$MODEL" \
    --rawfile prompt "$_PROMPT_TMPFILE" \
    '{
      "model": $model,
      "messages": [{"role": "user", "content": $prompt}],
      "max_tokens": 2000,
      "temperature": 0.1
    }')

  RESPONSE=$(curl -s --max-time "$TIMEOUT" -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -H "x-api-key: ${CROSS_AUDIT_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    "${API_BASE}/v1/messages" \
    -d "$REQUEST_BODY" 2>/dev/null) || {
    if [[ "${API_BASE}" == *"localhost"* ]]; then
      echo "Cross-audit: Cannot reach ${API_BASE} — is your local model server running?" >&2
    else
      echo "Cross-audit: API call failed (timeout or network error). Check your connection." >&2
    fi
    _log_audit "error" "api-network-error"
    exit 0
  }
  _HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  RESPONSE=$(echo "$RESPONSE" | sed '$d')
else
  REQUEST_BODY=$(jq -n \
    --arg model "$MODEL" \
    --rawfile prompt "$_PROMPT_TMPFILE" \
    '{
      "model": $model,
      "messages": [{"role": "user", "content": $prompt}],
      "temperature": 0.1,
      "max_tokens": 2000,
      "response_format": {"type": "json_object"}
    }')

  RESPONSE=$(curl -s --max-time "$TIMEOUT" -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${CROSS_AUDIT_API_KEY}" \
    "${API_BASE}/chat/completions" \
    -d "$REQUEST_BODY" 2>/dev/null) || {
    if [[ "${API_BASE}" == *"localhost"* ]]; then
      echo "Cross-audit: Cannot reach ${API_BASE} — is your local model server running?" >&2
    else
      echo "Cross-audit: API call failed (timeout or network error). Check your connection." >&2
    fi
    _log_audit "error" "api-network-error"
    exit 0
  }
  _HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  RESPONSE=$(echo "$RESPONSE" | sed '$d')
fi

# ── Parse response (provider-specific) ──
if [[ "$PROVIDER" == "anthropic" ]]; then
  API_ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null)
  [[ -z "$API_ERROR" ]] && API_ERROR=$(echo "$RESPONSE" | jq -r '.error.type // empty' 2>/dev/null)
  CONTENT=$(echo "$RESPONSE" | jq -r '[.content[] | select(.type=="text") | .text] | join("")' 2>/dev/null)
  PROMPT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.input_tokens // "?"' 2>/dev/null)
  COMPLETION_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.output_tokens // "?"' 2>/dev/null)
else
  API_ERROR=$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null)
  CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
  PROMPT_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.prompt_tokens // "?"' 2>/dev/null)
  COMPLETION_TOKENS=$(echo "$RESPONSE" | jq -r '.usage.completion_tokens // "?"' 2>/dev/null)
fi

if [[ -n "$API_ERROR" ]]; then
  if [[ "${_HTTP_CODE:-}" == "401" || "${_HTTP_CODE:-}" == "403" ]]; then
    echo "Cross-audit: Authentication failed ($API_ERROR). Check your API key — run 'bash .claude/setup-audit.sh' to reconfigure." >&2
  elif [[ "${_HTTP_CODE:-}" == "404" || "${_HTTP_CODE:-}" == "400" ]]; then
    echo "Cross-audit: Model '$MODEL' not found or invalid ($API_ERROR). Run 'bash .claude/setup-audit.sh' to reconfigure." >&2
  else
    echo "Cross-audit: API error — $API_ERROR (HTTP ${_HTTP_CODE:-unknown})" >&2
  fi
  _log_audit "error" "api-error-${_HTTP_CODE:-unknown}"
  exit 0
fi
if [[ -z "$CONTENT" ]]; then
  echo "Cross-audit: Empty response from API" >&2
  _log_audit "error" "empty-response"
  exit 0
fi

# Try to parse verdict from JSON response
# Strategy: try raw first, then strip markdown fences, then extract JSON substring
VERDICT=$(echo "$CONTENT" | jq -r '.verdict // empty' 2>/dev/null || true)
if [[ -z "$VERDICT" ]]; then
  # Strip markdown fenced code blocks (handles indented fences too)
  CLEAN_CONTENT=$(echo "$CONTENT" | sed '/^[[:space:]]*```[a-z]*/d')
  VERDICT=$(echo "$CLEAN_CONTENT" | jq -r '.verdict // empty' 2>/dev/null || true)
fi
if [[ -z "$VERDICT" ]]; then
  # Last resort: extract from first { to last } (handles preamble/postamble text)
  CLEAN_CONTENT=$(echo "$CONTENT" | sed -n '/{/,/}/p')
  VERDICT=$(echo "$CLEAN_CONTENT" | jq -r '.verdict // empty' 2>/dev/null || true)
fi
if [[ -z "$VERDICT" ]]; then
  VERDICT="UNKNOWN"
  echo "Cross-audit: WARNING — Could not parse verdict from LLM response. Raw response logged." >&2
fi
# Normalize verdict: trim whitespace and uppercase
VERDICT=$(echo "$VERDICT" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

# ── Emit additionalContext ──
# Claude sees this and presents it alongside its own assessment.

DIRECTIVE=""

# ── Self-audit checklist (embedded for Claude to reference) ──
SELF_AUDIT_CHECKLIST_FULL="=== SELF-AUDIT CHECKLIST ===
1. BUG SCAN: off-by-one, null/undefined, type mismatch, boundary conditions, resource leak
2. SECURITY SCAN: input validation, auth/authz, no secrets in code, injection vectors (SQL, XSS, command, path traversal)
3. AC COMPLIANCE: diff supports acceptance criteria, no missing AC
4. GUARDRAIL COMPLIANCE: CODING_GUARDRAILS.md rules, naming, error handling, immutable contracts
5. INTEGRATION RISK: conflicts with active items (check TRACKING.md), shared state, API changes (skip in sub-agent)
6. CRITICAL AXIS CHECK: affects critical axis? improves/degrades? (skip if undefined)
7. FAILURE MODE CHECK: predicted modes from Entry Gate, new unpredicted modes
8. REGRESSION RISK: changes behavior validated by existing tests
=== END CHECKLIST ==="

SELF_AUDIT_CHECKLIST_LIGHT="=== SELF-AUDIT CHECKLIST (lightweight) ===
1. BUG SCAN: off-by-one, null/undefined, type mismatch, boundary conditions, resource leak
2. SECURITY SCAN: input validation, auth/authz, no secrets in code, injection vectors
3. AC COMPLIANCE: diff supports acceptance criteria, no missing AC
=== END CHECKLIST ==="

# ── Close-gate: no auto-fix to prevent infinite loops ──
_AUTOFIX_INSTRUCTION="If you AGREE: apply the fix and inform user what you changed."
if [[ "$AUDIT_MODE" == "close-gate" ]]; then
  _AUTOFIX_INSTRUCTION="Do NOT auto-fix. Present all findings to user for manual resolution (close-gate mode)."
fi

case "$VERDICT" in
  BLOCK)
    DIRECTIVE="DIRECTIVE: This external audit found BLOCKING issues.
1. Perform structured self-audit on the same diff using the checklist below.
2. Compare your findings with the external findings — for each finding, state AGREE or DISAGREE.
3. ${_AUTOFIX_INSTRUCTION}
4. If you DISAGREE with a BLOCK finding, you MUST still escalate to the user with both perspectives.
   You cannot unilaterally dismiss a BLOCK. Present: 'External says X because Y. I disagree because Z. User decision needed.'
Workflow-Mode: ${WORKFLOW_MODE:-standard}
Audit-Mode: ${AUDIT_MODE}

DISAGREEMENT CATEGORIES (be specific about which type):
- FACTUAL: 'This is not a bug because [specific reason — e.g., input is validated at line N]'
- SEVERITY: 'This is real but WARN not BLOCK because [impact is limited to X]'
- MITIGATION: 'This is handled by [existing code/test at file:line]'

${SELF_AUDIT_CHECKLIST_FULL}"
    ;;
  WARN)
    DIRECTIVE="DIRECTIVE: This external audit found warnings.
1. Perform structured self-audit on the same diff using the checklist below.
2. Compare findings — for each, state AGREE, DISAGREE, or PARTIAL.
   PARTIAL = the issue exists but the suggested fix is wrong or incomplete. Propose your own fix.
3. ${_AUTOFIX_INSTRUCTION} Log all disagreements in Change Log.
4. Inform user of any auto-fixes applied. Continue implementation.
Workflow-Mode: ${WORKFLOW_MODE:-standard}
Audit-Mode: ${AUDIT_MODE}

${SELF_AUDIT_CHECKLIST_FULL}"
    ;;
  PASS)
    DIRECTIVE="DIRECTIVE: External audit passed. Run lightweight self-audit (bug, security, AC only).
Fix anything you find. Mention external PASS as confidence signal.
Workflow-Mode: ${WORKFLOW_MODE:-standard}

${SELF_AUDIT_CHECKLIST_LIGHT}"
    ;;
  *)
    DIRECTIVE="DIRECTIVE: External audit returned an UNPARSEABLE response (verdict could not be extracted). Present raw response to user for manual review."
    ;;
esac

CONFLICT_RULE="COMPARISON RULES:
- For each external finding: state AGREE, DISAGREE, or PARTIAL with reasoning.
- BLOCK findings you disagree with MUST be escalated to the user — you cannot dismiss a BLOCK alone.
- When disagreeing, specify the category: FACTUAL (not a real issue), SEVERITY (real but lower impact), or MITIGATION (already handled).
- PARTIAL: the issue is real but the fix is wrong/incomplete — propose your own fix.
- Log all auto-fixes and disagreements."

# ── Persist WARN/BLOCK findings to durable log (append-only) ──
if [[ "$VERDICT" == "WARN" || "$VERDICT" == "BLOCK" ]]; then
  _FINDINGS_TRACKING=$(find "$PROJECT_DIR" -maxdepth 2 -name "TRACKING*.md" 2>/dev/null | sort | head -1)
  if [[ -f "$_FINDINGS_TRACKING" ]]; then
    _FINDINGS_DIR="$(dirname "$_FINDINGS_TRACKING")"
    _FINDINGS_LOG="$_FINDINGS_DIR/.findings-log"
    _FINDINGS_NOW=$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date -Iseconds)
    _FINDINGS_TAG="AUDIT-${VERDICT}"
    # Extract individual findings from JSON response
    _FINDING_LINES=$(echo "$CONTENT" | jq -r '.findings[]? | "\(.file // .item // "?"):\(.line // "?") \(.issue // "")"' 2>/dev/null || true)
    if [[ -n "$_FINDING_LINES" ]]; then
      echo "$_FINDING_LINES" | while IFS= read -r _fline; do
        [[ -z "$_fline" ]] && continue
        echo "[$_FINDINGS_NOW] ${_FINDINGS_TAG}: ${_fline} | model: ${MODEL}" >> "$_FINDINGS_LOG"
      done
    else
      # Fallback: log summary if findings array not parseable
      _SUMMARY=$(echo "$CONTENT" | jq -r '.summary // empty' 2>/dev/null || true)
      echo "[$_FINDINGS_NOW] ${_FINDINGS_TAG}: ${_SUMMARY:-unparseable response} | model: ${MODEL}" >> "$_FINDINGS_LOG"
    fi
  fi
fi

jq -n \
  --arg content "$CONTENT" \
  --arg verdict "$VERDICT" \
  --arg model "$MODEL" \
  --arg prompt_tokens "$PROMPT_TOKENS" \
  --arg completion_tokens "$COMPLETION_TOKENS" \
  --arg directive "$DIRECTIVE" \
  --arg conflict "$CONFLICT_RULE" \
  --arg changed "$CHANGED_LINES" \
  --arg wfmode "${WORKFLOW_MODE:-standard}" \
'{
  "additionalContext": (
    "=== CROSS-LLM AUDIT RESULT ===\n" +
    "Model: " + $model + " | Lines changed: " + $changed + " | Tokens: ~" + $prompt_tokens + " in / ~" + $completion_tokens + " out\n" +
    "Verdict: " + $verdict + " | Mode: " + $wfmode + "\n\n" +
    $content + "\n\n" +
    $directive + "\n" +
    $conflict + "\n" +
    "================================"
  )
}'

# ── P0: Log result ──
if [[ "$VERDICT" == "UNKNOWN" ]]; then
  _log_audit "parse-failed" "verdict-not-parseable" "$VERDICT"
else
  _log_audit "success" "" "$VERDICT"
fi

# ── P1: Mechanical BLOCK enforcement ──
# When enabled, BLOCK verdict causes non-zero exit → Claude Code treats as hook failure.
# Opt-in via CROSS_AUDIT_ENFORCE_BLOCK=true (default: false, advisory only).
if [[ "$VERDICT" == "BLOCK" && "${CROSS_AUDIT_ENFORCE_BLOCK:-false}" == "true" ]]; then
  exit 1
fi

exit 0
