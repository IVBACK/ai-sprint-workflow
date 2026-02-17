#!/usr/bin/env bash
set -euo pipefail

# sprint-audit.sh — Automated sprint close gate checks
#
# This is a TEMPLATE. Copy to your project's Tools/ directory and adapt
# the patterns to your language, framework, and project conventions.
#
# Usage:
#   Tools/sprint-audit.sh                       # Full scan
#   Tools/sprint-audit.sh --files "A.cs B.cs"   # Scoped to specific files
#
# Exit codes:
#   0 = Clean (0 findings)
#   1 = Findings exist (review needed, not necessarily failures)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT/src"         # ← adjust to your source directory
TEST_DIR="$ROOT/tests"      # ← adjust to your test directory
EXT="*"                     # ← adjust: "cs", "ts", "py", "java", "go", "rs", "cpp"

total=0

# ── Helper ──

check() {
  local name="$1" pattern="$2" dir="${3:-$SRC_DIR}"
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
# SUMMARY
# ═══════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════"
if [[ $total -eq 0 ]]; then
  echo "Sprint audit CLEAN — 0 findings."
  exit 0
else
  echo "Sprint audit: $total finding(s) — review needed."
  echo "(Not all findings are bugs. Review each, fix or mark as false positive.)"
  exit 1
fi
