#!/usr/bin/env bash
# checks/go.sh — Go audit checks
#
# Source this file from sprint-audit.sh when EXT=go.
# Requires: common.sh sourced first, SRC_DIR and EXT set.

echo ""
echo "── Go Checks ──"

# Hot path allocations
check "HOT_ALLOC" "make(\\[\\]\|make(map"

# Framework anti-patterns
check "ANTIPATTERN" "panic(\|log\\.Fatal("

# Resource guard — unclosed handles
check "RESOURCE" "os\\.Open(\|sql\\.Open("

# Cached reference violations
check "UNCACHED" "os\\.Getenv("

# String allocations
check "STRING_ALLOC" "fmt\\.Sprintf("
