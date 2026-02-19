#!/bin/bash
# Hook: validate-tracking.sh
# Event: PostToolUse — Edit, Write
# Purpose: After TRACKING.md is edited, check that:
#   1. All status values are legal
#   2. "verified" items have evidence (non-empty evidence column)
#   3. "deferred" items have a reason
# Exits non-zero (non-blocking) to surface warnings — does not abort.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_VALIDATE_TRACKING" != "true" ]] && exit 0

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$FILE" != *"TRACKING.md"* ]] && exit 0

TRACKING_FILE="$FILE"
[[ ! -f "$TRACKING_FILE" ]] && exit 0

ERRORS=()
LEGAL_STATUSES="open|in_progress|fixed|verified|deferred|blocked"

# Check 1: Illegal status values in Sprint Board table
# Table rows look like: | CORE-001 | summary | STATUS | sprint | evidence |
ILLEGAL=$(grep -E '^\| CORE-[0-9]+' "$TRACKING_FILE" \
    | awk -F'|' '{gsub(/ /,"",$4); print NR": "$4}' \
    | grep -Ev "^[0-9]+:($LEGAL_STATUSES)$")

if [[ -n "$ILLEGAL" ]]; then
    ERRORS+=("Illegal status values found in Sprint Board:")
    while IFS= read -r line; do
        ERRORS+=("  $line")
    done <<< "$ILLEGAL"
fi

# Check 2: "verified" rows must have non-empty evidence column (col 5)
MISSING_EVIDENCE=$(grep -E '^\| CORE-[0-9]+' "$TRACKING_FILE" \
    | awk -F'|' '{gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$6); if ($4=="verified" && $6=="") print NR": "$2}')

if [[ -n "$MISSING_EVIDENCE" ]]; then
    ERRORS+=("'verified' items missing evidence:")
    while IFS= read -r line; do
        ERRORS+=("  $line")
    done <<< "$MISSING_EVIDENCE"
fi

# Check 3: "deferred" rows must have a reason (any content in evidence/notes col)
MISSING_REASON=$(grep -E '^\| CORE-[0-9]+' "$TRACKING_FILE" \
    | awk -F'|' '{gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$6); if ($4=="deferred" && $6=="") print NR": "$2}')

if [[ -n "$MISSING_REASON" ]]; then
    ERRORS+=("'deferred' items missing reason:")
    while IFS= read -r line; do
        ERRORS+=("  $line")
    done <<< "$MISSING_REASON"
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "TRACKING.md validation warnings:" >&2
    for err in "${ERRORS[@]}"; do
        echo "  $err" >&2
    done
    exit 1  # Non-blocking: warns agent but does not abort
fi

exit 0
