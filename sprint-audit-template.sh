#!/usr/bin/env bash
set -uo pipefail
# Note: -e is intentionally omitted. Individual check failures should not abort
# the entire audit. Each section handles its own errors with || true.

# sprint-audit.sh — Automated sprint close gate checks
#
# This is a TEMPLATE. Copy to your project's Tools/ directory and adapt
# the patterns to your language, framework, and project conventions.
#
# Usage:
#   Tools/sprint-audit.sh                       # Full scan
#
# Exit codes:
#   0 = Clean (0 findings)
#   1 = Findings exist (review needed, not necessarily failures)
#   2 = Setup error (fix script configuration before audit)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/src"         # ← adjust to your source directory
TEST_DIR="$ROOT/tests"      # ← adjust to your test directory
EXT="*"                     # ← adjust: "cs", "ts", "py", "java", "go", "rs", "cpp"

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

# ── Helper ──

check() {
  local name="$1" pattern="$2" dir="${3:-$SRC_DIR}"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP  [$name] — directory $dir not found"
    return
  fi
  local results count
  results=$(grep -rn "$pattern" --include="*.${EXT}" "$dir" 2>/dev/null || true)
  count=$(echo "$results" | grep -c . 2>/dev/null || echo 0)
  if [[ $count -gt 0 ]]; then
    echo ""
    echo "WARN  [$name] — $count finding(s):"
    echo "$results" | head -20
    [[ $count -gt 20 ]] && echo "  ... and $((count - 20)) more"
    total=$((total + count))
  else
    echo "PASS  [$name]"
  fi
}

# ═══════════════════════════════════════════════════════
# SECTION 1: Scaffolding tags
# Look for temporary markers that should be resolved
# ═══════════════════════════════════════════════════════

# Language-agnostic: search keywords without comment prefix.
# TODO/HACK/FIXME appear in comments regardless of style (// # <!-- --)
# TEMP(S matches the sprint-scoped scaffolding tag format: TEMP(S4)
check "SCAFFOLDING" "TODO\|HACK\|FIXME\|TEMP(S"

# ═══════════════════════════════════════════════════════
# SECTION 2: Hot path allocations
# Allocations inside frequently-called code
# ═══════════════════════════════════════════════════════

# Uncomment and adapt for your language:
# C#/Unity:  check "HOT_ALLOC" "new List<\|new Dictionary<\|new NativeArray"
# Java:      check "HOT_ALLOC" "new ArrayList<\|new HashMap<\|new HashSet<"
# TypeScript: check "HOT_ALLOC" "new Array(\|new Map(\|new Set("
# Python:    (list comprehensions in hot loops — harder to grep, manual review)
# Go:        check "HOT_ALLOC" "make(\\[\\]\|make(map"
# Rust:      check "HOT_ALLOC" "\\.clone()\|Vec::new()\|Box::new("
# C++:       check "HOT_ALLOC" "new \|malloc(\|calloc("

# ═══════════════════════════════════════════════════════
# SECTION 3: Cached reference violations
# Repeated lookups that should be cached
# ═══════════════════════════════════════════════════════

# Uncomment and adapt:
# Unity:     check "UNCACHED" "Camera\\.main\|GetComponent<\|FindObjectOfType"
# Web:       check "UNCACHED" "document\\.querySelector\|document\\.getElementById"
# Spring:    check "UNCACHED" "getBean(\|getEnvironment()"
# Go:        check "UNCACHED" "os\\.Getenv("

# ═══════════════════════════════════════════════════════
# SECTION 4: Framework anti-patterns
# Known dangerous patterns for your framework
# ═══════════════════════════════════════════════════════

# Uncomment and adapt:
# Unity:     check "ANTIPATTERN" "AppendStructuredBuffer\|SetFloats\|ComputeBufferType\\.Append"
# React:     check "ANTIPATTERN" "dangerouslySetInnerHTML\|innerHTML"
# Python:    check "ANTIPATTERN" "eval(\|exec(\|__import__"
# Java:      check "ANTIPATTERN" "e\\.printStackTrace(\|System\\.out\\.print"
# Go:        check "ANTIPATTERN" "panic(\|log\\.Fatal("
# Rust:      check "ANTIPATTERN" "unsafe {"
# C++:       check "ANTIPATTERN" "reinterpret_cast\|const_cast"

# ═══════════════════════════════════════════════════════
# SECTION 5: Resource guard
# Resources opened without matching close/dispose
# ═══════════════════════════════════════════════════════

# Uncomment and adapt:
# C#:        check "RESOURCE" "new FileStream\|new SqlConnection\|new StreamReader"
# Java:      check "RESOURCE" "new FileInputStream\|new BufferedReader\|DriverManager\\.getConnection"
# Python:    check "RESOURCE" "open(\|sqlite3\\.connect("
# Go:        check "RESOURCE" "os\\.Open(\|sql\\.Open("
# C++:       check "RESOURCE" "fopen(\|new std::"

# ═══════════════════════════════════════════════════════
# SECTION 6: String allocation in hot paths
# String building in performance-critical code
# ═══════════════════════════════════════════════════════

# Uncomment and adapt:
# C#:        check "STRING_ALLOC" '\$".*{' "$SRC_DIR"
# Java:      check "STRING_ALLOC" '" \+\|String\\.format('
# Python:    check "STRING_ALLOC" "f'\|f\""
# Go:        check "STRING_ALLOC" "fmt\\.Sprintf("

# ═══════════════════════════════════════════════════════
# SECTION 7: Contract violations
# Project-specific forbidden API usage
# ═══════════════════════════════════════════════════════

# Add your project's forbidden patterns here:
# check "CONTRACT" "forbidden_function_name\|deprecated_api"

# ═══════════════════════════════════════════════════════
# SECTION 8: Observability coverage
# Missing logging/profiling in key operations
# ═══════════════════════════════════════════════════════

# This is harder to grep — usually a manual check.
# For Unity, you can check for ProfilerMarker usage:
# check "OBSERVABILITY" "Dispatch\|Upload\|Evaluate" and cross-check with ProfilerMarker

# ═══════════════════════════════════════════════════════
# SECTION 9: Test coverage gap
# Source files without matching test files
# ═══════════════════════════════════════════════════════

echo ""
echo "── TEST COVERAGE GAP ──"
missing=0
while IFS= read -r f; do
  base=$(basename "$f" ".${f##*.}")
  # Skip common non-testable files
  [[ "$base" == "Program" || "$base" == "Startup" || "$base" == "index" ]] && continue
  if ! find "$TEST_DIR" -name "${base}*test*" -o -name "${base}*spec*" \
       -o -name "test_${base}*" -o -name "*${base}Test*" -o -name "*${base}_test*" \
       2>/dev/null | grep -q .; then
    echo "  NO TEST: $f"
    missing=$((missing + 1))
  fi
done < <(find "$SRC_DIR" -name "*.${EXT}" -not -path "*/test*" -not -path "*/__pycache__/*" 2>/dev/null)
total=$((total + missing))
[[ $missing -eq 0 ]] && echo "  All source files have matching tests."

# ═══════════════════════════════════════════════════════
# SECTION 10: API parity
# Same configuration set at all call sites
# ═══════════════════════════════════════════════════════

# Project-specific: check that all dispatch/config call sites use the same set of parameters.
# Example for Unity compute:
# check "PARITY" "SetInt\|SetFloat\|SetVector\|SetBuffer" and verify parity manually

# ═══════════════════════════════════════════════════════
# SECTION 11: Roadmap ↔ TRACKING.md Sync
# 11a: Catches premature ticks and forgotten ticks
# 11b: Orphan detection (items in one file but not other)
# 11c: Checkbox format check (CORE-### without - [ ] syntax)
# ═══════════════════════════════════════════════════════

echo ""
echo "── ROADMAP ↔ TRACKING SYNC ──"
TRACKING_FILE="$ROOT/TRACKING.md"        # ← adjust if different location
ROADMAP_FILE="$ROOT/Docs/Planning/Roadmap.md"  # ← adjust to your roadmap path
# Adjust the ID pattern below to match your project's item IDs (e.g., CORE-[0-9]+, TASK-[0-9]+)
ID_PATTERN="CORE-[0-9]+"
sync_findings=0

if [[ -f "$TRACKING_FILE" ]] && [[ -f "$ROADMAP_FILE" ]]; then
  # 11a. Extract item statuses from TRACKING.md
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

  # Check roadmap checkboxes against TRACKING statuses
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue

    is_checked=false
    is_skipped=false
    echo "$line" | grep -qE "^\s*-\s*\[x\]" && is_checked=true
    echo "$line" | grep -qE "^\s*-\s*\[~\]" && is_skipped=true

    t_status="${tracking_status[$item_id]:-unknown}"

    if $is_checked && [[ "$t_status" != "verified" ]]; then
      echo "  MISMATCH  $item_id: Roadmap=[x] but TRACKING=$t_status (premature tick)"
      sync_findings=$((sync_findings + 1))
    elif ! $is_checked && ! $is_skipped && [[ "$t_status" == "verified" ]]; then
      echo "  MISMATCH  $item_id: Roadmap=[ ] but TRACKING=verified (forgotten tick)"
      sync_findings=$((sync_findings + 1))
    elif $is_skipped && [[ "$t_status" != "deferred" ]]; then
      echo "  MISMATCH  $item_id: Roadmap=[~] but TRACKING=$t_status (should be deferred)"
      sync_findings=$((sync_findings + 1))
    elif ! $is_skipped && [[ "$t_status" == "deferred" ]]; then
      echo "  MISMATCH  $item_id: Roadmap=[ ] but TRACKING=deferred (missing [~] mark)"
      sync_findings=$((sync_findings + 1))
    fi
  done < <(grep -E "\- \[.\].*$ID_PATTERN" "$ROADMAP_FILE" || true)

  if [[ $sync_findings -eq 0 ]]; then
    echo "  (roadmap checkboxes consistent with TRACKING.md)"
  fi

  # 11b. Orphan detection — items in one file but not the other
  echo ""
  echo "── ORPHAN CHECK ──"
  orphans=0

  # Items in TRACKING but not in Roadmap
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    if ! grep -q "$item_id" "$ROADMAP_FILE" 2>/dev/null; then
      echo "  ORPHAN  $item_id: exists in TRACKING but not in Roadmap"
      orphans=$((orphans + 1))
    fi
  done < <(grep -E "$ID_PATTERN" "$TRACKING_FILE" 2>/dev/null | head -200 || true)

  # Items in Roadmap but not in TRACKING
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    if ! grep -q "$item_id" "$TRACKING_FILE" 2>/dev/null; then
      echo "  ORPHAN  $item_id: exists in Roadmap but not in TRACKING"
      orphans=$((orphans + 1))
    fi
  done < <(grep -E "$ID_PATTERN" "$ROADMAP_FILE" 2>/dev/null | head -200 || true)

  [[ $orphans -eq 0 ]] && echo "  No orphan items found."
  total=$((total + orphans))

  # 11c. Checkbox format check — detect CORE-### items without checkbox
  echo ""
  echo "── CHECKBOX FORMAT CHECK ──"
  fmt_errors=0
  while IFS= read -r line; do
    item_id=$(echo "$line" | grep -oE "$ID_PATTERN" | head -1)
    [[ -z "$item_id" ]] && continue
    # Skip lines that already have checkbox format
    echo "$line" | grep -qE "^\s*-\s*\[.\]" && continue
    echo "  FORMAT  $item_id: missing checkbox — use '- [ ] $item_id: ...' (breaks close gate tracking)"
    fmt_errors=$((fmt_errors + 1))
  done < <(grep -E "$ID_PATTERN" "$ROADMAP_FILE" 2>/dev/null | grep -E "^\s*-\s" | head -200 || true)
  [[ $fmt_errors -eq 0 ]] && echo "  All roadmap items have checkbox format."
  total=$((total + fmt_errors))
else
  echo "  (TRACKING.md or Roadmap.md not found — skipping)"
fi
total=$((total + sync_findings))

# ═══════════════════════════════════════════════════════
# SECTION 12: Metric ↔ Test Coverage
# Each roadmap metric must have a matching test.
# Extracts metric lines from Roadmap.md (two formats):
#   Format A: "Metric: description" or "**Metric:** description"
#   Format B: Bullet lines under "**Metric gates:**" header
# Searches TEST_DIR for corresponding test evidence.
# ═══════════════════════════════════════════════════════

echo ""
echo "── METRIC ↔ TEST COVERAGE ──"
metric_gaps=0

if [[ -f "$ROADMAP_FILE" ]]; then
  # Extract metric lines using awk (handles both formats):
  #   Format A: lines with "Metric:" directly (but not "Metric gate" headers)
  #   Format B: bullet lines under "Metric gates:" headers
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
      # Extract metric description based on format
      if echo "$mline" | grep -qiE "[Mm]etric[s]?\s*[:：]"; then
        # Format A: "Metric: description"
        metric_desc=$(echo "$mline" | sed -E 's/.*[Mm]etric[s]?\s*[:：]\s*//' | sed 's/[*`]//g' | xargs)
      else
        # Format B: "- description" (bullet under Metric gates header)
        metric_desc=$(echo "$mline" | sed -E 's/^\s*-\s*//' | sed 's/[*`]//g' | xargs)
      fi
      [[ -z "$metric_desc" ]] && continue

      # Extract keywords (3+ chars, skip common filler)
      keywords=$(echo "$metric_desc" | tr '[:upper:]' '[:lower:]' | \
        sed -E 's/[^a-z0-9 ]/ /g' | \
        tr ' ' '\n' | \
        grep -vE '^(the|a|an|is|are|be|to|of|in|for|and|or|no|not|with|must|should|each|per|all|any|same|than|from|has|have|does|when|will|can|at|by)$' | \
        grep -E '.{3,}' | \
        sort -u | head -8)

      # Search TEST_DIR for any keyword match
      found=false
      for kw in $keywords; do
        if grep -rli "$kw" "$TEST_DIR" --include="*.${EXT}" 2>/dev/null | grep -q .; then
          found=true
          break
        fi
      done

      if ! $found; then
        echo "  BLOCKER  NO TEST COVERAGE: $metric_desc"
        echo "    (keywords searched: $(echo $keywords | tr '\n' ', '))"
        metric_gaps=$((metric_gaps + 1))
      fi
    done <<< "$metric_lines"
  fi

  if [[ $metric_gaps -eq 0 ]]; then
    echo "  All roadmap metrics have matching test coverage."
  else
    echo ""
    echo "  $metric_gaps metric(s) without test coverage."
    echo "  BLOCKER — these are NOT false-positive-eligible. Gate cannot close."
    echo "  Action: write tests, or escalate via unmet-metric procedure (Close Gate Phase 0)."
  fi
else
  echo "  (Roadmap file not found — skipping metric coverage check)"
fi
total=$((total + metric_gaps))
blockers=$((blockers + metric_gaps))

# ═══════════════════════════════════════════════════════
# SECTION 13: Change Log completeness
# At least one Change Log entry should exist if sprint
# items are tracked. Empty Change Log suggests AI skipped
# decision/state logging during the sprint.
# ═══════════════════════════════════════════════════════

echo ""
echo "── CHANGE LOG ──"
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
  echo "  SKIP  (TRACKING.md not found)"
fi

# ═══════════════════════════════════════════════════════
# SECTION 14: Entry Gate log presence
# If Sprint Board has items, an Entry Gate should have
# been run and logged. Missing log suggests Entry Gate
# was skipped or not recorded.
# ═══════════════════════════════════════════════════════

echo ""
echo "── ENTRY GATE LOG ──"
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
  echo "  SKIP  (TRACKING.md not found)"
fi

# ═══════════════════════════════════════════════════════
# SECTION 15: Failure transfer check
# If Failure Encounters has entries, they should be
# transferred to Failure Mode History at Sprint Close
# step 7. Untransferred entries suggest Sprint Close
# was incomplete.
# ═══════════════════════════════════════════════════════

echo ""
echo "── FAILURE TRANSFER ──"
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
  echo "  SKIP  (TRACKING.md not found)"
fi

# ═══════════════════════════════════════════════════════
# SECTION 16: CLAUDE.md Last Checkpoint staleness
# Last Checkpoint should exist and not be empty template
# values. Stale checkpoint means session recovery will
# not know where the sprint left off.
# ═══════════════════════════════════════════════════════

echo ""
echo "── LAST CHECKPOINT ──"
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
  echo "  SKIP  (CLAUDE.md not found)"
fi

# ═══════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════"
if [[ $errors -gt 0 ]]; then
  echo "Sprint audit: $errors setup error(s) — fix script configuration before audit."
  exit 2
elif [[ $total -eq 0 ]]; then
  echo "Sprint audit CLEAN — 0 findings."
  exit 0
elif [[ $blockers -gt 0 ]]; then
  echo "Sprint audit: $total finding(s), $blockers BLOCKER(s) — gate cannot close."
  echo "BLOCKER findings require action (write test or escalate). They cannot be dismissed as false positive."
  [[ $((total - blockers)) -gt 0 ]] && echo "Remaining $((total - blockers)) finding(s): review each, fix or mark as false positive."
  exit 1
else
  echo "Sprint audit: $total finding(s) — review needed."
  echo "(Not all findings are bugs. Review each, fix or mark as false positive.)"
  exit 1
fi
