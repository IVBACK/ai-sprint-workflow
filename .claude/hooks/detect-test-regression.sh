#!/usr/bin/env bash
# Hook: detect-test-regression.sh
# Event: PostToolUse — Bash
# Purpose: After a test runner Bash call, scan stdout for failure signals.
#          Only triggers when the command is a known test runner — not on
#          git, ls, curl, or other unrelated commands.
#          If failures detected, inject CP3 AUDIT SIGNAL.
# WORKFLOW.md rule: Implementation Loop Step D.6 — "Do not silently continue;
#          surface AUDIT SIGNAL when past API missing/broken or test FAIL."
# Exit: 0 always (non-blocking) — injects additionalContext only.

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_DETECT_TEST_REGRESSION" != "true" ]] && exit 0
command -v jq >/dev/null 2>&1 || { echo "jq not found, skipping. Install: apt/brew/pacman/choco install jq" >&2; exit 0; }

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

[[ "$TOOL" != "Bash" ]] && exit 0

# --- Gate 1: Is this command a test runner? ---
# Check the command string before scanning output.
# Only proceed for known test runner invocations.
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

TEST_RUNNER_PATTERNS=(
    "pytest"
    "python -m pytest"
    "python3 -m pytest"
    "jest"
    "npx jest"
    "npm test"
    "npm run test"
    "yarn test"
    "go test"
    "cargo test"
    "dotnet test"
    "mvn test"
    "gradle test"
    "gradlew test"
    "make test"
    "unittest"
    "python -m unittest"
    "rspec"
    "mix test"
    "phpunit"
    "xunit"
    "nunit"
    "unity.*-runTests"
    "bash.*sprint-audit"
    "bash.*audit"
    "bash\s+test\b"
    "sh\s+test\b"
    "bash\s+run[_-]tests"
    "sh\s+run[_-]tests"
    "\./test"
    "run_tests"
    "run-tests"
)

IS_TEST_RUNNER=false
for pattern in "${TEST_RUNNER_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern" 2>/dev/null; then
        IS_TEST_RUNNER=true
        break
    fi
done

[[ "$IS_TEST_RUNNER" != "true" ]] && exit 0

# --- State directory setup (needed by both empty-output and failure paths) ---
# Derive project dir reliably: prefer CLAUDE_PROJECT_DIR, fall back to hook's own location
_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$HOOKS_DIR/../.." && pwd)}"
STATE_DIR="$_PROJECT_DIR/.claude/.state"
ESCALATION_FILE="$STATE_DIR/escalation-counter.json"

# --- Gate 2: Extract and scan output ---
OUTPUT=$(echo "$INPUT" | jq -r '.tool_response.output // empty')

[[ -z "$OUTPUT" ]] && {
    # Empty output from test runner = likely passed
    [[ -f "$ESCALATION_FILE" ]] && rm -f "$ESCALATION_FILE" 2>/dev/null
    exit 0
}

# Failure patterns — narrowed to test-runner specific formats only.
# Excludes generic words like "FAILED" that appear in non-test contexts.
FAIL_PATTERNS=(
    # pytest
    "FAILED [a-zA-Z].*::"
    "[0-9]+ failed(, [0-9]+ passed)?"
    "short test summary info"
    # jest / vitest
    "Tests:.*[1-9][0-9]* failed"
    "FAIL [a-zA-Z./]"
    # go test
    "^--- FAIL:"
    "^FAIL\s"
    "^FAIL\t"
    # cargo test
    "test result: FAILED\."
    "failures:"
    # dotnet test / xunit / nunit
    "Failed:[[:space:]]*[1-9]"
    "Total:.*Error:[[:space:]]*[1-9]"
    "Tests run:.*Failures: [1-9]"
    "Tests run:.*Errors: [1-9]"
    # JUnit / Maven / Gradle
    "BUILD FAILED"
    "Tests in error:"
    # Unity
    "Test run failed\."
    "had [1-9][0-9]* failure"
    # Generic — only when clearly from a test runner context
    "AssertionError:"
    "AssertionException:"
)

MATCHED_LINES=()
for pattern in "${FAIL_PATTERNS[@]}"; do
    while IFS= read -r line; do
        MATCHED_LINES+=("$line")
    done < <(echo "$OUTPUT" | grep -E "$pattern" 2>/dev/null | head -3)
done

# --- Gate 3: Test passed? Reset escalation counter ---
if [[ ${#MATCHED_LINES[@]} -eq 0 ]]; then
    # Tests passed — reset escalation counter
    if [[ -f "$ESCALATION_FILE" ]]; then
        rm -f "$ESCALATION_FILE" 2>/dev/null
    fi
    exit 0
fi

# --- Test failures detected — track consecutive failures ---
mkdir -p -m 700 "$STATE_DIR" 2>/dev/null

FAIL_COUNT=1
if [[ -f "$ESCALATION_FILE" ]]; then
    PREV_COUNT=$(jq -r '.count // 0' "$ESCALATION_FILE" 2>/dev/null || echo 0)
    FAIL_COUNT=$((PREV_COUNT + 1))
fi

_TMP_ESC="$ESCALATION_FILE.tmp"
jq -n --argjson count "$FAIL_COUNT" --arg cmd "$COMMAND" \
    '{"count": $count, "last_cmd": $cmd}' > "$_TMP_ESC" 2>/dev/null && \
    mv "$_TMP_ESC" "$ESCALATION_FILE" 2>/dev/null

UNIQUE_LINES=$(printf '%s\n' "${MATCHED_LINES[@]}" | sort -u | head -8)

# Build escalation reminder based on consecutive failure count
# Use printf to produce real newlines so jq --arg properly JSON-escapes them
ESCALATION_MSG=""
if [[ $FAIL_COUNT -ge 3 ]]; then
    ESCALATION_MSG=$(printf '\n⚠ ESCALATION: This is consecutive failure #%d. You have hit the 3-strike limit.\nSTOP fixing and present options to user (see IMPL-LOOP §C or §D.6).\n' "$FAIL_COUNT")
elif [[ $FAIL_COUNT -ge 2 ]]; then
    ESCALATION_MSG=$(printf '\n⚠ ESCALATION: This is consecutive failure #%d. Apply Approach Escalation (IMPL-LOOP §B.2).\nDo NOT repeat the same fix. Move to L2+ (alternative approach, deeper investigation, or decompose).\nLog transition: sprint-tools note attempt "L1→L2: [reason]"\n' "$FAIL_COUNT")
fi

jq -n --arg lines "$UNIQUE_LINES" --arg cmd "$COMMAND" --arg esc "$ESCALATION_MSG" '{
  "additionalContext": (
    "=== ⚠ CP3 AUDIT SIGNAL (WORKFLOW.md Implementation Loop D.6) ===\n" +
    "Test failures detected in: " + $cmd + "\n" +
    $lines + "\n\n" +
    "REQUIRED ACTIONS:\n" +
    "1. Determine if these are current-sprint or past-sprint failures.\n" +
    "2. If past-sprint: DO NOT continue silently. Surface to user:\n" +
    "   \"Past-sprint test regression detected — recommend Retroactive Audit.\"\n" +
    "3. If current-sprint: fix before proceeding, do not defer silently.\n" +
    "4. Do not mark sprint items as verified while tests are failing.\n" +
    "5. PREFER spawning a diagnostic sub-agent (worktree) with the failure output +\n" +
    "   stack trace files. Task: identify root cause + propose fix (do NOT apply).\n" +
    "   Review diagnosis before applying. If no sub-agent: diagnose in-context.\n" +
    $esc +
    "================================================================="
  )
}'

exit 0
