#!/bin/bash
# Hook: protect-claude.sh
# Event: PreToolUse — Edit, Write
# Purpose: Block CLAUDE.md from being overwritten without explicit user intent.
#          WORKFLOW.md rule: "Never overwrite CLAUDE.md without reading and
#          preserving existing content."

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_PROTECT_CLAUDE_MD" != "true" ]] && exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on Write tool (full overwrite). Edit (partial) is allowed.
if [[ "$TOOL" == "Write" ]] && [[ "$FILE" == *"CLAUDE.md"* ]]; then
    echo "BLOCKED: Writing to CLAUDE.md is not allowed (would overwrite existing content)." >&2
    echo "Use the Edit tool to append or modify specific sections." >&2
    echo "WORKFLOW.md rule: 'Never overwrite CLAUDE.md without reading and preserving existing content.'" >&2
    exit 2
fi

exit 0
