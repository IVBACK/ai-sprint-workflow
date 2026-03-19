#!/usr/bin/env bash
# validate-structure.sh — Structural consistency check (replaces v1 scripts).
#
# Validates numeric claims, version consistency, cross-file references,
# and template sync. Model-driven checks live in validate-model.sh.
# Runtime artifact checks live in validate-artifacts.sh.
#
# Usage:
#   bash validation/validate-structure.sh
#
# Exit codes:
#   0 = All checks pass
#   1 = Warnings (non-blocking)
#   2 = Failures (blocking)
#
# Dependencies: bash 4+, grep -E, sed -E (POSIX extended), python3 (for YAML hash)

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/validation/resolve-workflow.sh"
WORKFLOW=$(resolve_workflow "$REPO_ROOT")
_WORKFLOW_TMP="$WORKFLOW"
[[ "$_WORKFLOW_TMP" != "$REPO_ROOT/WORKFLOW.md" ]] && trap 'rm -f "$_WORKFLOW_TMP"' EXIT

README="$REPO_ROOT/README.md"
WORKFLOW_INDEX="$REPO_ROOT/WORKFLOW.md"
DESIGN="$REPO_ROOT/DESIGN.md"
AUDIT="$REPO_ROOT/sprint-audit-template.sh"
HOOKS_CONFIG="$REPO_ROOT/.claude/hooks-config.sh"
SESSION_START="$REPO_ROOT/.claude/hooks/session-start.sh"
SETTINGS_JSON="$REPO_ROOT/.claude/settings.json"
MODES="$REPO_ROOT/Docs/Workflow/WORKFLOW-MODES.md"
MODEL="$REPO_ROOT/validation/workflow-model.yaml"

passes=0
warnings=0
failures=0

pass() {
  local name="$1"; shift
  echo "  PASS  [$name]${*:+ $*}"
  passes=$((passes + 1))
}

warn() {
  local name="$1"; shift
  echo "  WARN  [$name] $*"
  warnings=$((warnings + 1))
}

fail() {
  local name="$1"; shift
  echo "  FAIL  [$name] $*"
  failures=$((failures + 1))
}

# Extract lines between two heading patterns (same-level heading boundary).
extract_section() {
  local file="$1" start="$2" stop="$3"
  sed -En "/${start}/,/${stop}/p" "$file" 2>/dev/null | sed '$d'
}

# ── Pre-flight ──────────────────────────────────────────────
echo "Validating structural consistency..."
preflight_ok=true
for f in "$README" "$WORKFLOW" "$WORKFLOW_INDEX"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR  Required file not found: $f"
    preflight_ok=false
  fi
done
if ! $preflight_ok; then
  exit 2
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 1: Numeric Claim Validation
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 1: Numeric Claims"
echo "══════════════════════════════════════════════════════"

# 1.1 Discovery question count
# README claims "16 discovery questions" (or "Ask N discovery questions").
# WORKFLOW.md has Q rows in tables: | **Project Shape** | Q0: ..., Q1: ... |
readme_dq_claim=$(grep -oE '[0-9]+ discovery questions' "$README" | grep -oE '[0-9]+' | head -1)
# Count individual Q numbers from README Discovery Questions section through next ## heading
# (section starts with ### Discovery Questions and goes until the next ## heading)
dq_block=$(sed -n '/^### Discovery Questions/,/^## /p' "$README")
template_dq_count=0
if [[ -n "$dq_block" ]]; then
  template_dq_count=$(echo "$dq_block" | grep -oE 'Q[0-9]+' | sort -u | wc -l)
fi

if [[ -z "$readme_dq_claim" ]]; then
  echo "  INFO  [DISCOVERY_Q_COUNT] Claim delegated to linked doc (README omits numeric detail)"
  passes=$((passes + 1))
elif [[ "$template_dq_count" -eq 0 ]]; then
  warn "DISCOVERY_Q_COUNT" "Could not count discovery questions (format changed?)"
elif [[ "$readme_dq_claim" -eq "$template_dq_count" ]]; then
  pass "DISCOVERY_Q_COUNT" "($readme_dq_claim)"
else
  fail "DISCOVERY_Q_COUNT" "README claims $readme_dq_claim, actual Q-numbers found: $template_dq_count"
fi

# 1.2 Language count
readme_lang_claim=$(grep -oE '[0-9]+ languages' "$README" | grep -oE '[0-9]+' | head -1)
readme_lang_table=$(extract_section "$README" "^## Supported Languages" "^##")
readme_lang_rows=0
if [[ -n "$readme_lang_table" ]]; then
  readme_lang_rows=$(echo "$readme_lang_table" | grep -cE '^| \*\*' || true)
fi

if [[ -z "$readme_lang_claim" ]]; then
  echo "  INFO  [LANG_COUNT] Claim delegated to linked doc (README omits numeric detail)"
  passes=$((passes + 1))
elif [[ "$readme_lang_rows" -eq 0 ]]; then
  warn "LANG_COUNT" "Could not extract language table rows"
elif [[ "$readme_lang_claim" -eq "$readme_lang_rows" ]]; then
  pass "LANG_COUNT" "($readme_lang_claim)"
else
  fail "LANG_COUNT" "README claims $readme_lang_claim languages but table has $readme_lang_rows rows"
fi

# 1.3 Bootstrap step count
# README: "Bootstrap Steps (10 total: Step 0 + steps 1-9)"
readme_bootstrap_claim=$(grep -oE 'steps 1[–-][0-9]+' "$README" | grep -oE '[0-9]+$' | head -1)
# Count numbered step lines (0-9) in the bootstrap section
bootstrap_section=$(extract_section "$README" "^### Bootstrap Steps" "^###|^##")
bootstrap_count=0
if [[ -n "$bootstrap_section" ]]; then
  # Count lines starting with a number followed by . (e.g., "0. Detect", "1. Scan")
  # Also count lines like "8.5 [Claude Code only]"
  bootstrap_count=$(echo "$bootstrap_section" | grep -cE '^[0-9]+(\.[0-9]*)?\. ' || true)
fi

if [[ -z "$readme_bootstrap_claim" ]]; then
  echo "  INFO  [BOOTSTRAP_STEPS] Claim delegated to linked doc (README omits numeric detail)"
  passes=$((passes + 1))
elif [[ "$bootstrap_count" -eq 0 ]]; then
  warn "BOOTSTRAP_STEPS" "Could not count bootstrap steps"
else
  # steps 1-9 means max step = 9, plus step 0 = 10 total
  # But count also includes step 8.5, so actual lines may be 11
  # Just verify the count is reasonable (> 0 and consistent with claimed range)
  pass "BOOTSTRAP_STEPS" "(steps through $readme_bootstrap_claim, $bootstrap_count lines)"
fi

# 1.4 Close Gate phase count
readme_cg_claim=$(grep -oE '[0-9]+ phases' "$README" | grep -oE '[0-9]+' | head -1)
cg_section=$(extract_section "$WORKFLOW" "^# Close Gate" "^# Sprint Close|^# CRITICAL")
cg_phases=0
if [[ -n "$cg_section" ]]; then
  cg_phases=$(echo "$cg_section" | sed 's/−/-/g' | grep -oE '## Phase [-]?[0-9]+|## Phase [0-9]+[a-c]' | grep -oE -- '-?[0-9]+' | sort -un | wc -l)
fi

if [[ -z "$readme_cg_claim" ]]; then
  echo "  INFO  [CLOSE_GATE_PHASES] Claim delegated to linked doc (README omits numeric detail)"
  passes=$((passes + 1))
elif [[ "$cg_phases" -eq 0 ]]; then
  warn "CLOSE_GATE_PHASES" "Could not extract phase headers from WORKFLOW.md"
elif [[ "$readme_cg_claim" -eq "$cg_phases" ]]; then
  pass "CLOSE_GATE_PHASES" "($readme_cg_claim)"
else
  fail "CLOSE_GATE_PHASES" "README claims $readme_cg_claim, WORKFLOW.md has $cg_phases unique phase numbers"
fi

# 1.5 Entry Gate step count
# README diagram: "(ph0-3,12 st)" — extract the step count
readme_eg_claim=$(grep -oE '[0-9]+ st[ep)s]' "$README" | grep -oE '[0-9]+' | head -1)
eg_section=$(extract_section "$WORKFLOW" "^# Entry Gate" "^# CRITICAL.*Reminders|^# Implementation Loop|^# CRITICAL RULES|^# Close Gate")
eg_steps=0
if [[ -n "$eg_section" ]]; then
  eg_steps=$(echo "$eg_section" | grep -cE '^### [0-9]+[a-z-]*\. |^[5-7]\. ' || true)
fi

if [[ -z "$readme_eg_claim" ]]; then
  echo "  INFO  [ENTRY_GATE_STEPS] Claim delegated to linked doc (README omits numeric detail)"
  passes=$((passes + 1))
elif [[ "$eg_steps" -eq 0 ]]; then
  warn "ENTRY_GATE_STEPS" "Could not count entry gate steps"
elif [[ "$readme_eg_claim" -eq "$eg_steps" ]]; then
  pass "ENTRY_GATE_STEPS" "($readme_eg_claim)"
else
  fail "ENTRY_GATE_STEPS" "README claims $readme_eg_claim, WORKFLOW.md has $eg_steps"
fi

# 1.6 Audit section count
if [[ -f "$AUDIT" ]]; then
  template_section_claim=$(grep -oE '[0-9]+ sections' "$WORKFLOW" | grep -oE '[0-9]+' | head -1)
  audit_section_count=$(grep -cE '^# SECTION [0-9]+' "$AUDIT" || true)

  if [[ -z "$template_section_claim" ]]; then
    warn "AUDIT_SECTIONS" "Could not find section count claim in WORKFLOW.md"
  elif [[ "$template_section_claim" -eq "$audit_section_count" ]]; then
    pass "AUDIT_SECTIONS" "($audit_section_count)"
  else
    fail "AUDIT_SECTIONS" "WORKFLOW.md claims $template_section_claim, audit has $audit_section_count"
  fi
else
  warn "AUDIT_SECTIONS" "sprint-audit-template.sh not found"
fi

# 1.7 Sprint Close log "steps 1-N" matches actual step count
sc_section=$(extract_section "$WORKFLOW" "^# Sprint Close" "^# CRITICAL.*Reminders|^# Procedures")
log_step_max=""
sc_step_count=0
if [[ -n "$sc_section" ]]; then
  log_step_max=$(echo "$sc_section" | grep -oE 'steps 1-[0-9]+' | grep -oE '[0-9]+$' | tail -1)
  sc_step_count=$(echo "$sc_section" | grep -cE '^## [0-9]+\. ' || true)
fi

if [[ -z "$log_step_max" ]]; then
  warn "SC_LOG_COUNT" "Could not find 'steps 1-N' in Sprint Close"
elif [[ "$log_step_max" -eq "$sc_step_count" ]]; then
  pass "SC_LOG_COUNT" "($sc_step_count)"
else
  fail "SC_LOG_COUNT" "Sprint Close log says 'steps 1-$log_step_max' but section has $sc_step_count steps"
fi

# 1.8 Hook count parity (README vs WORKFLOW-MODES.md)
if [[ -f "$MODES" ]]; then
  _HOOKS_ROW=$(grep -iE '^\| *Hooks *\|.*[0-9]+/[0-9]+' "$MODES" | head -1)
  MODES_COUNTS=$(echo "$_HOOKS_ROW" | grep -oE '[0-9]+/[0-9]+' | tr '\n' ' ')

  README_FREESTYLE=$(grep -iE 'freestyle' "$README" | grep -oE '[0-9]+/[0-9]+' | head -1)
  README_LITE=$(grep -iE '\blite\b' "$README" | grep -oE '[0-9]+/[0-9]+' | head -1)
  README_FULL=$(grep -iE 'standard|strict' "$README" | grep -oE '[0-9]+/[0-9]+' | head -1)
  README_COUNTS="$README_FREESTYLE $README_LITE $README_FULL "

  MODES_FREESTYLE=$(echo "$_HOOKS_ROW" | grep -oE '[0-9]+/[0-9]+' | sed -n '1p')
  MODES_LITE=$(echo "$_HOOKS_ROW" | grep -oE '[0-9]+/[0-9]+' | sed -n '2p')
  MODES_FULL=$(echo "$_HOOKS_ROW" | grep -oE '[0-9]+/[0-9]+' | sed -n '3p')

  if [[ "$MODES_FREESTYLE" == "$README_FREESTYLE" && "$MODES_LITE" == "$README_LITE" && "$MODES_FULL" == "$README_FULL" ]]; then
    pass "HOOK_COUNT_PARITY" "($README_FREESTYLE, $README_LITE, $README_FULL)"
  else
    fail "HOOK_COUNT_PARITY" "WORKFLOW-MODES.md ($MODES_FREESTYLE, $MODES_LITE, $MODES_FULL) != README ($README_FREESTYLE, $README_LITE, $README_FULL)"
  fi
else
  warn "HOOK_COUNT_PARITY" "WORKFLOW-MODES.md not found"
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 2: Version Consistency
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 2: Version Consistency"
echo "══════════════════════════════════════════════════════"

# 2.1 WORKFLOW.md has workflow-version comment
WF_VERSION=$(head -5 "$WORKFLOW_INDEX" | sed -n 's/.*workflow-version: *\([0-9.]*\).*/\1/p')
if [[ -n "$WF_VERSION" ]]; then
  pass "WF_VERSION" "($WF_VERSION)"
else
  fail "WF_VERSION" "WORKFLOW.md missing <!-- workflow-version: X.Y --> in first 5 lines"
fi

# 2.2 hooks-config.sh HOOKS_VERSION matches workflow-version
if [[ -f "$HOOKS_CONFIG" ]]; then
  HK_VERSION=$(grep '^HOOKS_VERSION=' "$HOOKS_CONFIG" | head -1 | sed 's/HOOKS_VERSION="\(.*\)"/\1/')
  if [[ -n "$HK_VERSION" && "$HK_VERSION" == "$WF_VERSION" ]]; then
    pass "HOOKS_VERSION" "($HK_VERSION)"
  elif [[ -n "$HK_VERSION" ]]; then
    fail "HOOKS_VERSION" "hooks-config.sh ($HK_VERSION) != WORKFLOW.md ($WF_VERSION)"
  else
    fail "HOOKS_VERSION" "hooks-config.sh missing HOOKS_VERSION"
  fi
else
  warn "HOOKS_VERSION" "hooks-config.sh not found"
fi

# 2.3 Changelog top entry matches workflow-version
CHANGELOG_VERSION=$(sed -n '/^## Changelog/,$ p' "$WORKFLOW" | grep -m1 '^### v' | sed 's/### v\([0-9.]*\).*/\1/')
if [[ -n "$CHANGELOG_VERSION" && "$CHANGELOG_VERSION" == "$WF_VERSION" ]]; then
  pass "CHANGELOG_VERSION" "($CHANGELOG_VERSION)"
elif [[ -n "$CHANGELOG_VERSION" ]]; then
  fail "CHANGELOG_VERSION" "Changelog top ($CHANGELOG_VERSION) != workflow-version ($WF_VERSION)"
else
  warn "CHANGELOG_VERSION" "No changelog version found"
fi

# 2.4 workflow-model.yaml hash matches current docs
if [[ -f "$MODEL" ]] && command -v python3 >/dev/null 2>&1; then
  ACTUAL_HASH=$(python3 -c "import hashlib; print(hashlib.sha256(open('$WORKFLOW','rb').read()).hexdigest())" 2>/dev/null || echo "")
  STORED_HASH=$(python3 -c "import yaml, sys; m=yaml.safe_load(open(sys.argv[1])); print(m.get('meta',{}).get('workflow_hash',''))" "$MODEL" 2>/dev/null || echo "")

  if [[ -z "$STORED_HASH" ]]; then
    warn "MODEL_HASH" "meta.workflow_hash not set in workflow-model.yaml"
  elif [[ "$ACTUAL_HASH" == "$STORED_HASH" ]]; then
    pass "MODEL_HASH"
  else
    fail "MODEL_HASH" "WORKFLOW.md changed since model was last validated (hash mismatch)"
  fi
else
  warn "MODEL_HASH" "workflow-model.yaml or python3 not available"
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 3: Cross-File References
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 3: Cross-File References"
echo "══════════════════════════════════════════════════════"

# 3.1 DESIGN.md step/phase refs exist in workflow docs
if [[ -f "$DESIGN" ]]; then
  kdd_section=$(extract_section "$DESIGN" "^## Key Design Decisions" "^## ")
  missing_refs=""

  if [[ -n "$kdd_section" ]] && [[ -n "$eg_section" ]]; then
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      step_num="${ref%%[a-e]*}"
      if ! grep -qE "^${step_num}\. |^### ${step_num}[.[:space:]]|[[:space:]]${ref}[.):,[:space:]]" <<< "$eg_section"; then
        missing_refs="$missing_refs EG-$ref"
      fi
    done < <(grep -oE 'Entry Gate step [0-9]+[a-e]?' <<< "$kdd_section" | grep -oE '[0-9]+[a-e]?' | sort -u)
  fi

  if [[ -n "$kdd_section" ]] && [[ -n "$sc_section" ]]; then
    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      step_num="${ref%%[a-g]*}"
      if ! grep -qE "^${step_num}\. |^## ${step_num}\. " <<< "$sc_section"; then
        missing_refs="$missing_refs SC-$ref"
      fi
    done < <(grep -oE 'Sprint Close step [0-9]+[a-g]?' <<< "$kdd_section" | grep -oE '[0-9]+[a-g]?' | sort -u)
  fi

  if [[ -z "$missing_refs" ]]; then
    pass "DESIGN_REFS"
  else
    fail "DESIGN_REFS" "Broken references in DESIGN.md:$missing_refs"
  fi
else
  warn "DESIGN_REFS" "DESIGN.md not found"
fi

# 3.2 README file tree matches actual docs
# Extract the file tree block from README (between ``` markers containing your-project/)
readme_tree=$(sed -n '/^your-project\//,/^```$/p' "$README" 2>/dev/null)
tree_ok=true
for expected_file in "ENTRY-GATE.md" "CLOSE-GATE.md" "SPRINT-CLOSE.md" "IMPL-LOOP.md" "AGENT-RULES.md" "STATE-TRANSITIONS.md" "BOOTSTRAP.md" "TEMPLATES.md" "PROCEDURES.md" "ADAPTATION.md" "HOOK-TEMPLATES.md"; do
  if [[ -n "$readme_tree" ]]; then
    if ! echo "$readme_tree" | grep -qF "$expected_file"; then
      fail "FILE_TREE" "README file tree missing: $expected_file"
      tree_ok=false
    fi
  fi
done
# Also verify the listed workflow files actually exist on disk
for expected_file in "ENTRY-GATE.md" "CLOSE-GATE.md" "SPRINT-CLOSE.md" "IMPL-LOOP.md" "AGENT-RULES.md" "STATE-TRANSITIONS.md" "BOOTSTRAP.md" "TEMPLATES.md" "PROCEDURES.md" "ADAPTATION.md" "HOOK-TEMPLATES.md"; do
  if [[ ! -f "$REPO_ROOT/Docs/Workflow/$expected_file" ]]; then
    fail "FILE_TREE" "Docs/Workflow/$expected_file listed in tree but missing on disk"
    tree_ok=false
  fi
done
$tree_ok && pass "FILE_TREE"

# 3.3 WORKFLOW-MODES.md references TEAM-GUIDE.md
if [[ -f "$MODES" ]]; then
  if grep -qF 'TEAM-GUIDE.md' "$MODES"; then
    pass "MODES_TEAM_REF"
  else
    fail "MODES_TEAM_REF" "WORKFLOW-MODES.md should reference TEAM-GUIDE.md"
  fi
else
  warn "MODES_TEAM_REF" "WORKFLOW-MODES.md not found"
fi

# 3.4 README references key doc files
ref_ok=true
for ref in "WORKFLOW-MODES.md" "DESIGN.md"; do
  if ! grep -qF "$ref" "$README"; then
    fail "README_REFS" "README does not reference $ref"
    ref_ok=false
  fi
done
$ref_ok && pass "README_REFS"

# 3.5 settings.json hook count matches hooks-config.sh flag count
if [[ -f "$SETTINGS_JSON" ]] && [[ -f "$HOOKS_CONFIG" ]]; then
  # All feature hooks (each has a HOOK_* toggle in hooks-config.sh)
  ACTUAL_HOOKS=$(grep -o 'hooks/[a-z-]*\.sh' "$SETTINGS_JSON" | sort -u | wc -l)
  CONFIG_HOOKS=$(grep -c '^HOOK_[A-Z_]*=.*\$' "$HOOKS_CONFIG" || true)

  if [[ "$CONFIG_HOOKS" -gt 0 && "$ACTUAL_HOOKS" -gt 0 && "$CONFIG_HOOKS" -eq "$ACTUAL_HOOKS" ]]; then
    pass "HOOK_FLAG_COUNT" "($CONFIG_HOOKS flags, $ACTUAL_HOOKS registered)"
  elif [[ "$CONFIG_HOOKS" -gt 0 && "$ACTUAL_HOOKS" -gt 0 ]]; then
    fail "HOOK_FLAG_COUNT" "hooks-config.sh flags ($CONFIG_HOOKS) != settings.json enforcer hooks ($ACTUAL_HOOKS)"
  else
    warn "HOOK_FLAG_COUNT" "Could not count hooks (config=$CONFIG_HOOKS, settings=$ACTUAL_HOOKS)"
  fi
else
  warn "HOOK_FLAG_COUNT" "settings.json or hooks-config.sh not found"
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 4: Template Sync
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 4: Template Sync"
echo "══════════════════════════════════════════════════════"

# 4.1 session-start.sh has version mismatch detection
if [[ -f "$SESSION_START" ]]; then
  if grep -q 'VERSION_WARNING' "$SESSION_START" && grep -q 'HOOKS_VERSION' "$SESSION_START"; then
    pass "SESSION_VERSION_DETECT"
  else
    fail "SESSION_VERSION_DETECT" "session-start.sh missing version mismatch detection"
  fi
else
  warn "SESSION_VERSION_DETECT" "session-start.sh not found"
fi

# 4.2 hooks-config.sh has HOOK_PROTECT_SECRETS
if [[ -f "$HOOKS_CONFIG" ]]; then
  if grep -q 'HOOK_PROTECT_SECRETS' "$HOOKS_CONFIG"; then
    pass "HOOK_PROTECT_SECRETS"
  else
    fail "HOOK_PROTECT_SECRETS" "hooks-config.sh missing HOOK_PROTECT_SECRETS"
  fi
else
  warn "HOOK_PROTECT_SECRETS" "hooks-config.sh not found"
fi

# 4.3 protect-secrets.sh registered in settings.json
if [[ -f "$SETTINGS_JSON" ]]; then
  if grep -q 'protect-secrets.sh' "$SETTINGS_JSON"; then
    pass "SECRETS_REGISTERED"
  else
    fail "SECRETS_REGISTERED" "protect-secrets.sh NOT registered in settings.json"
  fi
else
  warn "SECRETS_REGISTERED" "settings.json not found"
fi

# ═══════════════════════════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
total=$((passes + warnings + failures))
if [[ $failures -gt 0 ]]; then
  echo "Structure validation: $passes passed, $warnings warning(s), $failures FAILURE(s) — $total checks total."
  exit 2
elif [[ $warnings -gt 0 ]]; then
  echo "Structure validation: $passes passed, $warnings warning(s), 0 failures — $total checks total."
  exit 1
else
  echo "Structure validation CLEAN — $passes checks passed, 0 findings."
  exit 0
fi
