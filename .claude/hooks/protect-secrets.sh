#!/bin/bash
# Hook: protect-secrets.sh
# Event: PreToolUse — Read, Bash
# Purpose: Prevent the AI from reading files that contain secrets.
#          API keys are managed by shell hooks (cross-llm-audit.sh) —
#          the AI should never see them directly.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_PROTECT_SECRETS" != "true" ]] && exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# ── Block Read tool on secret files ──
if [[ "$TOOL" == "Read" ]]; then
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    BASE=$(basename "$FILE")

    # Allow .env.example (template, no secrets)
    [[ "$BASE" == ".env.example" ]] && exit 0

    case "$BASE" in
        .env|.env.*|*.key|*.pem|*.p12)
            echo "BLOCKED: Reading $BASE is not allowed — it may contain API keys or secrets." >&2
            echo "The cross-LLM audit hook reads .env automatically. You don't need to access it." >&2
            echo "To check audit status: look for 'Cross-audit:' messages in stderr after code changes." >&2
            exit 2
            ;;
        credentials.json|secrets.yaml|secrets.yml)
            echo "BLOCKED: Reading $BASE is not allowed — it may contain secrets." >&2
            exit 2
            ;;
    esac
fi

# ── Block Bash commands that would expose secrets ──
if [[ "$TOOL" == "Bash" ]]; then
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

    # Helper: does the command reference a secret file?
    # Matches .env (not .env.example), .env.*, credentials.json, secrets.yaml, *.key, *.pem, *.p12
    _has_secret_ref() {
        local cmd="$1"
        # .env files — match .env followed by non-alphanumeric or end
        if echo "$cmd" | grep -qE '\.env([^a-zA-Z0-9_-]|$)'; then
            # Exclude .env.example
            if ! echo "$cmd" | grep -qE '\.env\.example'; then
                return 0
            fi
        fi
        # Other secret file types
        if echo "$cmd" | grep -qE 'credentials\.json|secrets\.ya?ml'; then
            return 0
        fi
        if echo "$cmd" | grep -qE '\.(key|pem|p12)([^a-zA-Z0-9_-]|$)'; then
            return 0
        fi
        return 1
    }

    # Layer 1: Direct read commands
    if echo "$CMD" | grep -qE '(cat|head|tail|less|more|bat|source)\s' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents." >&2
        echo "The cross-LLM audit hook manages .env automatically." >&2
        exit 2
    fi

    # Layer 2: Scripting languages
    if echo "$CMD" | grep -qE '(python|python3|perl|ruby|node|php)' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents via scripting." >&2
        exit 2
    fi

    # Layer 3: Encoding/dump tools
    if echo "$CMD" | grep -qE '(base64|xxd|od|hexdump|strings)\s' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents." >&2
        exit 2
    fi

    # Layer 4: Text processing tools
    if echo "$CMD" | grep -qE '(awk|sed|grep|rg|jq|yq)\s' && _has_secret_ref "$CMD"; then
        echo "BLOCKED: This command would expose secret file contents." >&2
        exit 2
    fi

    # Layer 5: File redirects: < .env, $(<.env)
    if echo "$CMD" | grep -qE '<\s*\.env([^a-zA-Z0-9_-]|$)'; then
        if ! echo "$CMD" | grep -qE '\.env\.example'; then
            echo "BLOCKED: File redirect on .env detected." >&2
            exit 2
        fi
    fi

    # Layer 6: Explicit env var exposure
    if echo "$CMD" | grep -qiE '(echo|printf|printenv|env\s).*\$?\{?(CROSS_AUDIT_API_KEY|CROSS_AUDIT_.*KEY)'; then
        echo "BLOCKED: This command would expose the API key." >&2
        exit 2
    fi
fi

exit 0
