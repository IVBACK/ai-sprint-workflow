#!/usr/bin/env bash
# checks/typescript-react.sh — TypeScript/React audit checks
#
# Source this file from sprint-audit.sh when EXT=ts or tsx.
# Requires: common.sh sourced first, SRC_DIR and EXT set.

echo ""
echo "── TypeScript/React Checks ──"

# Hot path allocations
check "HOT_ALLOC" "new Array(\|\\.\\.\\."

# Cached reference violations
check "UNCACHED" "document\\.querySelector\|document\\.getElementById"

# Framework anti-patterns
check "ANTIPATTERN" "dangerouslySetInnerHTML\|innerHTML"

# Type safety
check "TYPE_SAFETY" "as any\|: any"

# Resource guard — open handles
check "RESOURCE" "createReadStream\|createWriteStream\|new WebSocket"

# String allocations (template literals in hot paths — manual review needed)
# check "STRING_ALLOC" — not reliably grep-detectable in TS
