#!/usr/bin/env bash
# Script: audit-health-check.sh
# Purpose: Check cross-LLM audit system health by reading the audit log.
# Usage: bash .claude/hooks/audit-health-check.sh
# Exit: 0 = healthy (audit ran successfully recently), 1 = stale or only errors
#
# Not a hook — standalone diagnostic script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load centralized config for default thresholds
[[ -f "$SCRIPT_DIR/../hooks-config.sh" ]] && source "$SCRIPT_DIR/../hooks-config.sh"

STATE_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)}/.claude/.state"
AUDIT_LOG="${STATE_DIR}/cross-audit-log.jsonl"
STALE_THRESHOLD_SECONDS="${1:-${AUDIT_HEALTH_STALE_SECONDS:-3600}}"  # Default: 1 hour

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }
yellow(){ printf '\033[33m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }

bold "=== Cross-LLM Audit Health Check ==="
echo ""

# Check if log exists
if [[ ! -f "$AUDIT_LOG" ]]; then
  red "No audit log found at: $AUDIT_LOG"
  echo "Audit has never run, or logging was not enabled."
  exit 1
fi

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
  red "jq is required for health check. Install jq: apt/brew/pacman/choco install jq"
  exit 1
fi

# Total entries
TOTAL=$(wc -l < "$AUDIT_LOG" | tr -d ' ')
echo "Log entries: $TOTAL"

# Count by status
echo ""
bold "Status breakdown:"
jq -r '.status' "$AUDIT_LOG" 2>/dev/null | sort | uniq -c | sort -rn || echo "  (parse error)"

# Last successful audit
LAST_SUCCESS=$(grep '"success"' "$AUDIT_LOG" 2>/dev/null | tail -1 || true)
if [[ -n "$LAST_SUCCESS" ]]; then
  LAST_TS=$(echo "$LAST_SUCCESS" | jq -r '.ts' 2>/dev/null)
  LAST_VERDICT=$(echo "$LAST_SUCCESS" | jq -r '.verdict' 2>/dev/null)
  LAST_MODE=$(echo "$LAST_SUCCESS" | jq -r '.mode' 2>/dev/null)
  echo ""
  green "Last successful audit: $LAST_TS (verdict=$LAST_VERDICT, mode=$LAST_MODE)"

  # Check staleness
  if command -v date >/dev/null 2>&1; then
    LAST_EPOCH=$(date -d "$LAST_TS" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_TS" +%s 2>/dev/null || echo 0)
    NOW_EPOCH=$(date +%s)
    AGE=$((NOW_EPOCH - LAST_EPOCH))
    if [[ "$AGE" -gt "$STALE_THRESHOLD_SECONDS" ]]; then
      yellow "WARNING: Last successful audit was ${AGE}s ago (threshold: ${STALE_THRESHOLD_SECONDS}s)"
      HEALTHY=false
    else
      green "Audit is fresh (${AGE}s ago, threshold: ${STALE_THRESHOLD_SECONDS}s)"
      HEALTHY=true
    fi
  fi
else
  red "No successful audit found in log!"
  HEALTHY=false
fi

# Recent errors
RECENT_ERRORS=$(tail -20 "$AUDIT_LOG" | grep -c '"error"' 2>/dev/null || echo 0)
if [[ "$RECENT_ERRORS" -gt "${AUDIT_HEALTH_ERROR_THRESHOLD:-5}" ]]; then
  echo ""
  red "WARNING: $RECENT_ERRORS errors in last 20 entries"
  echo "Recent errors:"
  tail -20 "$AUDIT_LOG" | grep '"error"' | tail -5 | jq -r '"\(.ts) \(.reason)"' 2>/dev/null || true
  HEALTHY=false
fi

# Last 5 entries
echo ""
bold "Last 5 entries:"
tail -5 "$AUDIT_LOG" | jq -r '"\(.ts) [\(.status)] \(.reason // .verdict // "-") \(.mode // "-")"' 2>/dev/null || tail -5 "$AUDIT_LOG"

echo ""
if [[ "${HEALTHY:-false}" == "true" ]]; then
  green "HEALTHY"
  exit 0
else
  red "UNHEALTHY — check configuration"
  exit 1
fi
