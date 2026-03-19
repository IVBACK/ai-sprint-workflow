#!/usr/bin/env bash
# resolve-workflow.sh — Provides WORKFLOW variable for validation scripts.
# Supports both monolithic WORKFLOW.md and split Docs/Workflow/ layout.
#
# Usage (source from validation scripts):
#   source "$REPO_ROOT/validation/resolve-workflow.sh"
#   WORKFLOW=$(resolve_workflow "$REPO_ROOT")
#
# When split layout exists (Docs/Workflow/), concatenates all files into
# a temp file so existing grep/sed patterns continue to work unchanged.
# Caller is responsible for cleanup (trap on EXIT recommended).

resolve_workflow() {
    local repo_root="$1"
    local workflow_dir="$repo_root/Docs/Workflow"

    if [[ -d "$workflow_dir" ]] && [[ -f "$workflow_dir/BOOTSTRAP.md" ]]; then
        local tmp
        tmp=$(mktemp "${TMPDIR:-/tmp}/workflow-combined.XXXXXX")
        local files=(
            "$workflow_dir/BOOTSTRAP.md"
            "$workflow_dir/TEMPLATES.md"
            "$workflow_dir/ENTRY-GATE.md"
            "$workflow_dir/IMPL-LOOP.md"
            "$workflow_dir/CLOSE-GATE.md"
            "$workflow_dir/SPRINT-CLOSE.md"
            "$workflow_dir/PROCEDURES.md"
            "$workflow_dir/AGENT-RULES.md"
            "$workflow_dir/STATE-TRANSITIONS.md"
            "$workflow_dir/ADAPTATION.md"
            "$workflow_dir/HOOK-TEMPLATES.md"
        )
        # Concatenate in logical order, stripping header blocks added per-file.
        # Header block: line 1 = # Title, then > ** nav lines, then blank line.
        for f in "${files[@]}"; do
            awk '
                NR==1 && /^# / { next }
                !past && /^$/ { next }
                !past && /^> \*\*/ { next }
                { past=1; print }
            ' "$f"
            echo ""
            echo "---"
            echo ""
        done > "$tmp" 2>/dev/null
        echo "$tmp"
    else
        echo "$repo_root/WORKFLOW.md"
    fi
}
