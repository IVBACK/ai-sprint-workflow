#!/usr/bin/env bash
# Hook: detect-audit-signals.sh
# Event: SessionStart + PostToolUse (Edit|Write on TRACKING.md)
# Purpose: Self-activating CP1 and CP2 detector.
#   CP1: Metric regression ≥20% between consecutive sprints
#        Reads §Performance Baseline Log table from TRACKING.md
#        Requires: ≥2 sprint rows for same metric, numeric values, separate unit column
#        Silent if section missing, insufficient data, or non-numeric values → zero false positives
#   CP2: Same failure category in 2+ sprints
#        Reads §Failure History table from TRACKING.md
#        Requires: Category column, sprint column, ≥2 identical categories
#        Silent if section missing or insufficient data
# Security:
#   - Metric/category names sanitized before output (alphanumeric + _ - only)
#   - jq --arg used for all string injection (JSON-safe)
#   - Raw TRACKING.md content never passed to additionalContext
#   - Division-by-zero guarded (prev=0 skipped)
# WORKFLOW.md rules:
#   CP1: Entry Gate Phase 1 — metric regression ≥20% → ⚠ AUDIT SIGNAL
#   CP2: Entry Gate Phase 3 Step 9a — same failure category 2+ sprints → ⚠ AUDIT SIGNAL

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOKS_DIR/../hooks-config.sh"

[[ "$HOOK_DETECT_AUDIT_SIGNALS" != "true" ]] && exit 0

# Thresholds from centralized config
_CP1_THRESHOLD="${AUDIT_CP1_THRESHOLD:-0.20}"
_CP2_MIN_SPRINTS="${AUDIT_CP2_MIN_SPRINTS:-2}"
command -v jq >/dev/null 2>&1 || exit 0

# ── PostToolUse filter: only re-run when TRACKING.md is the edited file ──
# On SessionStart, stdin is empty or has no tool_name → always run.
# On PostToolUse, only run if the edited file is TRACKING.md.
INPUT=$(cat)
if [[ -n "$INPUT" ]]; then
  TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
  FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  if [[ -n "$TOOL" ]]; then
    # PostToolUse context — only fire for TRACKING.md edits
    case "$FILE" in
      *TRACKING*.md) ;; # continue
      *) exit 0 ;;
    esac
  fi
fi

TRACKING=$(find "${CLAUDE_PROJECT_DIR:-.}" -maxdepth 2 -name "TRACKING.md" 2>/dev/null | head -1)
[[ -z "$TRACKING" || ! -f "$TRACKING" ]] && exit 0

# --- Sanitize helper: strip non-safe chars from metric/category names ---
sanitize() { echo "$1" | tr -cd 'a-zA-Z0-9_\- ' | cut -c1-40; }

# ── Check for missing structured sections ──
# Warn if TRACKING.md exists but lacks the tables CP1/CP2 need.
MISSING_SECTIONS=""
if ! grep -q "Performance Baseline Log" "$TRACKING" 2>/dev/null; then
  MISSING_SECTIONS+="Performance Baseline Log"
fi
if ! grep -q "Failure Mode History\|Failure History" "$TRACKING" 2>/dev/null; then
  [[ -n "$MISSING_SECTIONS" ]] && MISSING_SECTIONS+=", "
  MISSING_SECTIONS+="Failure Mode History"
fi

CP1_SIGNALS=""
CP2_SIGNALS=""

# ══════════════════════════════════════════════
# CP1: §Performance Baseline Log
# Expected table format:
#   | Sprint | Metric      | Value | Unit |
#   | S1     | render_time | 12    | ms   |
# Columns (awk -F'|'): $2=sprint $3=metric $4=value $5=unit
# ══════════════════════════════════════════════
CP1_SIGNALS=$(awk -F'|' -v cp1_thresh="$_CP1_THRESHOLD" '
  # Find section header (matches TRACKING.md template: "## Performance Baseline Log")
  /Performance Baseline Log/ { in_section=1; next }
  # Exit section on next ## heading
  in_section && /^##/ { in_section=0 }
  # Skip header/separator rows
  in_section && /Sprint.*Metric/ { next }
  in_section && /^[[:space:]]*\|[-:]+/ { next }
  # Parse data rows: must start with | S (sprint)
  in_section && /^\|[[:space:]]*S[0-9]/ {
    sprint=$2; metric=$3; value=$4; unit=$5
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", sprint)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", metric)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", unit)
    # Only numeric values (integer or decimal, no prefix/suffix)
    # Sanitize metric name: allow only alphanumeric, underscore, hyphen (max 32 chars)
    gsub(/[^a-zA-Z0-9_-]/, "_", metric)
    metric=substr(metric, 1, 32)
    if (value ~ /^[0-9]+(\.[0-9]+)?$/ && metric != "" && metric != "_") {
      key=metric
      if (key in last_sprint) {
        prev_val=last_val[key]
        curr_val=value+0
        prev_sp=last_sprint[key]
        # Guard: prev must be > 0 to avoid division by zero
        if (prev_val > 0) {
          pct=(curr_val - prev_val) / prev_val
          if (pct >= cp1_thresh) {
            printf "  %s: %s%s -> %s%s (+%.0f%%)\n", \
              key, prev_val, last_unit[key], curr_val, unit, pct*100
          }
        }
      }
      last_sprint[key]=sprint
      last_val[key]=value+0
      last_unit[key]=unit
    }
  }
' "$TRACKING")

# ══════════════════════════════════════════════
# CP2: §Failure History
# Expected table format:
#   | Sprint | Category  | Item     | Resolved |
#   | S1     | null-ref  | CORE-003 | yes      |
# Columns (awk -F'|'): $2=sprint $3=category
# ══════════════════════════════════════════════
CP2_SIGNALS=$(awk -F'|' -v cp2_min="$_CP2_MIN_SPRINTS" '
  # Matches TRACKING.md template: "## Failure Mode History"
  /Failure Mode History/ { in_section=1; next }
  in_section && /^##/ { in_section=0 }
  in_section && /Sprint.*Category/ { next }
  in_section && /^[[:space:]]*\|[-:]+/ { next }
  in_section && /^\|[[:space:]]*S[0-9]/ {
    sprint=$2; category=$3
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", sprint)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", category)
    # Sanitize category name
    gsub(/[^a-zA-Z0-9_-]/, "_", category)
    category=substr(category, 1, 32)
    if (category != "" && category != "_") {
      # Track unique sprints per category
      key=category SUBSEP sprint
      if (!(key in seen)) {
        seen[key]=1
        count[category]++
        sprints[category]=sprints[category] " " sprint
      }
    }
  }
  END {
    for (cat in count) {
      if (count[cat] >= cp2_min) {
        printf "  \"%s\" -- %d sprints:%s\n", cat, count[cat], sprints[cat]
      }
    }
  }
' "$TRACKING")

# Sanitize output lines (remove any content that could be used for injection)
if [[ -n "$CP1_SIGNALS" ]]; then
    CP1_SIGNALS=$(echo "$CP1_SIGNALS" | while IFS= read -r line; do
        # Allow: spaces, letters, digits, +%→:.-_/
        echo "$line" | tr -cd 'a-zA-Z0-9 _\-+%->:./()\n'
    done)
fi
if [[ -n "$CP2_SIGNALS" ]]; then
    CP2_SIGNALS=$(echo "$CP2_SIGNALS" | while IFS= read -r line; do
        echo "$line" | tr -cd 'a-zA-Z0-9 _\-+%->:./()\n'
    done)
fi

# ══════════════════════════════════════════════
# Output
# ══════════════════════════════════════════════
[[ -z "$CP1_SIGNALS" && -z "$CP2_SIGNALS" && -z "$MISSING_SECTIONS" ]] && exit 0

CONTEXT=""

if [[ -n "$MISSING_SECTIONS" ]]; then
    CONTEXT+="=== ℹ AUDIT DATA GAP ===\n"
    CONTEXT+="TRACKING.md is missing structured sections needed for automatic regression detection:\n"
    CONTEXT+="  Missing: ${MISSING_SECTIONS}\n"
    CONTEXT+="Without these tables, CP1 (metric regression) and/or CP2 (recurring failures) cannot fire.\n"
    CONTEXT+="Add the tables to TRACKING.md to enable automatic audit signals.\n"
    CONTEXT+="====================================================\n"
fi

if [[ -n "$CP1_SIGNALS" ]]; then
    _CP1_PCT=$(awk "BEGIN { printf \"%.0f\", $_CP1_THRESHOLD * 100 }")
    CONTEXT+="=== ⚠ CP1 AUDIT SIGNAL (WORKFLOW.md Entry Gate Phase 1) ===\n"
    CONTEXT+="Metric regression ≥${_CP1_PCT}% detected since last sprint:\n"
    CONTEXT+="$CP1_SIGNALS\n"
    CONTEXT+="REQUIRED: Before Entry Gate, surface to user:\n"
    CONTEXT+="  \"Metric regression detected — recommend Retroactive Audit.\"\n"
    CONTEXT+="  User decides YES/NO. Do not proceed silently.\n"
    CONTEXT+="====================================================\n"
fi

if [[ -n "$CP2_SIGNALS" ]]; then
    [[ -n "$CONTEXT" ]] && CONTEXT+="\n"
    CONTEXT+="=== ⚠ CP2 AUDIT SIGNAL (WORKFLOW.md Entry Gate Step 9a) ===\n"
    CONTEXT+="Recurring failure category detected across sprints:\n"
    CONTEXT+="$CP2_SIGNALS\n"
    CONTEXT+="REQUIRED: Surface to user — same failure category repeating\n"
    CONTEXT+="  suggests a root cause not yet addressed.\n"
    CONTEXT+="  Recommend Retroactive Audit for affected sprint.\n"
    CONTEXT+="====================================================\n"
fi

jq -n --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
exit 0
