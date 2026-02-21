#!/usr/bin/env bash
# checks/cpp.sh — C++ audit checks
#
# Source this file from sprint-audit.sh when EXT=cpp or hpp.
# Requires: common.sh sourced first, SRC_DIR and EXT set.

echo ""
echo "── C++ Checks ──"

# Hot path allocations
check "HOT_ALLOC" "new \|malloc(\|calloc("

# Framework anti-patterns
check "ANTIPATTERN" "reinterpret_cast\|const_cast"

# Resource guard — raw new without smart pointer
check "RESOURCE" "new std::\|fopen("

# Cached reference violations
check "UNCACHED" "dynamic_cast"

# Raw pointer usage (prefer smart pointers)
check "RAW_PTR" "\\* ="
