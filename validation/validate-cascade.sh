#!/usr/bin/env bash
# validate-cascade.sh — Version and cross-file consistency checks.
#
# Validates that version numbers, hook counts, and templates are consistent
# across WORKFLOW.md, hooks-config.sh, session-start.sh, README.md, DESIGN.md,
# and WORKFLOW-MODES.md.
#
# Usage:
#   ./validate-cascade.sh
#
# Exit codes:
#   0 = All checks pass
#   1 = Warnings exist (non-blocking)
#   2 = Failures exist (blocking — real inconsistencies)
#
# Dependencies: GNU bash 4+, grep, sed, head

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKFLOW="$REPO_ROOT/WORKFLOW.md"
README="$REPO_ROOT/README.md"
DESIGN="$REPO_ROOT/DESIGN.md"
MODES="$REPO_ROOT/Docs/WORKFLOW-MODES.md"
HOOKS_CONFIG="$REPO_ROOT/.claude/hooks-config.sh"
SESSION_START="$REPO_ROOT/.claude/hooks/session-start.sh"
SETTINGS_JSON="$REPO_ROOT/.claude/settings.json"

passes=0
warnings=0
failures=0

pass() {
  local name="$1"
  echo "  PASS  [$name]"
  passes=$((passes + 1))
}

warn() {
  local name="$1"; shift
  echo "  WARN  [$name] $*"
  warnings=$((warnings + 1))
}

fail() {
  local name="$1"; shift
  echo "  FAIL  [$name] $*"
  failures=$((failures + 1))
}

# ── Pre-flight ──
echo "Validating cascade consistency..."
preflight_ok=true
for f in "$WORKFLOW" "$README" "$DESIGN"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR  Required file not found: $f"
    preflight_ok=false
  fi
done
if ! $preflight_ok; then
  exit 2
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 1: Version Consistency
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 1: Version Consistency"
echo "══════════════════════════════════════════════════════"

# 1.1 WORKFLOW.md has workflow-version comment
WF_VERSION=$(head -5 "$WORKFLOW" | sed -n 's/.*workflow-version: *\([0-9.]*\).*/\1/p')
if [[ -n "$WF_VERSION" ]]; then
  pass "1.1 WORKFLOW.md has workflow-version: $WF_VERSION"
else
  fail "1.1 WORKFLOW.md missing <!-- workflow-version: X.Y --> in first 5 lines"
fi

# 1.2 Changelog top entry matches workflow-version
CHANGELOG_VERSION=$(grep -m1 '^### v' "$WORKFLOW" | sed 's/### v\([0-9.]*\).*/\1/' | head -1)
if [[ -z "$CHANGELOG_VERSION" ]]; then
  # Changelog might be at the bottom — search from end
  CHANGELOG_VERSION=$(tac "$WORKFLOW" | grep -m1 '^### v' | sed 's/### v\([0-9.]*\).*/\1/')
fi
# Actually search in the Changelog section specifically
CHANGELOG_VERSION=$(sed -n '/^## Changelog/,$ p' "$WORKFLOW" | grep -m1 '^### v' | sed 's/### v\([0-9.]*\).*/\1/')
if [[ -n "$CHANGELOG_VERSION" && "$CHANGELOG_VERSION" == "$WF_VERSION" ]]; then
  pass "1.2 Changelog top version ($CHANGELOG_VERSION) matches workflow-version ($WF_VERSION)"
elif [[ -n "$CHANGELOG_VERSION" ]]; then
  fail "1.2 Changelog top version ($CHANGELOG_VERSION) != workflow-version ($WF_VERSION)"
else
  fail "1.2 No changelog version found (missing ## Changelog section or ### vX.Y entries)"
fi

# 1.3 hooks-config.sh HOOKS_VERSION matches
if [[ -f "$HOOKS_CONFIG" ]]; then
  HK_VERSION=$(grep '^HOOKS_VERSION=' "$HOOKS_CONFIG" | head -1 | sed 's/HOOKS_VERSION="\(.*\)"/\1/')
  if [[ -n "$HK_VERSION" && "$HK_VERSION" == "$WF_VERSION" ]]; then
    pass "1.3 hooks-config.sh HOOKS_VERSION ($HK_VERSION) matches workflow-version ($WF_VERSION)"
  elif [[ -n "$HK_VERSION" ]]; then
    fail "1.3 hooks-config.sh HOOKS_VERSION ($HK_VERSION) != workflow-version ($WF_VERSION)"
  else
    fail "1.3 hooks-config.sh missing HOOKS_VERSION"
  fi
else
  warn "1.3 hooks-config.sh not found (ok if not bootstrapped)"
fi

# 1.4 hooks-config.sh template in WORKFLOW.md has matching HOOKS_VERSION
TEMPLATE_HK=$(grep -A9999 '^### Claude Code Hook Templates' "$WORKFLOW" \
  | grep 'HOOKS_VERSION=' | head -1 | sed 's/.*HOOKS_VERSION="\(.*\)".*/\1/')
if [[ -n "$TEMPLATE_HK" && "$TEMPLATE_HK" == "$WF_VERSION" ]]; then
  pass "1.4 WORKFLOW.md hooks-config template HOOKS_VERSION ($TEMPLATE_HK) matches"
elif [[ -n "$TEMPLATE_HK" ]]; then
  fail "1.4 WORKFLOW.md hooks-config template HOOKS_VERSION ($TEMPLATE_HK) != workflow-version ($WF_VERSION)"
else
  warn "1.4 HOOKS_VERSION not found in WORKFLOW.md hooks-config template"
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 2: Hook Count Consistency
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 2: Hook Count Consistency"
echo "══════════════════════════════════════════════════════"

# Count actual enforcer hooks registered in settings.json (exclude cross-llm-audit which is optional)
if [[ -f "$SETTINGS_JSON" ]]; then
  ACTUAL_HOOKS=$(grep -o 'hooks/[a-z-]*\.sh' "$SETTINGS_JSON" | sort -u | grep -v 'cross-llm-audit' | wc -l)
  ACTUAL_HOOKS_TOTAL=$(grep -o 'hooks/[a-z-]*\.sh' "$SETTINGS_JSON" | sort -u | wc -l)
else
  ACTUAL_HOOKS=0
  ACTUAL_HOOKS_TOTAL=0
fi

# Count hook flags in hooks-config.sh (HOOK_* variables, not HOOKS_VERSION)
if [[ -f "$HOOKS_CONFIG" ]]; then
  CONFIG_HOOKS=$(grep -c '^HOOK_[A-Z_]*=.*\$' "$HOOKS_CONFIG" || true)
else
  CONFIG_HOOKS=0
fi

# 2.1 README hook counts — look specifically in the Workflow Modes table
# Pattern: "Core safety (N/N)" or "All hooks (N/N)" in mode table rows
README_LITE=$(grep -oP '\d+/\d+' "$README" | head -1)
README_FULL=$(grep -oP '\(\d+/\d+\)' "$README" | tail -1 | tr -d '()')
if [[ -z "$README_FULL" ]]; then
  README_FULL=$(grep -oP '\d+/\d+' "$README" | tail -1)
fi
if [[ -n "$README_LITE" ]]; then
  LITE_N=$(echo "$README_LITE" | cut -d/ -f1)
  FULL_N=$(echo "$README_FULL" | cut -d/ -f2)
  # Verify FULL_N matches enforcer hooks in settings.json (not including optional cross-llm-audit)
  if [[ "$ACTUAL_HOOKS" -gt 0 && "$FULL_N" != "$ACTUAL_HOOKS" ]]; then
    fail "2.1a README full hook count ($FULL_N) != settings.json enforcer hooks ($ACTUAL_HOOKS) [total with optional: $ACTUAL_HOOKS_TOTAL]"
  else
    pass "2.1a README full hook count ($FULL_N) consistent with settings.json enforcer hooks ($ACTUAL_HOOKS)"
  fi
  # Verify CONFIG_HOOKS matches
  if [[ "$CONFIG_HOOKS" -gt 0 && "$FULL_N" != "$CONFIG_HOOKS" ]]; then
    fail "2.1b README full hook count ($FULL_N) != hooks-config.sh flag count ($CONFIG_HOOKS)"
  else
    pass "2.1b README full hook count ($FULL_N) consistent with hooks-config.sh flags ($CONFIG_HOOKS)"
  fi
else
  warn "2.1 No hook count pattern (N/N) found in README"
fi

# 2.2 WORKFLOW-MODES.md hook counts
if [[ -f "$MODES" ]]; then
  MODES_LITE=$(grep -oP '\d+/\d+' "$MODES" | head -1)
  MODES_FULL=$(grep -oP '\d+/\d+' "$MODES" | tail -1)
  if [[ "$MODES_LITE" == "$README_LITE" && "$MODES_FULL" == "$README_FULL" ]]; then
    pass "2.2 WORKFLOW-MODES.md hook counts match README ($MODES_LITE, $MODES_FULL)"
  else
    fail "2.2 WORKFLOW-MODES.md hook counts ($MODES_LITE, $MODES_FULL) != README ($README_LITE, $README_FULL)"
  fi
else
  warn "2.2 WORKFLOW-MODES.md not found"
fi

# 2.3 DESIGN.md hook counts — only match N/N patterns near "hook" or "Lite" context
DESIGN_HOOK_COUNTS=$(grep -i 'hook\|lite\|standard\|strict' "$DESIGN" | grep -oP '\d+/\d+' | sort -u)
if [[ -n "$DESIGN_HOOK_COUNTS" ]]; then
  design_ok=true
  while IFS= read -r count; do
    if [[ "$count" != "$README_LITE" && "$count" != "$README_FULL" ]]; then
      # Check if this is actually a hook count (not a phase number like 2/4)
      num=$(echo "$count" | cut -d/ -f2)
      if [[ "$num" -ge 5 ]]; then
        design_ok=false
        fail "2.3 DESIGN.md has unexpected hook count: $count (expected $README_LITE or $README_FULL)"
      fi
    fi
  done <<< "$DESIGN_HOOK_COUNTS"
  if $design_ok; then
    pass "2.3 DESIGN.md hook counts match README"
  fi
else
  warn "2.3 No hook count pattern found in DESIGN.md near hook references"
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 3: Template Sync (critical blocks)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 3: Template Sync"
echo "══════════════════════════════════════════════════════"

# 3.1 session-start.sh has version mismatch detection
if [[ -f "$SESSION_START" ]]; then
  if grep -q 'VERSION_WARNING' "$SESSION_START" && grep -q 'HOOKS_VERSION' "$SESSION_START"; then
    pass "3.1 session-start.sh has version mismatch detection"
  else
    fail "3.1 session-start.sh missing version mismatch detection (VERSION_WARNING / HOOKS_VERSION)"
  fi
else
  warn "3.1 session-start.sh not found"
fi

# 3.2 session-start.sh template in WORKFLOW.md has version mismatch detection
# Search from Hook Templates heading to end of file for VERSION_WARNING
# Use grep -c to check count (avoids pipefail issues with piped commands)
_vw_count=$(awk '/^### Claude Code Hook Templates/,0' "$WORKFLOW" | grep -c 'VERSION_WARNING' || true)
if [[ "$_vw_count" -gt 0 ]]; then
  pass "3.2 WORKFLOW.md session-start.sh template has version mismatch detection"
else
  fail "3.2 WORKFLOW.md session-start.sh template missing version mismatch detection"
fi

# 3.3 hooks-config.sh has HOOK_PROTECT_SECRETS
if [[ -f "$HOOKS_CONFIG" ]]; then
  if grep -q 'HOOK_PROTECT_SECRETS' "$HOOKS_CONFIG"; then
    pass "3.3 hooks-config.sh has HOOK_PROTECT_SECRETS"
  else
    fail "3.3 hooks-config.sh missing HOOK_PROTECT_SECRETS"
  fi
else
  warn "3.3 hooks-config.sh not found"
fi

# 3.4 WORKFLOW.md hooks-config template has HOOK_PROTECT_SECRETS
# Use grep -c instead of grep -q to avoid SIGPIPE with pipefail (grep -q closes pipe early)
if [[ $(sed -n '/^### Claude Code Hook Templates/,/^### /p' "$WORKFLOW" | grep -c 'HOOK_PROTECT_SECRETS') -gt 0 ]]; then
  pass "3.4 WORKFLOW.md hooks-config template has HOOK_PROTECT_SECRETS"
else
  fail "3.4 WORKFLOW.md hooks-config template missing HOOK_PROTECT_SECRETS"
fi

# 3.5 protect-secrets.sh is registered in settings.json
if [[ -f "$SETTINGS_JSON" ]]; then
  if grep -q 'protect-secrets.sh' "$SETTINGS_JSON"; then
    pass "3.5 protect-secrets.sh registered in settings.json"
  else
    fail "3.5 protect-secrets.sh NOT registered in settings.json"
  fi
else
  warn "3.5 settings.json not found"
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 4: Cross-File References
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 4: Cross-File References"
echo "══════════════════════════════════════════════════════"

# 4.1 README references §Upgrade
if grep -q 'Upgrade\|upgrade' "$README" && grep -q 'workflow-version' "$README"; then
  pass "4.1 README references upgrade/version system"
else
  fail "4.1 README missing upgrade/version system reference"
fi

# 4.2 DESIGN.md has version system design decision
if grep -qi 'version system\|AI-driven upgrade' "$DESIGN"; then
  pass "4.2 DESIGN.md has version system design decision"
else
  fail "4.2 DESIGN.md missing version system design decision"
fi

# 4.3 WORKFLOW.md has Upgrade section
if grep -q '^## Upgrade' "$WORKFLOW"; then
  pass "4.3 WORKFLOW.md has §Upgrade section"
else
  fail "4.3 WORKFLOW.md missing §Upgrade section"
fi

# 4.4 WORKFLOW.md has Changelog section
if grep -q '^## Changelog' "$WORKFLOW"; then
  pass "4.4 WORKFLOW.md has §Changelog section"
else
  fail "4.4 WORKFLOW.md missing §Changelog section"
fi

# 4.5 .gitignore has secret file patterns
GITIGNORE="$REPO_ROOT/.gitignore"
if [[ -f "$GITIGNORE" ]]; then
  missing_patterns=()
  for pat in ".env" "*.key" "*.pem" "credentials.json"; do
    if ! grep -qF "$pat" "$GITIGNORE"; then
      missing_patterns+=("$pat")
    fi
  done
  if [[ ${#missing_patterns[@]} -eq 0 ]]; then
    pass "4.5 .gitignore has all secret file patterns"
  else
    fail "4.5 .gitignore missing patterns: ${missing_patterns[*]}"
  fi
else
  warn "4.5 .gitignore not found"
fi

# ═══════════════════════════════════════════════════════════════
#  Summary
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
total=$((passes + warnings + failures))
echo "  Cascade check: $total checks — $passes pass, $warnings warn, $failures fail"
echo "══════════════════════════════════════════════════════"

if [[ $failures -gt 0 ]]; then
  exit 2
elif [[ $warnings -gt 0 ]]; then
  exit 1
else
  exit 0
fi
