#!/usr/bin/env bash
# checks/python.sh — Python audit checks
#
# Source this file from sprint-audit.sh when EXT=py.
# Requires: common.sh sourced first, SRC_DIR and EXT set.

echo ""
echo "── Python Checks ──"

# Framework anti-patterns
check "ANTIPATTERN" "eval(\|exec(\|__import__"

# Bare except (catches too broadly)
check "BARE_EXCEPT" "except:"

# Resource guard — unclosed file/connection handles
check "RESOURCE" "open(\|sqlite3\\.connect(\|psycopg2\\.connect("

# Cached reference violations
check "UNCACHED" "os\\.path\\.exists\|os\\.path\\.isfile\|os\\.path\\.isdir"

# String allocations (f-strings in hot loops — hard to grep, flagged for review)
check "STRING_ALLOC" "f'\|f\""

# Type hints missing (optional — uncomment if enforced)
# check "TYPE_HINT" "def .*[^)]:" — too noisy, prefer mypy
