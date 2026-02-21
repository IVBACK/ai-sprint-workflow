#!/usr/bin/env bash
# validate-scenarios.sh — Mutation tests for scenario acceptance tests
#
# For each scenario in check-prompt.md:
#   1. Read its evidence_pattern and mutation_target
#   2. Create a temp copy of WORKFLOW.md with mutation_target REMOVED
#   3. Check if evidence_pattern still matches the mutated file
#      - If YES  → evidence_pattern survives mutation → scenario has no "bite" → FAIL
#      - If NO   → evidence_pattern is gone after mutation → scenario correctly detects
#                  the missing text → PASS
#
# Exit codes:
#   0 = all scenarios have bite (mutation testing passed)
#   1 = warnings (some scenarios trivially satisfied — review but non-blocking)
#   2 = one or more mutations survived → scenarios lack coverage → blocking
#
# Usage:
#   bash validate-scenarios.sh             # run all mutation tests
#   bash validate-scenarios.sh --verbose   # show each mutation result

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOW="$REPO_ROOT/WORKFLOW.md"

VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

# ── Counters ─────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
WARN=0
SKIP=0

# ── Helpers ──────────────────────────────────────────────────────────────────
log_pass() { echo "  PASS  [$1] $2"; ((PASS++)) || true; }
log_fail() { echo "  FAIL  [$1] $2"; ((FAIL++)) || true; }
log_warn() { echo "  WARN  [$1] $2"; ((WARN++)) || true; }
log_skip() { echo "  SKIP  [$1] $2"; ((SKIP++)) || true; }

# run_mutation <id> <evidence_pattern> <mutation_target>
#   Returns 0 (PASS) or 1 (FAIL).
run_mutation() {
  local id="$1"
  local pattern="$2"
  local target="$3"

  # First: verify evidence_pattern currently matches (sanity check)
  if ! grep -qE "$pattern" "$WORKFLOW" 2>/dev/null; then
    log_fail "$id" "Evidence pattern not found in WORKFLOW.md (scenario baseline broken)"
    return 1
  fi

  # Second: verify mutation_target exists in WORKFLOW.md
  if ! grep -qF "$target" "$WORKFLOW" 2>/dev/null; then
    log_warn "$id" "Mutation target not found in WORKFLOW.md — may have been reworded"
    return 0  # non-blocking: scenario still verified structurally
  fi

  # Third: apply mutation and recheck
  local tmp
  tmp=$(mktemp)
  grep -vF "$target" "$WORKFLOW" > "$tmp"

  if grep -qE "$pattern" "$tmp" 2>/dev/null; then
    # Pattern still matches after removing target → scenario has no bite
    log_fail "$id" "Evidence survives mutation — scenario provides no coverage for missing text"
    rm -f "$tmp"
    return 1
  else
    # Pattern gone → mutation correctly killed
    log_pass "$id" "Mutation killed (evidence correctly absent after removal)"
    [[ "$VERBOSE" -eq 1 ]] && echo "         Pattern : $pattern" && echo "         Removed : $target"
    rm -f "$tmp"
    return 0
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
echo "── validate-scenarios.sh — Scenario mutation tests ──────────────────────────"
echo ""
echo "Template: $WORKFLOW"
echo ""

if [[ ! -f "$WORKFLOW" ]]; then
  echo "  ERROR  WORKFLOW.md not found at: $WORKFLOW"
  exit 2
fi

# ─── ENTRY GATE ──────────────────────────────────────────────────────────────
echo "▶ Entry Gate"

run_mutation "EG-S01" \
  'return to the relevant phase' \
  'return to the relevant phase'

run_mutation "EG-S02" \
  'keep → item unchanged' \
  'item unchanged, continue gate.'

run_mutation "EG-S03" \
  'remove.*delete from Roadmap.*log removal in Change Log' \
  'delete from Roadmap + TRACKING.md, log removal in Change Log.'

run_mutation "EG-S04" \
  'does not approve.*identify concerns.*rework 0b-0d' \
  'User does not approve → identify concerns → rework 0b-0d → re-present.'

run_mutation "EG-S05" \
  '0 Must.*sprint is empty.*Present options' \
  'sprint is empty. Present options:'

run_mutation "EG-S06" \
  'should it be Should[?]' \
  'should it be Should?'

run_mutation "EG-S07" \
  'Check previous sprint.*Sprint Close completion|Sprint Close.*complete.*Change Log' \
  "Check previous sprint's Sprint Close completion:"

echo ""

# ─── CLOSE GATE ──────────────────────────────────────────────────────────────
echo "▶ Close Gate"

run_mutation "CG-S01" \
  'mandatory.*run before every Close Gate' \
  'run before every Close Gate'

run_mutation "CG-S02" \
  'ALL metrics are DEFERRED.*gate blocked' \
  'Guard: if ALL metrics are DEFERRED → gate blocked. At least one metric must PASS.'

run_mutation "CG-S03" \
  'MISSING/FAIL.*gate blocked' \
  'Rule: every row must be PASS or DEFERRED (with escalation). MISSING/FAIL → gate blocked.'

run_mutation "CG-S04" \
  'ALL of the following phases were explicitly completed' \
  'that ALL of the following phases were explicitly completed in this session:'

run_mutation "CG-S05" \
  'cannot be silently deferred' \
  'Any finding that touches the Critical Axis domain cannot be silently deferred.'

run_mutation "CG-S06" \
  'step 12d logs.*Entry Gate.*abbreviated.*Close Gate' \
  'step 12d logs "Entry Gate (abbreviated)" so Close Gate knows.'

echo ""

# ─── IMPLEMENTATION LOOP ─────────────────────────────────────────────────────
echo "▶ Implementation Loop"

run_mutation "IL-S01" \
  'Still failing after 3.*stop and present' \
  'Still failing after 3'

run_mutation "IL-S02" \
  'FAIL on previous item.*regression.*fix before writing' \
  'fix before writing any more code'

run_mutation "IL-S03" \
  'Max 3 attempts.*if still failing.*log visual gap' \
  'Max 3 attempts; if still failing: log visual gap in'

run_mutation "IL-S04" \
  'scope-outside fix.*immediately log|immediately log.*TRACKING.*Change Log' \
  'immediately log it in TRACKING.md §Change Log:'

run_mutation "IL-S05" \
  'Read the GUARDRAILS sections identified in Entry Gate Phase 1' \
  'Read the GUARDRAILS sections identified in Entry Gate Phase 1 step 4 (relevant to this task type)'

echo ""

# ─── MID-SPRINT ──────────────────────────────────────────────────────────────
echo "▶ Mid-Sprint"

run_mutation "MS-S01" \
  'AI never initiates scope changes unilaterally' \
  'User requests scope change (AI never initiates scope changes unilaterally)'

run_mutation "MS-S02" \
  'hotfix outside sprint scope' \
  'Add as hotfix outside sprint scope'

echo ""

# ─── SPRINT ABORT ────────────────────────────────────────────────────────────
echo "▶ Sprint Abort"

run_mutation "SA-S01" \
  'User requests abort.*AI never initiates abort' \
  '1. User requests abort (AI never initiates abort)'

run_mutation "SA-S02" \
  'abort.*failure.*[Vv]erified work persists|abort.*not.*failure' \
  'Rule: abort ≠ failure. Verified work persists, unfinished work is deferred, not deleted.'

echo ""

# ─── SESSION RECOVERY ────────────────────────────────────────────────────────
echo "▶ Session Recovery"

run_mutation "SR-S01" \
  'Mid-sprint.*in_progress.*resume from TRACKING\.md' \
  '   b. Mid-sprint (in_progress or open items exist) → resume from TRACKING.md'

echo ""

# ─── RETROACTIVE SPRINT AUDIT ────────────────────────────────────────────────
echo "▶ Retroactive Sprint Audit"

run_mutation "RA-S01" \
  'never opens an audit unilaterally.*proposes.*user confirms' \
  'AI never opens an audit unilaterally — it proposes; the user confirms.'

run_mutation "RA-S02" \
  'never silently dismisses a detection signal' \
  'AI never silently dismisses a detection signal — if signal fires, it must surface it.'

echo ""

# ─── CONTRACT REVISION ───────────────────────────────────────────────────────
echo "▶ Contract Revision"

run_mutation "CR-S01" \
  'AI never initiates contract revision unprompted' \
  'AI never initiates contract revision unprompted.'

echo ""

# ─── SCOPE NEGOTIATION ───────────────────────────────────────────────────────
echo "▶ Scope Negotiation"

run_mutation "SN-S01" \
  'Never silently drop features' \
  'Never silently drop features — always show where they went.'

echo ""

# ─── PERFORMANCE BASELINE ────────────────────────────────────────────────────
echo "▶ Performance Baseline"

run_mutation "PB-S01" \
  'Do not invent fake baselines' \
  'Do not invent fake baselines.'

echo ""

# ─── GUARDRAIL UPDATE ────────────────────────────────────────────────────────
echo "▶ Guardrail Update"

run_mutation "GU-S01" \
  'present proposed rule to user' \
  'Before adding: present proposed rule to user'

run_mutation "GU-S02" \
  'Update sprint-audit.sh if pattern is grep-detectable' \
  '6. Update sprint-audit.sh if pattern is grep-detectable'

echo ""

# ─── ARCHITECTURE REVIEW ─────────────────────────────────────────────────────
echo "▶ Architecture Review"

run_mutation "AR-S01" \
  'Same category 2\+ times in last 3 sprints.*flag.*Architecture Review Required' \
  'Same category 2+ times in last 3 sprints → flag "Architecture Review Required" at next Entry Gate'

echo ""

# ─── FAILURE MODE HISTORY ────────────────────────────────────────────────────
echo "▶ Failure Mode History"

run_mutation "FM-S01" \
  'failure modes in 3 categories' \
  'list known failure modes in 3 categories:'

echo ""

# ─── Session Boundary ────────────────────────────────────────────────────────
echo "▶ Session Boundary"

run_mutation "SB-S01" \
  'AI MUST recommend starting a new session' \
  'AI MUST recommend starting a new session for implementation ("Continue sprint N").'

echo ""

# ─── Implementation Loop (continued) ─────────────────────────────────────────
echo "▶ Implementation Loop (Close Gate initiation)"

run_mutation "IL-S06" \
  'Close Gate is always user-initiated.*AI does not ask' \
  'Close Gate is always user-initiated — AI does not ask "shall we close?" unprompted.'

echo ""

# ─── Close Gate ───────────────────────────────────────────────────────────────
echo "▶ Close Gate (blocking escalation)"

run_mutation "CG-S07" \
  'automatically a blocker' \
  'the gap is automatically a blocker. It must be resolved before the current sprint'"'"'s Close Gate.'

echo ""

# ─── Entry Gate (Bootstrap) ───────────────────────────────────────────────────
echo "▶ Entry Gate (VCS=none fallback)"

run_mutation "EG-S08" \
  'VCS=none.*Phase 1b|Phase 1b uses Entry Gate notes' \
  'If VCS=none: skip Q11 (commit style); Phase 1b uses Entry Gate notes'

echo ""

# ─── Sprint Close ─────────────────────────────────────────────────────────────
echo "▶ Sprint Close"

run_mutation "SC-S01" \
  'Transfer rows to TRACKING.*Failure Mode History' \
  'Transfer rows to TRACKING.md §Failure Mode History (include Detection column:'

run_mutation "SC-S02" \
  'Delete.*ENTRY_GATE' \
  'its purpose (sprint-scoped reference) is fulfilled.'

run_mutation "SC-S03" \
  'Verified items older than 3 sprints.*sprint-board-archive' \
  'Verified items older than 3 sprints → archive to Docs/Archive/sprint-board-archive.md.'

run_mutation "SC-S04" \
  'Keep last 5 sprints.*baseline-archive' \
  'Keep last 5 sprints. Older rows → Docs/Archive/baseline-archive.md.'

run_mutation "SC-S05" \
  'archive completed sprint sections older than 1 sprint' \
  'archive completed sprint sections older than 1 sprint'

echo ""

# ─── Sprint Abort (continued) ─────────────────────────────────────────────
echo "▶ Sprint Abort (abbreviated close)"

run_mutation "SA-S03" \
  'Skip steps 5, 7-12, 14, and 15' \
  'Skip steps 5, 7-12, 14, and 15'

echo ""

# ─── Performance Baseline (continued) ────────────────────────────────────
echo "▶ Performance Baseline (column optimization)"

run_mutation "PB-S02" \
  'Deltas are derived on demand' \
  'Deltas are derived on demand from adjacent rows.'

echo ""

# ─── Audit Signal ─────────────────────────────────────────────────────────────
echo "▶ Audit Signal"

run_mutation "AS-S01" \
  'Surface it to the user immediately using.*AUDIT SIGNAL' \
  'Surface it to the user immediately using the ⚠ AUDIT SIGNAL format'

run_mutation "AS-S02" \
  'dismissed twice.*not re-surfaced' \
  'A signal dismissed twice for the same system is not re-surfaced unless a new trigger fires.'

echo ""

# ─── Implementation Loop (D.6 test run) ──────────────────────────────────────
echo "▶ Implementation Loop (D.6 incremental test run)"

run_mutation "IL-S07" \
  'Run ALL tests written so far — current item' \
  'Run ALL tests written so far — current item + all previous items in this sprint:'

echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN + SKIP))
echo "── Results ──────────────────────────────────────────────────────────────────"
echo "   $TOTAL scenarios:  $PASS PASS  $FAIL FAIL  $WARN WARN  $SKIP SKIP"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "  FAIL scenarios above indicate that removing that text from WORKFLOW.md"
  echo "  would NOT be detected — the scenario provides false coverage."
  echo "  Fix: tighten the evidence_pattern or choose a more specific mutation_target."
  echo ""
  exit 2
fi

if [[ "$WARN" -gt 0 ]]; then
  echo "  WARN: some mutation targets were not found in WORKFLOW.md."
  echo "  This may indicate WORKFLOW.md was reworded. Update mutation_target in"
  echo "  validation/scenarios/check-prompt.md to match current text."
  echo ""
  exit 1
fi

echo "  All scenarios have bite — every evidence pattern is tied to specific text"
echo "  whose removal would be detected."
echo ""
exit 0
