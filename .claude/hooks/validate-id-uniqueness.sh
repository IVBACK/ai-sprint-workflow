#!/bin/bash
# Hook: validate-id-uniqueness.sh
# Event: PostToolUse — Edit, Write
# Purpose: After TRACKING.md is edited, detect duplicate CORE-### IDs.
#          WORKFLOW.md rule: "Never reuse an existing ID."
#          Soft warn (exit 1) — does not abort, surfaces to agent.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_VALIDATE_ID_UNIQUENESS" != "true" ]] && exit 0

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ "$FILE" != *"TRACKING.md"* ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

# Extract all CORE-### IDs and find duplicates
DUPLICATES=$(grep -oE 'CORE-[0-9]+' "$FILE" | sort | uniq -d)

if [[ -n "$DUPLICATES" ]]; then
    echo "TRACKING.md ID uniqueness violation:" >&2
    echo "  Duplicate CORE-### IDs found (IDs must never be reused):" >&2
    while IFS= read -r id; do
        COUNT=$(grep -oE "$id" "$FILE" | wc -l)
        echo "  $id appears $COUNT times" >&2
    done <<< "$DUPLICATES"
    echo "  Fix: remove or reassign the duplicate entry." >&2
    exit 1
fi

exit 0
