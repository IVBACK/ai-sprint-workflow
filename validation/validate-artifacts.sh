#!/usr/bin/env bash
# validate-artifacts.sh — Post-session artifact compliance check
#
# Tests whether TRACKING.md (and optionally CLAUDE.md, Roadmap.md) produced
# by an AI sprint session comply with the workflow protocol.
#
# This is NOT a structural check of WORKFLOW.md — it checks runtime artifacts
# from an actual sprint execution to catch protocol violations after the fact.
#
# Usage:
#   bash validate-artifacts.sh                        # uses ./TRACKING.md
#   bash validate-artifacts.sh --tracking path/to/TRACKING.md
#   bash validate-artifacts.sh --tracking T.md --claude CLAUDE.md --roadmap Roadmap.md
#
# Exit codes:
#   0 = clean (all checks pass)
#   1 = warnings (potential issues, non-blocking)
#   2 = violations (clear protocol breaches, blocking)

set -uo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
TRACKING=""
CLAUDE_MD=""
ROADMAP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tracking) TRACKING="$2"; shift 2 ;;
    --claude)   CLAUDE_MD="$2"; shift 2 ;;
    --roadmap)  ROADMAP="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

# Defaults
[[ -z "$TRACKING" ]] && TRACKING="TRACKING.md"
[[ -z "$CLAUDE_MD" && -f "CLAUDE.md" ]] && CLAUDE_MD="CLAUDE.md"
[[ -z "$ROADMAP" && -f "Docs/Planning/Roadmap.md" ]] && ROADMAP="Docs/Planning/Roadmap.md"

# ── Counters ─────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; WARN=0; INFO=0

log_pass() { echo "  PASS  [$1] $2"; ((PASS++)) || true; }
log_fail() { echo "  FAIL  [$1] $2"; ((FAIL++)) || true; }
log_warn() { echo "  WARN  [$1] $2"; ((WARN++)) || true; }
log_info() { echo "  INFO  [$1] $2"; ((INFO++)) || true; }

# ── Guards ────────────────────────────────────────────────────────────────────
echo "── validate-artifacts.sh — Runtime compliance check ─────────────────────────"
echo ""
echo "  TRACKING : $TRACKING"
[[ -n "$CLAUDE_MD" ]] && echo "  CLAUDE   : $CLAUDE_MD"
[[ -n "$ROADMAP"   ]] && echo "  ROADMAP  : $ROADMAP"
echo ""

if [[ ! -f "$TRACKING" ]]; then
  echo "  ERROR  TRACKING.md not found at: $TRACKING"
  echo "         Pass --tracking <path> to specify the file."
  exit 2
fi

TRACKING_TEXT=$(< "$TRACKING")

# ── CHECK GROUP 1: Required sections ─────────────────────────────────────────
echo "▶ Required sections"

check_section() {
  local id="$1" pattern="$2" label="$3"
  if echo "$TRACKING_TEXT" | grep -qE "$pattern"; then
    log_pass "$id" "$label section present"
  else
    log_fail "$id" "$label section missing — required by WORKFLOW.md"
  fi
}

check_section "ART-S01" '##?\s*Sprint Board|Sprint Board' "§Sprint Board"
check_section "ART-S02" '##?\s*Change Log|Change Log' "§Change Log"
check_section "ART-S03" '##?\s*(Predicted )?Failure Mode|Failure Mode History' "§Failure Mode History"
echo ""

# ── CHECK GROUP 2: Status value validity ─────────────────────────────────────
echo "▶ Item status values"

VALID_STATUSES="open|in_progress|fixed|verified|blocked|deferred|sprint_abort"

# Extract status values from TRACKING.md table rows (format: | ID | desc | status | ...)
# Looks for lines with CORE-### or similar IDs followed by pipe-separated columns
invalid_statuses=$(echo "$TRACKING_TEXT" | \
  grep -E '^\|[[:space:]]*(CORE|ITEM|TASK)-[0-9]+' | \
  awk -F'|' '{gsub(/[[:space:]]/,"",$4); print $4}' | \
  grep -vE "^($VALID_STATUSES)$" | grep -v '^$' || true)

if [[ -z "$invalid_statuses" ]]; then
  log_pass "ART-ST01" "All item status values are valid"
else
  while IFS= read -r status; do
    log_fail "ART-ST01" "Invalid status value: '$status' (valid: open/in_progress/fixed/verified/blocked/deferred/sprint_abort)"
  done <<< "$invalid_statuses"
fi
echo ""

# ── CHECK GROUP 3: Deferred items have reason + target sprint ─────────────────
echo "▶ Deferred item fields"

# Find rows with status=deferred
deferred_rows=$(echo "$TRACKING_TEXT" | grep -E '^\|[[:space:]]*(CORE|ITEM|TASK)-[0-9]+' | \
  awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); if($4=="deferred") print $0}' || true)

if [[ -z "$deferred_rows" ]]; then
  log_info "ART-DF00" "No deferred items found"
else
  deferred_count=$(echo "$deferred_rows" | wc -l | tr -d ' ')
  ok=0; missing=0
  while IFS= read -r row; do
    # Check for reason or target sprint reference (→ S<N> or reason: or S<N>)
    if echo "$row" | grep -qE 'reason:|→ S[0-9]+|target.*S[0-9]+|S[0-9]+'; then
      ((ok++)) || true
    else
      item=$(echo "$row" | awk -F'|' '{gsub(/[[:space:]]/,"",$2); print $2}')
      log_warn "ART-DF01" "Deferred item '$item' has no reason or target sprint — required by WORKFLOW.md"
      ((missing++)) || true
    fi
  done <<< "$deferred_rows"
  [[ "$ok" -gt 0 ]] && log_pass "ART-DF01" "$ok/$deferred_count deferred items have reason + target sprint"
fi
echo ""

# ── CHECK GROUP 4: Entry Gate log ─────────────────────────────────────────────
echo "▶ Gate execution logs"

if echo "$TRACKING_TEXT" | grep -qE 'Entry Gate.*[0-9]{4}|Entry Gate.*phases|Entry Gate.*steps executed'; then
  log_pass "ART-EG01" "Entry Gate log entry found in Change Log"
else
  log_warn "ART-EG01" "No Entry Gate log entry found — WORKFLOW.md requires logging after step 12d"
fi

# Check if Close Gate log exists (only warn if sprint has verified items,
# which implies sprint should be closed)
verified_count=$(echo "$TRACKING_TEXT" | \
  grep -E '^\|[[:space:]]*(CORE|ITEM|TASK)-[0-9]+' | \
  awk -F'|' '{gsub(/[[:space:]]/,"",$4); print $4}' | \
  grep -c "^verified$" || true)

if [[ "$verified_count" -gt 0 ]]; then
  if echo "$TRACKING_TEXT" | grep -qE 'Close Gate.*[0-9]{4}|Sprint closed|Sprint Close.*[0-9]{4}'; then
    log_pass "ART-CG01" "Close Gate log entry found ($verified_count verified items)"
  else
    log_warn "ART-CG01" "$verified_count verified items found but no Close Gate log — was Close Gate run?"
  fi
else
  log_info "ART-CG01" "No verified items — Close Gate log not expected yet"
fi
echo ""

# ── CHECK GROUP 5: Sprint abort compliance ────────────────────────────────────
echo "▶ Sprint abort compliance"

if echo "$TRACKING_TEXT" | grep -qE 'sprint.?abort|Sprint aborted|sprint_abort'; then
  # Abort was triggered — check that abort log exists in Change Log
  if echo "$TRACKING_TEXT" | grep -qiE 'Sprint aborted.*[Rr]eason|abort.*[Rr]eason.*[0-9]{4}'; then
    log_pass "ART-SA01" "Sprint abort log with reason found"
  else
    log_warn "ART-SA01" "Sprint abort detected but no log with reason/date found — WORKFLOW.md §Sprint Abort step 6 requires it"
  fi

  # Non-verified items should be deferred (not left open/in_progress)
  open_after_abort=$(echo "$TRACKING_TEXT" | \
    grep -E '^\|[[:space:]]*(CORE|ITEM|TASK)-[0-9]+' | \
    awk -F'|' '{gsub(/[[:space:]]/,"",$4); print $4}' | \
    grep -cE '^(open|in_progress|fixed)$' || true)
  if [[ "$open_after_abort" -gt 0 ]]; then
    log_warn "ART-SA02" "$open_after_abort items still open/in_progress after sprint abort — should be deferred"
  else
    log_pass "ART-SA02" "All non-verified items are deferred after sprint abort"
  fi
else
  log_info "ART-SA01" "No sprint abort detected"
fi
echo ""

# ── CHECK GROUP 6: CLAUDE.md checkpoint ──────────────────────────────────────
if [[ -n "$CLAUDE_MD" && -f "$CLAUDE_MD" ]]; then
  echo "▶ CLAUDE.md checkpoint"
  CLAUDE_TEXT=$(< "$CLAUDE_MD")

  if echo "$CLAUDE_TEXT" | grep -qE 'Last Checkpoint|LastCheckpoint'; then
    checkpoint=$(echo "$CLAUDE_TEXT" | grep -A1 -E 'Last Checkpoint|LastCheckpoint' | tail -1)
    if echo "$checkpoint" | grep -qE 'Entry Gate|Close Gate|Sprint [0-9]|Implementation'; then
      log_pass "ART-CP01" "§Last Checkpoint is set and references a workflow phase"
    else
      log_warn "ART-CP01" "§Last Checkpoint exists but content looks stale or vague: '$checkpoint'"
    fi
  else
    log_warn "ART-CP01" "§Last Checkpoint not found in CLAUDE.md — required after each gate"
  fi
  echo ""
fi

# ── CHECK GROUP 7: Roadmap / TRACKING sync ────────────────────────────────────
if [[ -n "$ROADMAP" && -f "$ROADMAP" ]]; then
  echo "▶ Roadmap ↔ TRACKING sync"
  ROADMAP_TEXT=$(< "$ROADMAP")

  # Items marked [x] in roadmap should be verified in TRACKING.md
  checked_items=$(echo "$ROADMAP_TEXT" | grep -oE '\[x\] (CORE|ITEM|TASK)-[0-9]+' | \
    grep -oE '(CORE|ITEM|TASK)-[0-9]+' || true)

  if [[ -z "$checked_items" ]]; then
    log_info "ART-RM01" "No [x] items in Roadmap to sync-check"
  else
    mismatch=0
    while IFS= read -r item_id; do
      status=$(echo "$TRACKING_TEXT" | grep -E "^\|[[:space:]]*${item_id}" | \
        awk -F'|' '{gsub(/[[:space:]]/,"",$4); print $4}' | head -1)
      if [[ "$status" != "verified" ]]; then
        log_warn "ART-RM01" "$item_id is [x] in Roadmap but status='${status:-not found}' in TRACKING.md"
        ((mismatch++)) || true
      fi
    done <<< "$checked_items"
    total=$(echo "$checked_items" | wc -l | tr -d ' ')
    ok=$((total - mismatch))
    [[ "$mismatch" -eq 0 ]] && log_pass "ART-RM01" "All $total [x] Roadmap items have status=verified in TRACKING.md"
  fi

  # Items marked [~] in roadmap should be deferred in TRACKING.md
  deferred_items=$(echo "$ROADMAP_TEXT" | grep -oE '\[~\] (CORE|ITEM|TASK)-[0-9]+' | \
    grep -oE '(CORE|ITEM|TASK)-[0-9]+' || true)

  if [[ -n "$deferred_items" ]]; then
    mismatch=0
    while IFS= read -r item_id; do
      status=$(echo "$TRACKING_TEXT" | grep -E "^\|[[:space:]]*${item_id}" | \
        awk -F'|' '{gsub(/[[:space:]]/,"",$4); print $4}' | head -1)
      if [[ "$status" != "deferred" ]]; then
        log_warn "ART-RM02" "$item_id is [~] in Roadmap but status='${status:-not found}' in TRACKING.md"
        ((mismatch++)) || true
      fi
    done <<< "$deferred_items"
    total=$(echo "$deferred_items" | wc -l | tr -d ' ')
    [[ "$mismatch" -eq 0 ]] && log_pass "ART-RM02" "All $total [~] Roadmap items have status=deferred in TRACKING.md"
  fi
  echo ""
fi

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN + INFO))
echo "── Results ──────────────────────────────────────────────────────────────────"
echo "   $TOTAL checks:  $PASS PASS  $FAIL FAIL  $WARN WARN  $INFO INFO"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "  FAIL items indicate clear protocol violations in the session artifacts."
  echo "  Review the AI session transcript and correct the artifacts."
  echo ""
  exit 2
fi

if [[ "$WARN" -gt 0 ]]; then
  echo "  WARN items may indicate skipped steps or missing documentation."
  echo "  Review before declaring the sprint complete."
  echo ""
  exit 1
fi

echo "  Artifact compliance CLEAN — no protocol violations detected."
echo ""
exit 0
