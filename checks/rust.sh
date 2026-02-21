#!/usr/bin/env bash
# checks/rust.sh — Rust audit checks
#
# Source this file from sprint-audit.sh when EXT=rs.
# Requires: common.sh sourced first, SRC_DIR and EXT set.

echo ""
echo "── Rust Checks ──"

# Hot path allocations
check "HOT_ALLOC" "\\.clone()\|Vec::new()\|Box::new("

# Framework anti-patterns
check "ANTIPATTERN" "unsafe {"

# Cached reference violations
check "UNCACHED" "\\.unwrap()"

# Resource guard — not typically needed (RAII), but flag manual drops
check "RESOURCE" "std::mem::forget\|ManuallyDrop"
