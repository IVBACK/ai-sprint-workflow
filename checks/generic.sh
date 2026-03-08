#!/usr/bin/env bash
# checks/generic.sh — Language-agnostic audit checks
#
# Always sourced by sprint-audit.sh. Runs checks that apply to any language.
# Requires: common.sh sourced first, SRC_DIR and EXT set.

echo ""
echo "── Generic Checks ──"

# Formalized debt tags (linked to tracked items)
check "SCAFFOLDING" "TEMP(CORE-\|TEMP(S"

# Naked TODO/HACK/FIXME without a tracked CORE-ID — blocks Close Gate.
# Excludes lines with formalized TEMP(CORE- or TEMP(S to avoid double-counting.
if [[ -d "$SRC_DIR" ]]; then
  _untracked=$(grep -rn "TODO\|HACK\|FIXME" --include="*.${EXT}" "$SRC_DIR" 2>/dev/null \
    | grep -v "TEMP(CORE-" | grep -v "TEMP(S" || true)
  _ucount=$(echo "$_untracked" | grep -c . 2>/dev/null || echo 0)
  if [[ $_ucount -gt 0 ]]; then
    echo ""
    echo "BLOCK [UNTRACKED_DEBT] — $_ucount finding(s) (non-dismissible):"
    echo "$_untracked" | head -20
    [[ $_ucount -gt 20 ]] && echo "  ... and $((_ucount - 20)) more"
    total=$((total + _ucount))
    blockers=$((blockers + _ucount))
  else
    echo "PASS  [UNTRACKED_DEBT]"
  fi
else
  echo "SKIP  [UNTRACKED_DEBT] — directory $SRC_DIR not found"
fi

# Contract violations (project-specific — add your forbidden patterns)
# check "CONTRACT" "forbidden_function_name\|deprecated_api"
