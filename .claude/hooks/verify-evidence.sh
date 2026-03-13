#!/usr/bin/env bash
# Script: verify-evidence.sh
# Purpose: Verify sub-agent AC exit check evidence (file:line references).
# Usage: bash .claude/hooks/verify-evidence.sh < agent-report.txt
#    or: bash .claude/hooks/verify-evidence.sh report.txt
# Exit: 0 = all evidence valid, 1 = invalid evidence found
#
# Not a hook — called by coordinator between waves to validate sub-agent reports.
# Checks that file:line references actually exist and extracts context snippets.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }

# ── Read input ──
REPORT=""
if [[ $# -ge 1 && -f "$1" ]]; then
  REPORT=$(cat "$1")
elif [[ ! -t 0 ]]; then
  REPORT=$(cat)
else
  echo "Usage: $0 < agent-report.txt" >&2
  echo "   or: $0 report.txt" >&2
  exit 1
fi

if [[ -z "$REPORT" ]]; then
  echo "Empty report" >&2
  exit 1
fi

# ── Extract file:line references ──
# Matches patterns like: src/app.ts:42, ./src/lib.rs:100, path/to/file.py:7
# Excludes common false positives (URLs, timestamps)
REFS=$(echo "$REPORT" | grep -oE '[a-zA-Z0-9_./-]+\.[a-zA-Z]{1,10}:[0-9]+' 2>/dev/null \
  | grep -vE '^https?:' \
  | grep -vE '^[0-9]+\.[0-9]+\.[0-9]+' \
  | sort -u || true)

if [[ -z "$REFS" ]]; then
  yellow "No file:line references found in report."
  echo "Report may not contain D.7 AC exit check evidence."
  exit 0
fi

REF_COUNT=$(echo "$REFS" | wc -l | tr -d ' ')
bold "=== Evidence Verification ==="
echo "Found $REF_COUNT file:line reference(s)"
echo ""

VALID=0
INVALID=0
CONTEXT_WIDTH=2  # lines of context before/after

cd "$PROJECT_DIR" 2>/dev/null || exit 1

while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue

  FILE_PATH="${ref%%:*}"
  LINE_NUM="${ref##*:}"

  # Try to resolve relative to project dir
  RESOLVED=""
  if [[ -f "$FILE_PATH" ]]; then
    RESOLVED="$FILE_PATH"
  elif [[ -f "$PROJECT_DIR/$FILE_PATH" ]]; then
    RESOLVED="$PROJECT_DIR/$FILE_PATH"
  fi

  if [[ -z "$RESOLVED" ]]; then
    red "  INVALID: $ref — file not found"
    INVALID=$((INVALID + 1))
    continue
  fi

  # Check line number is in range
  TOTAL_LINES=$(wc -l < "$RESOLVED" | tr -d ' ')
  if [[ "$LINE_NUM" -gt "$TOTAL_LINES" || "$LINE_NUM" -lt 1 ]]; then
    red "  INVALID: $ref — line $LINE_NUM out of range (file has $TOTAL_LINES lines)"
    INVALID=$((INVALID + 1))
    continue
  fi

  # Extract context snippet
  START=$((LINE_NUM - CONTEXT_WIDTH))
  [[ "$START" -lt 1 ]] && START=1
  END=$((LINE_NUM + CONTEXT_WIDTH))
  [[ "$END" -gt "$TOTAL_LINES" ]] && END=$TOTAL_LINES

  green "  VALID: $ref"
  # Show context with line numbers, highlighting the referenced line
  awk -v start="$START" -v end="$END" -v target="$LINE_NUM" \
    'NR >= start && NR <= end {
      prefix = (NR == target) ? ">>>" : "   "
      printf "    %s %4d | %s\n", prefix, NR, $0
    }' "$RESOLVED"
  echo ""
  VALID=$((VALID + 1))

done <<< "$REFS"

# ── Summary ──
echo ""
bold "=== Summary ==="
echo "Valid:   $VALID / $REF_COUNT"
echo "Invalid: $INVALID / $REF_COUNT"

if [[ "$INVALID" -gt 0 ]]; then
  echo ""
  red "EVIDENCE INCOMPLETE — $INVALID reference(s) could not be verified."
  echo "The coordinator should ask the sub-agent to fix invalid references"
  echo "before merging, or manually verify the acceptance criteria."
  exit 1
fi

green "ALL EVIDENCE VERIFIED"
exit 0
