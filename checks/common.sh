#!/usr/bin/env bash
# checks/common.sh — Shared helpers for modular audit checks
#
# Source this file in the main sprint-audit script and language adapters.
# Provides: check(), check_blocker(), summary variables.

# ── Counters (initialized by main script, incremented by checks) ──
# These must be declared before sourcing this file:
#   total=0  errors=0  blockers=0

# ── Helper: check() ──
# Runs a grep-based check and reports findings.
#
# Usage: check "CHECK_NAME" "grep_pattern" [directory]
#
# Arguments:
#   $1 — Check name (displayed in output)
#   $2 — Grep pattern (extended regex)
#   $3 — Directory to search (default: $SRC_DIR)
#
# Globals read: SRC_DIR, EXT
# Globals modified: total
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

# ── Helper: check_blocker() ──
# Same as check() but findings are non-dismissible blockers.
#
# Usage: check_blocker "CHECK_NAME" "grep_pattern" [directory]
check_blocker() {
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
    echo "BLOCKER  [$name] — $count finding(s):"
    echo "$results" | head -20
    [[ $count -gt 20 ]] && echo "  ... and $((count - 20)) more"
    total=$((total + count))
    blockers=$((blockers + count))
  else
    echo "PASS  [$name]"
  fi
}

# ── Helper: check_multi() ──
# Runs check() with multiple file extensions.
#
# Usage: check_multi "CHECK_NAME" "grep_pattern" "ext1 ext2 ext3" [directory]
check_multi() {
  local name="$1" pattern="$2" extensions="$3" dir="${4:-$SRC_DIR}"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP  [$name] — directory $dir not found"
    return
  fi
  local include_args=""
  for ext in $extensions; do
    include_args="$include_args --include=*.${ext}"
  done
  local results count
  results=$(grep -rn "$pattern" $include_args "$dir" 2>/dev/null || true)
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
