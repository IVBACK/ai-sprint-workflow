#!/bin/bash
# Test script for cross-llm-audit.sh
# Usage:
#   bash .claude/hooks/test-cross-audit.sh              # Mock test (no API call)
#   bash .claude/hooks/test-cross-audit.sh --live        # Live test (uses .env or env vars)
#
# Live test loads API key from .env automatically (same as the hook itself).
# Or set env vars manually:
#   export CROSS_AUDIT_API_KEY="your-key"
#   export CROSS_AUDIT_API_BASE="https://models.inference.ai.azure.com"  # GitHub Models
#   export CROSS_AUDIT_MODEL="gpt-4o"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/cross-llm-audit.sh"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASSED=0
FAILED=0
LIVE_MODE="${1:-}"

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }
bold()  { printf '\033[1m%s\033[0m\n' "$1"; }

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    green "  PASS: $desc (exit=$actual)"
    PASSED=$((PASSED + 1))
  else
    red "  FAIL: $desc (expected exit=$expected, got exit=$actual)"
    FAILED=$((FAILED + 1))
  fi
}

assert_empty() {
  local desc="$1" output="$2"
  if [[ -z "$output" ]]; then
    green "  PASS: $desc (no output)"
    PASSED=$((PASSED + 1))
  else
    red "  FAIL: $desc (expected empty, got: ${output:0:80}...)"
    FAILED=$((FAILED + 1))
  fi
}

assert_contains() {
  local desc="$1" output="$2" pattern="$3"
  if echo "$output" | grep -q "$pattern" 2>/dev/null; then
    green "  PASS: $desc (contains '$pattern')"
    PASSED=$((PASSED + 1))
  else
    red "  FAIL: $desc (missing '$pattern')"
    FAILED=$((FAILED + 1))
  fi
}

# ══════════════════════════════════════════
bold "═══ Cross-LLM Audit Hook Tests ═══"
echo ""

# ── Test 1: No API key → silent exit ──
bold "Test 1: No API key → silent skip"
OUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' \
  | CROSS_AUDIT_API_KEY="" bash "$HOOK" 2>&1)
assert_exit "exits 0 without API key" 0 $?
assert_empty "no output without API key" "$OUT"

# ── Test 3: Skip non-source files ──
bold "Test 2: Skips non-source files"
# Note: S*_ENTRY_GATE.md, S*_CLOSE_GATE.md, and TRACKING.md are NOT skipped —
# they trigger special audit modes (entry-gate, close-gate, wave-review).
# They are tested separately in tests 9-13.
for skip_file in "CLAUDE.md" "WORKFLOW.md" "Docs/Planning/Roadmap.md" \
                 "SPRINT_CLOSE.md" "CODING_GUARDRAILS.md" "LESSONS.md" \
                 "config.json" ".env" "package-lock.json" "data.yaml"; do
  OUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$skip_file\"}}" \
    | CROSS_AUDIT_API_KEY="test" bash "$HOOK" 2>&1)
  assert_empty "skips $skip_file" "$OUT"
done

# ── Test 4: Skip non-Edit/Write tools ──
bold "Test 3: Skips non-Edit/Write tools"
for tool in "Bash" "Read" "Glob" "Grep" "Agent"; do
  OUT=$(echo "{\"tool_name\":\"$tool\",\"tool_input\":{\"file_path\":\"src/app.ts\"}}" \
    | CROSS_AUDIT_API_KEY="test" bash "$HOOK" 2>&1)
  assert_empty "skips tool=$tool" "$OUT"
done

# ── Test 5: Wave mode counter ──
bold "Test 4: Wave mode batching (fires on 5th edit)"
TEST_COUNTER="/tmp/.cross-audit-test-counter-$$"
rm -f "$TEST_COUNTER"
for i in 1 2 3 4; do
  OUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' \
    | CROSS_AUDIT_API_KEY="test" \
      CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
      CROSS_AUDIT_COUNTER_FILE="$TEST_COUNTER" \
      bash "$HOOK" 2>&1)
done
if [[ -f "$TEST_COUNTER" ]]; then
  COUNT=$(cat "$TEST_COUNTER")
  if [[ "$COUNT" == "4" ]]; then
    green "  PASS: counter incremented to 4 after 4 edits"
    PASSED=$((PASSED + 1))
  else
    red "  FAIL: counter is $COUNT, expected 4"
    FAILED=$((FAILED + 1))
  fi
  rm -f "$TEST_COUNTER"
else
  red "  FAIL: counter file not created"
  FAILED=$((FAILED + 1))
fi

# ── Test 5: Wave-size=1 (every edit) ──
bold "Test 5: Wave-size=1 passes through immediately"
# This will try to run but fail at git diff (no changes) — that's fine
OUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' \
  | CROSS_AUDIT_API_KEY="test" \
    CROSS_AUDIT_WAVE_SIZE=1 \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$HOOK" 2>&1)
# If we get here without crashing, wave-size=1 path works
assert_exit "wave-size=1 doesn't crash" 0 $?

# ── Test 6: Empty diff → skip ──
bold "Test 6: Empty diff → skip"
# Use a clean temp git repo so git diff returns nothing
TEMP_REPO=$(mktemp -d)
git -C "$TEMP_REPO" init -q 2>/dev/null
git -C "$TEMP_REPO" -c user.name="test" -c user.email="test@test" commit --allow-empty -m "init" -q 2>/dev/null
OUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' \
  | CROSS_AUDIT_API_KEY="test" \
    CROSS_AUDIT_WAVE_SIZE=1 \
    CLAUDE_PROJECT_DIR="$TEMP_REPO" \
    bash "$HOOK" 2>&1)
rm -rf "$TEMP_REPO"
assert_empty "skips when diff is empty" "$OUT"

# ── Test 7: CROSS_AUDIT_FIRE override ──
bold "Test 7: CROSS_AUDIT_FIRE=true forces immediate audit"
OUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' \
  | CROSS_AUDIT_API_KEY="test" \
    CROSS_AUDIT_FIRE=true \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$HOOK" 2>&1)
# Should pass wave gate but stop at empty diff (no real diff)
assert_exit "FIRE override exits cleanly" 0 $?

# ── Test 9: Close Gate mode (holistic review) ──
bold "Test 8: Close Gate mode detection"
# Close Gate files should bypass wave counting and skip file exclusion
TEMP_REPO=$(mktemp -d)
git -C "$TEMP_REPO" init -q 2>/dev/null
git -C "$TEMP_REPO" -c user.name="test" -c user.email="test@test" commit --allow-empty -m "init" -q 2>/dev/null
# Create a dummy close gate file and a source change
echo "# Sprint Close Gate" > "$TEMP_REPO/S1_CLOSE_GATE.md"
echo "console.log('new feature')" > "$TEMP_REPO/app.js"
git -C "$TEMP_REPO" add -A 2>/dev/null
git -C "$TEMP_REPO" -c user.name="test" -c user.email="test@test" commit -m "sprint work" -q 2>/dev/null
# Add more changes so diff is non-empty against initial commit
echo "console.log('more changes')" >> "$TEMP_REPO/app.js"
git -C "$TEMP_REPO" add -A 2>/dev/null
OUT=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TEMP_REPO/S1_CLOSE_GATE.md\"}}" \
  | CROSS_AUDIT_API_KEY="test" \
    CLAUDE_PROJECT_DIR="$TEMP_REPO" \
    bash "$HOOK" 2>&1)
# Close gate should bypass wave counter (fire immediately) but fail at API call
# The key test is: it doesn't silently exit like a regular wave edit would
assert_exit "close-gate mode exits cleanly" 0 $?
rm -rf "$TEMP_REPO"

# ── Test 9: Entry Gate mode detection ──
bold "Test 9: Entry Gate mode detection"
TEMP_REPO=$(mktemp -d)
git -C "$TEMP_REPO" init -q 2>/dev/null
git -C "$TEMP_REPO" -c user.name="test" -c user.email="test@test" commit --allow-empty -m "init" -q 2>/dev/null
# Create entry gate with content
cat > "$TEMP_REPO/S2_ENTRY_GATE.md" << 'GEOF'
# Sprint 2 Entry Gate
## Items
- CORE-100: Add user auth
## Failure Modes
- Token expiry not handled
GEOF
OUT=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TEMP_REPO/S2_ENTRY_GATE.md\"}}" \
  | CROSS_AUDIT_API_KEY="test" \
    CLAUDE_PROJECT_DIR="$TEMP_REPO" \
    bash "$HOOK" 2>&1)
# Entry gate should bypass wave counter and use file content as diff
assert_exit "entry-gate mode exits cleanly" 0 $?
rm -rf "$TEMP_REPO"

# ── Test 10: Gate files skip wave counting ──
bold "Test 10: Gate files skip wave counting"
TEST_COUNTER="/tmp/.cross-audit-test-counter-gate-$$"
rm -f "$TEST_COUNTER"
echo "3" > "$TEST_COUNTER"
# In wave mode with counter at 3, a normal file would just increment to 4 and exit
# But a close gate file should bypass the counter entirely
TEMP_REPO=$(mktemp -d)
git -C "$TEMP_REPO" init -q 2>/dev/null
git -C "$TEMP_REPO" -c user.name="test" -c user.email="test@test" commit --allow-empty -m "init" -q 2>/dev/null
echo "change" > "$TEMP_REPO/app.js"
git -C "$TEMP_REPO" add -A 2>/dev/null
OUT=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TEMP_REPO/S1_CLOSE_GATE.md\"}}" \
  | CROSS_AUDIT_API_KEY="test" \
    CROSS_AUDIT_COUNTER_FILE="$TEST_COUNTER" \
    CLAUDE_PROJECT_DIR="$TEMP_REPO" \
    bash "$HOOK" 2>&1)
# Counter should NOT have been modified (gate bypasses wave counting)
if [[ -f "$TEST_COUNTER" ]]; then
  COUNT=$(cat "$TEST_COUNTER")
  if [[ "$COUNT" == "3" ]]; then
    green "  PASS: wave counter unchanged for gate file (still $COUNT)"
    PASSED=$((PASSED + 1))
  else
    red "  FAIL: wave counter changed to $COUNT, expected 3 (gate should bypass)"
    FAILED=$((FAILED + 1))
  fi
else
  red "  FAIL: counter file missing"
  FAILED=$((FAILED + 1))
fi
rm -f "$TEST_COUNTER"
rm -rf "$TEMP_REPO"

# ── Test 11: Wave-review mode (TRACKING.md triggers wave-review) ──
bold "Test 11: Wave-review mode on TRACKING.md edit"
TEMP_REPO=$(mktemp -d)
git -C "$TEMP_REPO" init -q 2>/dev/null
git -C "$TEMP_REPO" -c user.name="test" -c user.email="test@test" commit --allow-empty -m "init" -q 2>/dev/null
# Create source changes that would appear in a wave merge
echo "function newFeature() { return 42; }" > "$TEMP_REPO/feature.js"
git -C "$TEMP_REPO" add -A 2>/dev/null
git -C "$TEMP_REPO" -c user.name="test" -c user.email="test@test" commit -m "wave merge" -q 2>/dev/null
# Create TRACKING.md (coordinator updating after merge)
echo "| CORE-100 | Auth | fixed | ✓ |" > "$TEMP_REPO/TRACKING.md"
OUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TEMP_REPO/TRACKING.md\"}}" \
  | CROSS_AUDIT_API_KEY="test" \
    CLAUDE_PROJECT_DIR="$TEMP_REPO" \
    bash "$HOOK" 2>&1)
# Wave-review should bypass wave counter and attempt audit (will fail at API call, that's ok)
assert_exit "wave-review mode exits cleanly" 0 $?
rm -rf "$TEMP_REPO"

# ── Test 12: Wave-review skips when no code changes ──
bold "Test 12: Wave-review skips when no code changes in diff"
TEMP_REPO=$(mktemp -d)
git -C "$TEMP_REPO" init -q 2>/dev/null
git -C "$TEMP_REPO" -c user.name="test" -c user.email="test@test" commit --allow-empty -m "init" -q 2>/dev/null
# No source changes — only TRACKING.md
echo "| CORE-100 | Auth | in_progress | |" > "$TEMP_REPO/TRACKING.md"
OUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$TEMP_REPO/TRACKING.md\"}}" \
  | CROSS_AUDIT_API_KEY="test" \
    CLAUDE_PROJECT_DIR="$TEMP_REPO" \
    bash "$HOOK" 2>&1)
assert_exit "wave-review skips when no code diff" 0 $?
assert_empty "no output for empty wave diff" "$OUT"
rm -rf "$TEMP_REPO"

# ── Test 13: Audit log is created on skip ──
bold "Test 13: Audit log is created (P0)"
TEMP_REPO=$(mktemp -d)
git -C "$TEMP_REPO" init -q 2>/dev/null
git -C "$TEMP_REPO" -c user.name="test" -c user.email="test@test" commit --allow-empty -m "init" -q 2>/dev/null
TEST_STATE_DIR="$TEMP_REPO/.claude/.state"
mkdir -p "$TEST_STATE_DIR"
TEST_LOG="$TEST_STATE_DIR/cross-audit-log.jsonl"
OUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' \
  | CROSS_AUDIT_API_KEY="test" \
    CROSS_AUDIT_WAVE_SIZE=1 \
    CLAUDE_PROJECT_DIR="$TEMP_REPO" \
    bash "$HOOK" 2>&1)
if [[ -f "$TEST_LOG" ]]; then
  LAST_STATUS=$(tail -1 "$TEST_LOG" | jq -r '.status' 2>/dev/null)
  if [[ "$LAST_STATUS" == "skip" ]]; then
    green "  PASS: audit log records skip events"
    PASSED=$((PASSED + 1))
  else
    red "  FAIL: log status is '$LAST_STATUS', expected 'skip'"
    FAILED=$((FAILED + 1))
  fi
else
  red "  FAIL: audit log not created at $TEST_LOG"
  FAILED=$((FAILED + 1))
fi
rm -rf "$TEMP_REPO"

# ── Test 14: verify-evidence.sh validates file:line refs ──
bold "Test 14: Evidence verification script (P3)"
TEMP_REPO=$(mktemp -d)
mkdir -p "$TEMP_REPO/src"
# Create a 50-line file
for i in $(seq 1 50); do echo "line $i content" >> "$TEMP_REPO/src/app.ts"; done
# Create a mock agent report with valid and invalid refs
REPORT="## Agent Report
AC1: src/app.ts:10 — implemented feature
AC2: src/nonexistent.ts:5 — missing file
AC3: src/app.ts:999 — out of range"
EXIT_CODE=0
OUT=$(echo "$REPORT" | CLAUDE_PROJECT_DIR="$TEMP_REPO" bash "$SCRIPT_DIR/verify-evidence.sh" 2>&1) || EXIT_CODE=$?
if [[ $EXIT_CODE -eq 1 ]]; then
  green "  PASS: verify-evidence detects invalid references (exit=1)"
  PASSED=$((PASSED + 1))
else
  red "  FAIL: verify-evidence should exit 1 for invalid refs (got exit=$EXIT_CODE)"
  FAILED=$((FAILED + 1))
fi
# Test with only valid refs
REPORT2="## Agent Report
AC1: src/app.ts:10 — implemented feature
AC2: src/app.ts:25 — another feature"
OUT=$(echo "$REPORT2" | CLAUDE_PROJECT_DIR="$TEMP_REPO" bash "$SCRIPT_DIR/verify-evidence.sh" 2>&1)
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
  green "  PASS: verify-evidence accepts valid references (exit=0)"
  PASSED=$((PASSED + 1))
else
  red "  FAIL: verify-evidence should exit 0 for valid refs (got exit=$EXIT_CODE)"
  FAILED=$((FAILED + 1))
fi
rm -rf "$TEMP_REPO"

# ══════════════════════════════════════════
# Dual Review Tests
# ══════════════════════════════════════════
bold "═══ Dual Review Tests ═══"
echo ""

# ── Test 15: Review protocol config accepted without error ──
bold "Test 15: Review protocol config accepted"
OUT=$(echo '{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}' \
  | CROSS_AUDIT_API_KEY="test" \
    CROSS_AUDIT_WAVE_SIZE=1 \
    CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
    bash "$HOOK" 2>&1)
assert_exit "review protocol config accepted without error" 0 $?

# ── Test 16: Core audit config variables have valid defaults ──
bold "Test 16: Core audit config defaults from hooks-config.sh"
if [[ -f "$PROJECT_DIR/.claude/hooks-config.sh" ]]; then
  WAVE_VAL=$(bash -c "source '$PROJECT_DIR/.claude/hooks-config.sh' 2>/dev/null; echo \"\${CROSS_AUDIT_WAVE_SIZE:-MISSING}\"")
  ENFORCE_VAL=$(bash -c "source '$PROJECT_DIR/.claude/hooks-config.sh' 2>/dev/null; echo \"\${CROSS_AUDIT_ENFORCE_BLOCK:-MISSING}\"")
  ALL_SET=true
  for var_name in WAVE_VAL ENFORCE_VAL; do
    val="${!var_name}"
    if [[ "$val" == "MISSING" ]]; then
      red "  FAIL: $var_name not set in hooks-config.sh"
      FAILED=$((FAILED + 1))
      ALL_SET=false
    fi
  done
  if [[ "$ALL_SET" == "true" ]]; then
    green "  PASS: core audit config vars have defaults (WAVE=$WAVE_VAL, ENFORCE=$ENFORCE_VAL)"
    PASSED=$((PASSED + 1))
  fi
else
  red "  FAIL: hooks-config.sh not found"
  FAILED=$((FAILED + 1))
fi

# ── Test 17: Self-audit checklist is embedded in hook ──
bold "Test 17: Self-audit checklist is embedded in hook"
if grep -q "SELF-AUDIT CHECKLIST" "$HOOK"; then
  green "  PASS: self-audit checklist found in hook"
  PASSED=$((PASSED + 1))
else
  red "  FAIL: self-audit checklist not found in hook"
  FAILED=$((FAILED + 1))
fi

# ── Test 18: Review protocol directive exists in hook ──
bold "Test 18: Review protocol directive in hook"
if grep -q "structured self-audit" "$HOOK"; then
  green "  PASS: review protocol directive found"
  PASSED=$((PASSED + 1))
else
  red "  FAIL: review protocol directive not found"
  FAILED=$((FAILED + 1))
fi

# ── Test 19: Workflow mode is injected into additionalContext ──
bold "Test 19: Workflow-Mode in additionalContext output"
if grep -q 'wfmode' "$HOOK" && grep -q 'WORKFLOW_MODE' "$HOOK"; then
  green "  PASS: workflow mode is passed to additionalContext"
  PASSED=$((PASSED + 1))
else
  red "  FAIL: workflow mode not found in additionalContext output"
  FAILED=$((FAILED + 1))
fi

# ── Test 20: Audit log structure in _audit-lib.sh ──
bold "Test 20: audit log has mode field in _audit-lib.sh"
if grep -q 'mode' "$SCRIPT_DIR/_audit-lib.sh"; then
  green "  PASS: mode field found in _audit-lib.sh"
  PASSED=$((PASSED + 1))
else
  red "  FAIL: mode field not found in _audit-lib.sh"
  FAILED=$((FAILED + 1))
fi

# ══════════════════════════════════════════
# Live test (optional)
# ══════════════════════════════════════════
if [[ "$LIVE_MODE" == "--live" ]]; then
  echo ""
  bold "═══ LIVE API TEST ═══"

  # Load .env the same way the hook does (shell env takes precedence)
  _ENV_FILE="${PROJECT_DIR}/.env"
  if [[ -f "$_ENV_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      key="${line%%=*}"
      value="${line#*=}"
      key=$(echo "$key" | sed 's/^[[:space:]]*export[[:space:]]*//' | tr -d '[:space:]')
      value=$(echo "$value" | sed -E 's/[[:space:]]+#.*$//; s/^[[:space:]]*["'"'"']?//; s/["'"'"']?[[:space:]]*$//')
      if [[ "$key" == CROSS_AUDIT_* ]]; then
        [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
        _cur_val=$(printenv "$key" 2>/dev/null || true)
        [[ -z "$_cur_val" ]] && export "$key=$value"
      fi
    done < "$_ENV_FILE"
    echo "  Loaded cross-audit config from .env"
  fi

  if [[ -z "${CROSS_AUDIT_API_KEY:-}" ]]; then
    red "SKIP: CROSS_AUDIT_API_KEY not set."
    red "  Option 1: Run  bash .claude/setup-audit.sh  to create .env"
    red "  Option 2: export CROSS_AUDIT_API_KEY=\"your-key\" before running this script"
  else
    echo "Creating temporary test change..."

    # Create a temp file with a deliberate bug
    TEMP_FILE="$PROJECT_DIR/_cross_audit_test_temp.py"
    cat > "$TEMP_FILE" << 'PYEOF'
import os
import subprocess

def run_command(user_input):
    # BUG: command injection vulnerability
    result = subprocess.run(f"echo {user_input}", shell=True, capture_output=True)
    return result.stdout.decode()

def get_config():
    password = "admin123"  # BUG: hardcoded credential
    return {"db_host": "localhost", "password": password}

def process_data(items):
    # BUG: no input validation
    for item in items:
        eval(item["expression"])  # BUG: eval on user input
PYEOF

    git -C "$PROJECT_DIR" add "$TEMP_FILE" 2>/dev/null

    bold "Sending to ${CROSS_AUDIT_API_BASE:-https://api.openai.com/v1} (model: ${CROSS_AUDIT_MODEL:-gpt-4o})..."

    OUT=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$TEMP_FILE\"}}" \
      | CROSS_AUDIT_WAVE_SIZE=1 \
        CLAUDE_PROJECT_DIR="$PROJECT_DIR" \
        bash "$HOOK" 2>&1)

    if echo "$OUT" | jq -r '.additionalContext' 2>/dev/null | grep -q "CROSS-LLM AUDIT"; then
      green "  PASS: Got audit response!"
      echo ""
      echo "--- Response ---"
      echo "$OUT" | jq -r '.additionalContext' 2>/dev/null
      echo "--- End ---"
      PASSED=$((PASSED + 1))
    else
      red "  FAIL: No valid audit response"
      echo "Raw output: ${OUT:0:500}"
      FAILED=$((FAILED + 1))
    fi

    # Cleanup
    git -C "$PROJECT_DIR" reset HEAD "$TEMP_FILE" 2>/dev/null || true
    rm -f "$TEMP_FILE"
  fi
fi

# ══════════════════════════════════════════
echo ""
bold "═══ Results ═══"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[[ $FAILED -gt 0 ]] && { red "SOME TESTS FAILED"; exit 1; }
green "ALL TESTS PASSED"
exit 0
