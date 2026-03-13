#!/usr/bin/env bash
# Test suite for protect-secrets.sh hook
# Run: bash Tools/test-protect-secrets.sh

set -uo pipefail

HOOK=".claude/hooks/protect-secrets.sh"
PASS=0
FAIL=0

test_case() {
    local description="$1"
    local input="$2"
    local expected_exit="$3"  # 0 = allowed, 2 = blocked

    actual_exit=0
    echo "$input" | bash "$HOOK" >/dev/null 2>/dev/null || actual_exit=$?

    if [[ "$actual_exit" -eq "$expected_exit" ]]; then
        echo "  PASS: $description (exit=$actual_exit)"
        ((PASS++))
    else
        echo "  FAIL: $description (expected exit=$expected_exit, got exit=$actual_exit)"
        ((FAIL++))
    fi
}

echo "=== protect-secrets.sh Test Suite ==="
echo ""

echo "-- Read tool tests --"
test_case "Block Read .env" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/.env"}}' 2

test_case "Block Read .env.local" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/.env.local"}}' 2

test_case "Block Read .env.production" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/.env.production"}}' 2

test_case "Block Read server.key" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/certs/server.key"}}' 2

test_case "Block Read cert.pem" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/cert.pem"}}' 2

test_case "Block Read credentials.json" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/credentials.json"}}' 2

test_case "Block Read secrets.yaml" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/secrets.yaml"}}' 2

test_case "Allow Read .env.example" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/.env.example"}}' 0

test_case "Allow Read src/index.ts" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/src/index.ts"}}' 0

test_case "Allow Read package.json" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/package.json"}}' 0

test_case "Allow Read CLAUDE.md" \
    '{"tool_name":"Read","tool_input":{"file_path":"/project/CLAUDE.md"}}' 0

echo ""
echo "-- Bash tool tests --"
test_case "Block cat .env" \
    '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}' 2

test_case "Block head .env" \
    '{"tool_name":"Bash","tool_input":{"command":"head -5 .env"}}' 2

test_case "Block source .env" \
    '{"tool_name":"Bash","tool_input":{"command":"source .env"}}' 2

test_case "Block cat server.key" \
    '{"tool_name":"Bash","tool_input":{"command":"cat /etc/ssl/server.key"}}' 2

test_case "Block echo \$CROSS_AUDIT_API_KEY" \
    '{"tool_name":"Bash","tool_input":{"command":"echo $CROSS_AUDIT_API_KEY"}}' 2

test_case "Block printenv CROSS_AUDIT_API_KEY" \
    '{"tool_name":"Bash","tool_input":{"command":"printenv CROSS_AUDIT_API_KEY"}}' 2

test_case "Allow npm install" \
    '{"tool_name":"Bash","tool_input":{"command":"npm install"}}' 0

test_case "Allow git status" \
    '{"tool_name":"Bash","tool_input":{"command":"git status"}}' 0

test_case "Allow ls -la" \
    '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' 0

test_case "Allow grep in source files" \
    '{"tool_name":"Bash","tool_input":{"command":"grep -r TODO src/"}}' 0

echo ""
echo "-- Edge cases --"
test_case "Allow Edit tool (not hooked)" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/.env"}}' 0

test_case "Allow Write tool (not hooked here)" \
    '{"tool_name":"Write","tool_input":{"file_path":"/project/src/app.ts"}}' 0

test_case "Block cat .env in pipeline" \
    '{"tool_name":"Bash","tool_input":{"command":"cat .env | grep KEY"}}' 2

test_case "Block less credentials.json" \
    '{"tool_name":"Bash","tool_input":{"command":"less credentials.json"}}' 2

echo ""
echo "-- Bypass prevention --"
test_case "Block python3 read .env" \
    '{"tool_name":"Bash","tool_input":{"command":"python3 -c \"open('"'"'.env'"'"').read()\""}}' 2

test_case "Block base64 .env" \
    '{"tool_name":"Bash","tool_input":{"command":"base64 .env"}}' 2

test_case "Block awk .env" \
    '{"tool_name":"Bash","tool_input":{"command":"awk \"{print}\" .env"}}' 2

test_case "Block grep .env content" \
    '{"tool_name":"Bash","tool_input":{"command":"grep KEY .env"}}' 2

test_case "Block sed .env" \
    '{"tool_name":"Bash","tool_input":{"command":"sed -n p .env"}}' 2

test_case "Block redirect < .env" \
    '{"tool_name":"Bash","tool_input":{"command":"while read line; do echo $line; done < .env"}}' 2

test_case "Block node .env read" \
    '{"tool_name":"Bash","tool_input":{"command":"node -e \"require('"'"'fs'"'"').readFileSync('"'"'.env'"'"')\""}}' 2

test_case "Allow ls .env (safe — shows metadata not content)" \
    '{"tool_name":"Bash","tool_input":{"command":"ls -la .env"}}' 0

test_case "Allow test -f .env (safe — existence check only)" \
    '{"tool_name":"Bash","tool_input":{"command":"test -f .env && echo exists"}}' 0

test_case "Allow wc -l .env (safe — line count only)" \
    '{"tool_name":"Bash","tool_input":{"command":"wc -l .env"}}' 0

test_case "Allow cat .env.example (template, no secrets)" \
    '{"tool_name":"Bash","tool_input":{"command":"cat .env.example"}}' 0

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed (total: $((PASS + FAIL)))"
if [[ "$FAIL" -gt 0 ]]; then
    echo "STATUS: SOME TESTS FAILED"
    exit 1
else
    echo "STATUS: ALL TESTS PASSED"
    exit 0
fi
