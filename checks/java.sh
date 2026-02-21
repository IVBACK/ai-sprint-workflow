#!/usr/bin/env bash
# checks/java.sh — Java audit checks
#
# Source this file from sprint-audit.sh when EXT=java.
# Requires: common.sh sourced first, SRC_DIR and EXT set.

echo ""
echo "── Java Checks ──"

# Hot path allocations
check "HOT_ALLOC" "new ArrayList<\|new HashMap<\|new HashSet<"

# Framework anti-patterns
check "ANTIPATTERN" "e\\.printStackTrace(\|System\\.out\\.print"

# Resource guard — unclosed streams/connections
check "RESOURCE" "new FileInputStream\|new BufferedReader\|DriverManager\\.getConnection"

# Cached reference violations (Spring)
check "UNCACHED" "getBean(\|getEnvironment()"

# String allocations
check "STRING_ALLOC" "\" +\|String\\.format("
