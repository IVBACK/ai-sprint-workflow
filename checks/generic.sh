#!/usr/bin/env bash
# checks/generic.sh — Language-agnostic audit checks
#
# Always sourced by sprint-audit.sh. Runs checks that apply to any language.
# Requires: common.sh sourced first, SRC_DIR and EXT set.

echo ""
echo "── Generic Checks ──"

# Scaffolding tags (language-agnostic — works with any comment style)
check "SCAFFOLDING" "TODO\|HACK\|FIXME\|TEMP(S"

# Contract violations (project-specific — add your forbidden patterns)
# check "CONTRACT" "forbidden_function_name\|deprecated_api"
