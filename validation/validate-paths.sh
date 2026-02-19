#!/usr/bin/env bash
# validate-paths.sh — Path simulation for workflow definition.
#
# Verifies that all major workflow paths (decision points, branches, recovery flows)
# are fully specified in WORKFLOW.md. Each scenario extracts a specific section
# and checks that required branch/path text exists within that section.
#
# Usage:
#   ./validate-paths.sh              # Run all scenario checks
#   ./validate-paths.sh --self-test  # Run negative tests (verify checks catch gaps)
#
# Exit codes:
#   0 = All checks pass
#   1 = Warnings exist (non-blocking)
#   2 = Failures exist (blocking)
#
# Dependencies: GNU bash 4+, grep -E, sed, mktemp
# Section boundaries use same-level headings (^## ), never --- delimiters.

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW="$REPO_ROOT/WORKFLOW.md"
ROADMAP="$REPO_ROOT/ROADMAP-DESIGN-PROMPT.md"

passes=0
warnings=0
failures=0

pass() {
  local name="$1"
  echo "  PASS  [$name]"
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

# Extract lines between two same-level heading patterns.
# Usage: extract_section FILE START_REGEX STOP_REGEX
# Returns lines from (including) START_REGEX up to (excluding) STOP_REGEX.
extract_section() {
  local file="$1" start="$2" stop="$3"
  sed -n "/${start}/,/${stop}/p" "$file" 2>/dev/null | sed "\$d"
}

# Core check: verify a pattern exists within a specific section.
# Usage: section_check CHECK_NAME SECTION_TEXT PATTERN DESCRIPTION
section_check() {
  local name="$1" section="$2" pattern="$3" desc="$4"
  if [[ -z "$section" ]]; then
    fail "$name" "Could not extract section (format changed?)"
    return
  fi
  if echo "$section" | grep -qE "$pattern"; then
    pass "$name"
  else
    fail "$name" "$desc"
  fi
}

# Check: verify a pattern exists anywhere in a file.
# Usage: file_check CHECK_NAME FILE PATTERN DESCRIPTION
file_check() {
  local name="$1" file="$2" pattern="$3" desc="$4"
  if [[ ! -f "$file" ]]; then
    fail "$name" "File not found: $file"
    return
  fi
  if grep -qE "$pattern" "$file"; then
    pass "$name"
  else
    fail "$name" "$desc"
  fi
}

# ── Pre-flight ──────────────────────────────────────────────
preflight_ok=true
for f in "$WORKFLOW" "$ROADMAP"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR  Required file not found: $f"
    preflight_ok=false
  fi
done
$preflight_ok || exit 2

# Check for --self-test mode
SELF_TEST=false
if [[ "${1:-}" == "--self-test" ]]; then
  SELF_TEST=true
fi

if $SELF_TEST; then
  echo "Running self-test (negative tests)..."
  echo "Using temp copy — real WORKFLOW.md is never modified."
  echo ""
else
  echo "Validating workflow paths..."
  echo "  WORKFLOW: $WORKFLOW"
  echo ""
fi

# ── Extract all major sections once ─────────────────────────

# Use the active WORKFLOW.md (real or temp copy, set later for self-test)
ACTIVE_WORKFLOW="$WORKFLOW"

run_checks() {
  local tmpl="$ACTIVE_WORKFLOW"
  passes=0; warnings=0; failures=0

  local eg_section cg_section sc_section
  local scope_section abort_section contract_section
  local session_section state_section
  local update_section

  eg_section=$(extract_section "$tmpl" "^## Entry Gate" "^## Close Gate")
  cg_section=$(extract_section "$tmpl" "^## Close Gate" "^## Sprint Close")
  sc_section=$(extract_section "$tmpl" "^## Sprint Close" "^## Anti-Pattern")
  scope_section=$(extract_section "$tmpl" "^### Mid-Sprint Scope Change" "^### Scope Negotiation")
  abort_section=$(extract_section "$tmpl" "^### Sprint Abort" "^### Roadmap")
  contract_section=$(extract_section "$tmpl" "^### Immutable Contract Revision" "^### Sprint Abort")
  session_section=$(extract_section "$tmpl" "^### Session Start Protocol" "^### During Implementation")
  state_section=$(extract_section "$tmpl" "^## State Transitions" "^## Checklist")
  update_section=$(extract_section "$tmpl" "^## Update Rule" "^### Mid-Sprint")

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 1: Happy Path — all major sections exist
  # ═══════════════════════════════════════════════════════════
  echo "── SCENARIO 1: Happy Path (major sections exist) ──"

  section_check "S1_ENTRY_GATE" "$eg_section" "Phase 0|Phase 1|Phase 2|Phase 3" \
    "Entry Gate section missing phase structure"

  section_check "S1_CLOSE_GATE" "$cg_section" "Phase 0|Phase 1a|Phase 1b|Phase 2|Phase 3|Phase 4" \
    "Close Gate section missing phase structure"

  section_check "S1_SPRINT_CLOSE" "$sc_section" "^1\. |^2\. |^3\. " \
    "Sprint Close section missing numbered steps"

  section_check "S1_IMPL_LOOP" \
    "$(extract_section "$tmpl" "^## Implementation Loop" "^---")" \
    "Pre-code check|Write code|Self-verify|Write tests|Update TRACKING" \
    "Implementation loop missing A-E steps"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 2: Entry Gate Rejection + Rework
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 2: Entry Gate Rejection ──"

  section_check "S2_STEP12E_REJECT" "$eg_section" \
    "does not approve.*return to" \
    "Entry Gate step 12e missing rejection path (GAP 1)"

  section_check "S2_PHASE0E_REJECT" "$eg_section" \
    "0e.*does not approve|does not approve.*rework 0b" \
    "Entry Gate Phase 0 step 0e missing rejection path (GAP 2)"

  section_check "S2_ABORT_FALLBACK" "$eg_section" \
    "Sprint Abort" \
    "Entry Gate rejection does not reference Sprint Abort as fallback"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 3: Close Gate DEFERRED Metrics
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 3: DEFERRED Metrics ──"

  section_check "S3_DEFERRED_ESCALATION" "$cg_section" \
    "DEFERRED.*escalation|escalation.*DEFERRED" \
    "Close Gate missing DEFERRED escalation procedure"

  section_check "S3_ALL_DEFERRED_GUARD" "$cg_section" \
    "[Aa]ll metrics are DEFERRED|ALL metrics.*DEFERRED.*blocked" \
    "Close Gate missing all-DEFERRED guard (GAP 3)"

  section_check "S3_PRESENT_TABLE" "$cg_section" \
    "[Pp]resent.*table to user|[Pp]resent completed table" \
    "Close Gate missing mandatory table presentation to user"

  section_check "S3_COMPACT_LOG" "$cg_section" \
    "compact summary|one-line summary" \
    "Close Gate missing compact TRACKING.md logging instruction"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 4: Sprint Abort
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 4: Sprint Abort ──"

  section_check "S4_USER_INITIATES" "$abort_section" \
    "[Uu]ser requests abort" \
    "Sprint Abort missing user-initiation rule"

  section_check "S4_DEFERRED_ITEMS" "$abort_section" \
    "deferred|non-verified.*deferred|unfinished.*deferred" \
    "Sprint Abort missing deferred item handling"

  section_check "S4_VERIFIED_PRESERVED" "$abort_section" \
    "[Vv]erified.*keep|[Vv]erified.*not lost|[Vv]erified items keep" \
    "Sprint Abort missing verified item preservation"

  section_check "S4_ABBREVIATED_CLOSE" "$abort_section" \
    "steps 1-4.*step 9|abbreviated Sprint Close" \
    "Sprint Abort missing abbreviated Sprint Close reference"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 5: Mid-Sprint Scope Change + Regression
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 5: Scope Change + Regression ──"

  section_check "S5_USER_INITIATES" "$scope_section" \
    "[Uu]ser requests scope change|AI never initiates" \
    "Scope Change missing user-initiation rule"

  section_check "S5_REGRESSION" "$scope_section" \
    "invalidate.*verified|regression|verified.*open" \
    "Scope Change missing regression handling"

  section_check "S5_HOTFIX_TRACKING" "$scope_section" \
    "[Hh]otfix.*requires|[Hh]otfix.*Change Log|[Hh]otfix.*retrospective" \
    "Scope Change hotfix missing tracking requirements (GAP 4)"

  section_check "S5_STATE_VERIFIED_OPEN" "$state_section" \
    "verified.*open|regression found" \
    "State Transitions missing verified→open regression path"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 6: Architecture Review Trigger
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 6: Architecture Review ──"

  section_check "S6_TRIGGER" "$eg_section" \
    "category.*2.*times|Same category 2+" \
    "Entry Gate 9a missing Architecture Review trigger condition"

  section_check "S6_PROCEDURE" "$eg_section" \
    "Identify the recurring category|Trace root causes" \
    "Entry Gate 9a missing Architecture Review procedure steps"

  section_check "S6_USER_DECIDES" "$eg_section" \
    "fix now.*defer|[Uu]ser decides.*fix.*defer" \
    "Architecture Review missing user decision (fix now or defer)"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 7: Unpredicted Failure → Update Rule
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 7: Update Rule ──"

  section_check "S7_UNPREDICTED_TRIGGER" "$sc_section" \
    "[Uu]npredicted.*guardrail|[Uu]npredicted.*Update Rule" \
    "Sprint Close step 7 missing unpredicted failure → guardrail link"

  section_check "S7_DEDUP_CHECK" "$update_section" \
    "LESSONS_INDEX|already exist|dedup|rule.*already" \
    "Update Rule missing dedup check against LESSONS_INDEX"

  section_check "S7_RULE_CHAIN" "$update_section" \
    "root cause|anti-pattern|sprint-audit|LESSONS_INDEX" \
    "Update Rule missing multi-step chain"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 8: Session Recovery
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 8: Session Recovery ──"

  section_check "S8_THREE_MODES" "$session_section" \
    "a\..*[Nn]ew sprint|b\..*[Mm]id-sprint|c\..*[Ii]nterrupted" \
    "Session Start missing 3 modes (new/mid-sprint/interrupted)"

  section_check "S8_IN_PROGRESS_VERIFY" "$session_section" \
    "in_progress.*verify|verify.*code state" \
    "Session Start missing in_progress item verification for interrupted sessions"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 9: Close Gate Exit Code Handling
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 9: Audit Exit Code Handling ──"

  section_check "S9_EXIT_0" "$cg_section" \
    "[Ee]xit code 0.*clean|[Ee]xit code 0.*proceed" \
    "Close Gate Phase 1a missing exit code 0 (clean) path"

  section_check "S9_EXIT_1" "$cg_section" \
    "[Ee]xit code 1.*findings|[Ee]xit code 1.*review" \
    "Close Gate Phase 1a missing exit code 1 (findings) path"

  section_check "S9_EXIT_2" "$cg_section" \
    "[Ee]xit code 2.*setup|[Ee]xit code 2.*fix" \
    "Close Gate Phase 1a missing exit code 2 (setup error) path"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 10: Immutable Contract Revision
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 10: Contract Revision ──"

  section_check "S10_USER_TRIGGER" "$contract_section" \
    "[Uu]ser explicitly requests|AI never initiates" \
    "Contract Revision missing user-initiation rule"

  section_check "S10_BLAST_RADIUS" "$contract_section" \
    "blast radius" \
    "Contract Revision missing blast radius assessment"

  section_check "S10_REGRESSION" "$contract_section" \
    "verified.*open|regression" \
    "Contract Revision missing verified→open regression handling"

  section_check "S10_GUARDRAIL_UPDATE" "$contract_section" \
    "guardrail.*update|guardrail.*remove|[Aa]ffected guardrail" \
    "Contract Revision missing guardrail rule update step"

  # ═══════════════════════════════════════════════════════════
  #  BONUS: Gap fix completeness checks
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── Gap Fix Completeness ──"

  # GAP 5: Step 8 outcome mechanics
  section_check "GAP5_STEP8_MECHANICS" "$eg_section" \
    "keep.*item unchanged|modify.*update.*Roadmap|defer.*deferred|remove.*delete" \
    "Entry Gate step 8 missing user response mechanics (GAP 5)"

  # GAP 6: Section replacement at Entry Gate
  section_check "GAP6_SECTION_CLEAR" "$eg_section" \
    "Clear.*Predicted Failure|Clear.*Failure Encounters|replace previous sprint" \
    "Entry Gate Phase 1 missing section replacement instruction (GAP 6)"

  # State diagram: open→blocked
  section_check "STATE_OPEN_BLOCKED" "$state_section" \
    "► blocked|→ blocked|open.*blocked" \
    "State Transitions missing open→blocked path"

  # State diagram: fixed→in_progress (rework)
  section_check "STATE_FIXED_REWORK" "$state_section" \
    "fixed.*in_progress|rework.*before verification|re-fix cycle" \
    "State Transitions missing fixed→in_progress rework path"

  # State diagram: sprint aborted state
  section_check "STATE_SPRINT_ABORT" "$state_section" \
    "aborted|abort" \
    "Sprint Lifecycle missing aborted state"

  # State diagram: done→next sprint
  section_check "STATE_DONE_NEXT" "$state_section" \
    "next sprint|done.*planned" \
    "Sprint Lifecycle missing done→planned transition"

  # ═══════════════════════════════════════════════════════════
  #  SCENARIO 11: Design-First Path (ROADMAP-DESIGN-PROMPT.md)
  # ═══════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 11: Design-First Path ──"

  # WORKFLOW.md step 4 has the design-first skip alternative
  file_check "S11_STEP4_SKIP" "$tmpl" \
    "design-first alternative|skip this step entirely" \
    "WORKFLOW.md step 4 missing design-first alternative (skip when Roadmap.md exists)"

  # WORKFLOW.md bootstrap detects existing Roadmap.md and skips Initial Planning
  file_check "S11_ROADMAP_DETECT" "$tmpl" \
    "Roadmap\.md already exists|skip Initial Planning" \
    "WORKFLOW.md missing bootstrap detection of existing Roadmap.md → skip step 4"

  # WORKFLOW.md step 5 feeds Non-Negotiable Contracts from Roadmap.md into CLAUDE.md
  file_check "S11_CONTRACT_FEED" "$tmpl" \
    "Non-Negotiable Contracts.*CLAUDE|read Roadmap.*§Non-Negotiable" \
    "WORKFLOW.md step 5 missing design-first contract feed into CLAUDE.md"

  # ROADMAP-DESIGN-PROMPT.md usage flow references WORKFLOW.md bootstrap step
  file_check "S11_USAGE_FLOW" "$ROADMAP" \
    "WORKFLOW.md.*bootstrap|bootstrap.*WORKFLOW.md" \
    "ROADMAP-DESIGN-PROMPT.md usage flow missing link to WORKFLOW.md bootstrap"

  # ═══════════════════════════════════════════════════════════════
  #  SCENARIO 12: Workflow Integrity — Recurring Bug Categories
  # ═══════════════════════════════════════════════════════════════
  echo ""
  echo "── SCENARIO 12: Workflow Integrity ──"

  # CP1 must reference Phase 1 step 3 (not "step 6" which is API contract review)
  file_check "CP1_STEP_REF" "$tmpl" \
    "Checkpoint 1.*Phase 1 step 3|CP1.*Phase 1 step 3" \
    "CP1 label must reference Phase 1 step 3 (not step 6 — step 6 is API contract review)"

  # Abbreviated mode must include section-clearing step after step 2 (Fix B side effect)
  section_check "ABBREVIATED_CLEARS" "$eg_section" \
    "abbreviated only.*[Cc]lear|After step 2.*abbreviated" \
    "Abbreviated Entry Gate missing clearing step for Predicted Failure Modes after step 2"

  # TRACKING.md template must contain Performance Baseline Log section
  file_check "PERF_BASELINE_TMPL" "$tmpl" \
    "Performance Baseline Log" \
    "TRACKING.md template missing §Performance Baseline Log (read by CP1, written by Sprint Close step 5)"

  # Session Start step 4a must NOT auto-start Entry Gate (user-initiated principle)
  section_check "ENTRY_GATE_INITIATED" "$session_section" \
    "Do NOT begin Entry Gate|inform user.*Entry Gate.*wait" \
    "Session Start Protocol step 4a must state Entry Gate is user-initiated (not auto-start)"

  # Session Start step 4d must NOT auto-suggest Close Gate (user-initiated principle)
  section_check "CLOSE_GATE_INITIATED" "$session_section" \
    "Do NOT suggest Close Gate" \
    "Session Start Protocol step 4d must prohibit unprompted Close Gate suggestion"

  # Entry Gate Phase 1 Step 0: Sprint Close completion check before proceeding
  section_check "SPRINT_CLOSE_CHECK" "$eg_section" \
    "Check previous sprint.*Sprint Close|Sprint Close.*complete.*Change Log|Change Log.*Sprint Close.*complete" \
    "Entry Gate Phase 1 missing Sprint Close completion check (Step 0)"

  # Implementation Loop B: side fix logging rule
  file_check "SIDE_FIX_LOGGING" "$tmpl" \
    "Side fix:.*Change Log|scope-outside fix|scope.outside fix" \
    "Implementation Loop B missing side fix logging rule"

  # Implementation Loop A: guardrails must be read before writing code
  file_check "GUARDRAIL_READ_BEFORE_CODE" "$tmpl" \
    "Read the GUARDRAILS sections identified in Entry Gate Phase 1" \
    "Implementation Loop A missing guardrail read step before writing code"

  # Session boundary: AI MUST recommend new session after Entry Gate (and before Close Gate)
  file_check "SESSION_BOUNDARY_MANDATORY" "$tmpl" \
    "AI MUST recommend starting a new session" \
    "Workflow missing mandatory session boundary recommendation (Entry Gate → impl, impl → Close Gate)"

  # Implementation Loop: Close Gate is user-initiated — AI must NOT suggest it unprompted
  file_check "CLOSE_GATE_UNPROMPTED" "$tmpl" \
    "Close Gate is always user-initiated.*AI does not ask" \
    "Implementation Loop missing explicit constraint: AI must not suggest Close Gate unprompted"

  # Close Gate verdict: pre-verdict guard checklist is mandatory before issuing any recommendation
  file_check "PREVERDICT_GUARD" "$tmpl" \
    "Pre-verdict guard.*mandatory" \
    "Close Gate missing pre-verdict guard (mandatory phase checklist before issuing verdict)"

  # Retroactive audit: REGRESSION/INTEGRATION_GAP affecting Must item → automatic blocker
  file_check "BLOCKING_ESCALATION" "$tmpl" \
    "automatically a blocker" \
    "Retroactive audit missing blocking escalation rule (REGRESSION/INTEGRATION_GAP → Must item blocker)"

  # Bootstrap Q8: VCS=none → Phase 1b falls back to Entry Gate notes
  file_check "VCS_NONE_FALLBACK" "$tmpl" \
    "VCS=none.*Phase 1b|Phase 1b uses Entry Gate notes" \
    "Bootstrap section missing VCS=none fallback for Phase 1b (no git diff available)"

  # Sprint Close step 7d: Failure Encounters rows must be transferred to Failure Mode History
  file_check "FAILURE_HISTORY_TRANSFER" "$tmpl" \
    "Transfer rows to TRACKING.*Failure Mode History" \
    "Sprint Close step 7d missing explicit transfer of Failure Encounters to Failure Mode History"

  # Audit signal: AI MUST surface to user immediately — cannot silently continue
  file_check "AUDIT_SIGNAL_MANDATORY" "$tmpl" \
    "Surface it to the user immediately using.*AUDIT SIGNAL" \
    "Audit signal section missing mandatory surface obligation (AI must not silently continue)"

  # Sprint Close step 7: Entry Gate report file must be deleted after sprint closes
  file_check "ENTRY_GATE_REPORT_DELETE" "$tmpl" \
    "Delete.*ENTRY_GATE" \
    "Sprint Close missing Entry Gate report deletion step (S<N>_ENTRY_GATE.md is temporary)"

  # Audit signal: a signal dismissed twice is not re-surfaced without a new trigger
  file_check "DISMISSED_SIGNAL_THRESHOLD" "$tmpl" \
    "dismissed twice.*not re-surfaced" \
    "Audit signal section missing dismissed-twice suppression threshold rule"

  # Implementation Loop D.6: incremental test run after each item (catches regressions early)
  file_check "IMPL_LOOP_TEST_RUN" "$tmpl" \
    "Run ALL tests written so far — current item" \
    "Implementation Loop D.6 missing incremental test run instruction (run all tests after each item)"
}

# ═══════════════════════════════════════════════════════════════
#  MAIN: Normal mode or self-test
# ═══════════════════════════════════════════════════════════════

if ! $SELF_TEST; then
  # Normal mode: run checks against real WORKFLOW.md
  run_checks
else
  # Self-test mode: verify that removing each GAP fix causes the corresponding check to FAIL.
  # CRITICAL: Never modify the real WORKFLOW.md. Use a temp copy with trap cleanup.
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  # Define GAP fix tests using parallel arrays.
  # Patterns may contain | for regex alternation, so a simple delimiter won't work.
  declare -a gap_names=(
    "GAP1_REMOVAL"
    "GAP2_REMOVAL"
    "GAP3_REMOVAL"
    "GAP4_REMOVAL"
    "GAP5_REMOVAL"
    "GAP6_REMOVAL"
    "STATE_REMOVAL"
    "GAP_S6_TRIGGER"
    "GAP_S8_MODES"
    "GAP_S9_EXIT"
    "GAP_S10_CONTRACT"
    "GAP_S11_DESIGNFIRST"
    "CP1_STEP_REF_REMOVAL"
    "ABBREV_CLEARS_REMOVAL"
    "PERF_BASELINE_REMOVAL"
    "ENTRY_INITIATED_REMOVAL"
    "CLOSE_INITIATED_REMOVAL"
    "SPRINT_CLOSE_CHECK_REMOVAL"
    "SIDE_FIX_LOGGING_REMOVAL"
    "GUARDRAIL_READ_BEFORE_CODE_REMOVAL"
    "SESSION_BOUNDARY_REMOVAL"
    "CLOSE_GATE_UNPROMPTED_REMOVAL"
    "PREVERDICT_GUARD_REMOVAL"
    "BLOCKING_ESCALATION_REMOVAL"
    "VCS_NONE_FALLBACK_REMOVAL"
    "FAILURE_HISTORY_TRANSFER_REMOVAL"
    "AUDIT_SIGNAL_MANDATORY_REMOVAL"
    "ENTRY_GATE_REPORT_DELETE_REMOVAL"
    "DISMISSED_SIGNAL_THRESHOLD_REMOVAL"
    "IMPL_LOOP_TEST_RUN_REMOVAL"
  )
  declare -a gap_patterns=(
    "does not approve.*return to"
    "0e.*does not approve|does not approve.*rework 0b"
    "[Aa][Ll][Ll] metrics.*DEFERRED"
    "Hotfix still requires"
    "keep.*item unchanged|modify.*update.*Roadmap|defer.*deferred|remove.*delete"
    "Clear.*Predicted Failure|Clear.*Failure Encounters|replace previous sprint"
    "re-fix cycle"
    "Same category 2"
    "[Nn]ew sprint|[Mm]id-sprint|[Ii]nterrupted session"
    "[Ee]xit code 0.*clean|[Ee]xit code 0.*proceed"
    "blast radius"
    "design-first alternative|skip this step entirely"
    "Checkpoint 1.*Phase 1 step 3|CP1.*Phase 1 step 3"
    "abbreviated only.*[Cc]lear|After step 2.*abbreviated"
    "Performance Baseline Log"
    "Do NOT begin Entry Gate"
    "Do NOT suggest Close Gate"
    "Check previous sprint.*Sprint Close|Sprint Close.*complete.*Change Log|Change Log.*Sprint Close.*complete"
    "Side fix:.*Change Log|scope-outside fix|scope.outside fix"
    "Read the GUARDRAILS sections identified in Entry Gate Phase 1"
    "AI MUST recommend starting a new session for implementation"
    "Close Gate is always user-initiated — AI does not ask"
    "Pre-verdict guard \\(mandatory\\)"
    "automatically a blocker"
    "Phase 1b uses Entry Gate notes"
    "Transfer rows to TRACKING.md §Failure Mode History"
    "Surface it to the user immediately using the"
    "Delete.*ENTRY_GATE"
    "dismissed twice.*not re-surfaced"
    "Run ALL tests written so far — current item"
  )
  declare -a gap_expected=(
    "S2_STEP12E_REJECT"
    "S2_PHASE0E_REJECT"
    "S3_ALL_DEFERRED_GUARD"
    "S5_HOTFIX_TRACKING"
    "GAP5_STEP8_MECHANICS"
    "GAP6_SECTION_CLEAR"
    "STATE_FIXED_REWORK"
    "S6_TRIGGER"
    "S8_THREE_MODES"
    "S9_EXIT_0"
    "S10_BLAST_RADIUS"
    "S11_STEP4_SKIP"
    "CP1_STEP_REF"
    "ABBREVIATED_CLEARS"
    "PERF_BASELINE_TMPL"
    "ENTRY_GATE_INITIATED"
    "CLOSE_GATE_INITIATED"
    "SPRINT_CLOSE_CHECK"
    "SIDE_FIX_LOGGING"
    "GUARDRAIL_READ_BEFORE_CODE"
    "SESSION_BOUNDARY_MANDATORY"
    "CLOSE_GATE_UNPROMPTED"
    "PREVERDICT_GUARD"
    "BLOCKING_ESCALATION"
    "VCS_NONE_FALLBACK"
    "FAILURE_HISTORY_TRANSFER"
    "AUDIT_SIGNAL_MANDATORY"
    "ENTRY_GATE_REPORT_DELETE"
    "DISMISSED_SIGNAL_THRESHOLD"
    "IMPL_LOOP_TEST_RUN"
  )

  self_test_pass=0
  self_test_fail=0

  for i in "${!gap_names[@]}"; do
    test_name="${gap_names[$i]}"
    remove_pattern="${gap_patterns[$i]}"
    expected_check="${gap_expected[$i]}"

    echo "── Self-test: $test_name ──"

    # Create a temp copy with the GAP fix text removed
    tmp_file="$tmp_dir/WORKFLOW.md"
    grep -vE "$remove_pattern" "$WORKFLOW" > "$tmp_file" 2>/dev/null || cp "$WORKFLOW" "$tmp_file"

    # Run checks against the modified copy (capture output)
    ACTIVE_WORKFLOW="$tmp_file"
    output=$(run_checks 2>&1)

    # Check if the expected check FAILed
    if echo "$output" | grep -q "FAIL.*$expected_check"; then
      echo "  PASS  Removing '$remove_pattern' correctly triggered FAIL on [$expected_check]"
      self_test_pass=$((self_test_pass + 1))
    else
      echo "  FAIL  Removing '$remove_pattern' did NOT trigger FAIL on [$expected_check]"
      echo "        (Check may be matching unrelated text — tighten the pattern)"
      self_test_fail=$((self_test_fail + 1))
    fi
    echo ""
  done

  # Reset to real template for summary
  ACTIVE_WORKFLOW="$WORKFLOW"

  echo "══════════════════════════════════════════════════════"
  echo "Self-test: $self_test_pass passed, $self_test_fail failed out of ${#gap_names[@]} tests."
  if [[ $self_test_fail -gt 0 ]]; then
    echo "Some checks did not detect gap removal — patterns may need tightening."
    exit 2
  else
    echo "All negative tests passed — checks correctly detect gap removals."
    exit 0
  fi
fi

# ═══════════════════════════════════════════════════════════════
#  SUMMARY (normal mode only)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
if [[ $failures -gt 0 ]]; then
  echo "Path validation: $passes passed, $warnings warning(s), $failures FAILURE(s)."
  echo "FAIL findings indicate missing workflow paths — fix in WORKFLOW.md."
  exit 2
elif [[ $warnings -gt 0 ]]; then
  echo "Path validation: $passes passed, $warnings warning(s), 0 failures."
  echo "WARN findings may indicate underspecified paths — review if needed."
  exit 1
else
  echo "Path validation CLEAN — $passes checks passed, 0 findings."
  exit 0
fi
