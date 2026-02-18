#!/usr/bin/env bash
# validate-workflow.sh — Structural consistency check for workflow definition files.
#
# Validates that README.md, WORKFLOW.md, and sprint-audit-template.sh agree on
# numeric claims, cross-references, status values, and structural features.
#
# Usage:
#   ./validate-workflow.sh
#
# Exit codes:
#   0 = All checks pass (PASS only)
#   1 = Warnings exist (non-blocking — known intentional differences)
#   2 = Failures exist (blocking — real inconsistencies)
#
# Dependencies: GNU bash 4+ (associative arrays), grep -E (POSIX ERE), sed, awk
# Tested on: Linux (GNU coreutils). macOS may need GNU grep (brew install grep).

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
README="$REPO_ROOT/README.md"
WORKFLOW="$REPO_ROOT/WORKFLOW.md"
AUDIT="$REPO_ROOT/sprint-audit-template.sh"
ROADMAP="$REPO_ROOT/ROADMAP-DESIGN-PROMPT.md"
DESIGN="$REPO_ROOT/DESIGN.md"

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

# Extract lines between two heading patterns (same-level heading boundary).
# Usage: extract_section FILE START_REGEX STOP_REGEX
# Returns lines from (including) START_REGEX up to (excluding) STOP_REGEX.
extract_section() {
  local file="$1" start="$2" stop="$3"
  sed -n "/${start}/,/${stop}/p" "$file" 2>/dev/null | sed '$d'
}

# ── Pre-flight ──────────────────────────────────────────────
echo "Validating workflow consistency..."
preflight_ok=true
for f in "$README" "$WORKFLOW" "$AUDIT" "$ROADMAP" "$DESIGN"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR  Required file not found: $f"
    preflight_ok=false
  fi
done
if ! $preflight_ok; then
  exit 2
fi
echo "  README:   $README"
echo "  WORKFLOW: $WORKFLOW"
echo "  AUDIT:    $AUDIT"
echo "  ROADMAP:  $ROADMAP"
echo "  DESIGN:   $DESIGN"

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 1: Numeric Claim Validation
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 1: Numeric Claim Validation"
echo "══════════════════════════════════════════════════════"

# 1.1 Discovery question count
# README claims "14 discovery questions"; WORKFLOW.md has Q0-Q13 in tables.
readme_dq_claim=$(grep -oE '[0-9]+ discovery questions' "$README" | grep -oE '[0-9]+' | head -1)
template_dq_section=$(extract_section "$WORKFLOW" "^### Discovery Questions" "^---")
template_dq_count=0
if [[ -n "$template_dq_section" ]]; then
  template_dq_count=$(echo "$template_dq_section" | grep -cE '^\| [0-9]+ \|' || true)
fi

if [[ -z "$readme_dq_claim" ]]; then
  warn "DISCOVERY_Q_COUNT" "Could not find discovery question count claim in README"
elif [[ "$template_dq_count" -eq 0 ]]; then
  warn "DISCOVERY_Q_COUNT" "Could not extract discovery questions from WORKFLOW.md (format changed?)"
elif [[ "$readme_dq_claim" -eq "$template_dq_count" ]]; then
  pass "DISCOVERY_Q_COUNT ($readme_dq_claim)"
else
  fail "DISCOVERY_Q_COUNT" "README claims $readme_dq_claim, WORKFLOW.md defines $template_dq_count"
fi

# 1.2 Language count
# README claims "7 languages"; both README and WORKFLOW.md have language tables.
readme_lang_claim=$(grep -oE '[0-9]+ languages' "$README" | grep -oE '[0-9]+' | head -1)
readme_lang_section=$(extract_section "$README" "^## Supported Languages" "^##")
readme_lang_rows=0
if [[ -n "$readme_lang_section" ]]; then
  readme_lang_rows=$(echo "$readme_lang_section" | grep -cE '^\| \*\*' || true)
fi
template_lang_section=$(extract_section "$WORKFLOW" "^### Language-Specific Pattern Examples" "^---")
template_lang_rows=0
if [[ -n "$template_lang_section" ]]; then
  template_lang_rows=$(echo "$template_lang_section" | grep -cE '^\| \*\*' || true)
fi

lang_ok=true
if [[ -z "$readme_lang_claim" ]]; then
  warn "LANG_COUNT" "Could not find language count claim in README"
  lang_ok=false
else
  if [[ "$readme_lang_claim" -ne "$readme_lang_rows" ]]; then
    fail "LANG_COUNT_README" "README claims $readme_lang_claim but table has $readme_lang_rows rows"
    lang_ok=false
  fi
  if [[ "$readme_lang_rows" -ne "$template_lang_rows" ]]; then
    fail "LANG_COUNT_CROSS" "README table: $readme_lang_rows rows, WORKFLOW.md table: $template_lang_rows rows"
    lang_ok=false
  fi
fi
$lang_ok && [[ -n "$readme_lang_claim" ]] && pass "LANG_COUNT ($readme_lang_claim)"

# 1.3 Bootstrap step count
# README header: "Bootstrap Steps (9 total)"
readme_bootstrap_claim=$(grep -oE 'Bootstrap Steps \([0-9]+' "$README" | grep -oE '[0-9]+' | head -1)
# WORKFLOW.md bootstrap steps are numbered "1. ... " through "9. ..." before the first ``` block.
# Use the specific heading "Quick Start — AI Agent Bootstrap" to avoid matching CLAUDE.md template's "Quick Start".
template_bootstrap_section=$(sed -n '/^## Quick Start.*Bootstrap/,/^```/p' "$WORKFLOW" | head -n -1)
template_bootstrap_count=0
if [[ -n "$template_bootstrap_section" ]]; then
  template_bootstrap_count=$(echo "$template_bootstrap_section" | grep -cE '^[0-9]+\. ' || true)
fi

if [[ -z "$readme_bootstrap_claim" ]]; then
  warn "BOOTSTRAP_STEPS" "Could not find bootstrap step count in README"
elif [[ "$template_bootstrap_count" -eq 0 ]]; then
  warn "BOOTSTRAP_STEPS" "Could not extract bootstrap steps from WORKFLOW.md (format changed?)"
elif [[ "$readme_bootstrap_claim" -eq "$template_bootstrap_count" ]]; then
  pass "BOOTSTRAP_STEPS ($readme_bootstrap_claim)"
else
  fail "BOOTSTRAP_STEPS" "README claims $readme_bootstrap_claim, WORKFLOW.md has $template_bootstrap_count"
fi

# 1.4 Close Gate phase count
# README diagram says "(5 phases)". WORKFLOW.md has Phase 0, 1a, 1b, 2, 3, 4 = 5 unique numbers.
readme_cg_claim=$(grep -oE '[0-9]+ phases' "$README" | grep -oE '[0-9]+' | head -1)
template_cg_section=$(extract_section "$WORKFLOW" "^## Close Gate" "^## Sprint Close")
template_cg_phases=0
if [[ -n "$template_cg_section" ]]; then
  template_cg_phases=$(echo "$template_cg_section" | grep -oE '\*\*Phase [0-9]+' | grep -oE '[0-9]+' | sort -un | wc -l)
fi

if [[ -z "$readme_cg_claim" ]]; then
  warn "CLOSE_GATE_PHASES" "Could not find close gate phase count in README"
elif [[ "$template_cg_phases" -eq 0 ]]; then
  warn "CLOSE_GATE_PHASES" "Could not extract phase headers from WORKFLOW.md (format changed?)"
elif [[ "$readme_cg_claim" -eq "$template_cg_phases" ]]; then
  pass "CLOSE_GATE_PHASES ($readme_cg_claim)"
else
  fail "CLOSE_GATE_PHASES" "README claims $readme_cg_claim, WORKFLOW.md has $template_cg_phases unique phase numbers"
fi

# 1.5 Entry Gate step count
# README diagram: "12 st" or CLAUDE.md template: "12 steps".
readme_eg_claim=$(grep -oE '[0-9]+ st[ep)s]' "$README" | grep -oE '[0-9]+' | head -1)
template_eg_section=$(extract_section "$WORKFLOW" "^## Entry Gate" "^---")
template_eg_steps=0
if [[ -n "$template_eg_section" ]]; then
  template_eg_steps=$(echo "$template_eg_section" | grep -cE '^[0-9]+\. ' || true)
fi

if [[ -z "$readme_eg_claim" ]]; then
  warn "ENTRY_GATE_STEPS" "Could not find entry gate step count in README"
elif [[ "$template_eg_steps" -eq 0 ]]; then
  warn "ENTRY_GATE_STEPS" "Could not extract entry gate steps from WORKFLOW.md (format changed?)"
elif [[ "$readme_eg_claim" -eq "$template_eg_steps" ]]; then
  pass "ENTRY_GATE_STEPS ($readme_eg_claim)"
else
  fail "ENTRY_GATE_STEPS" "README claims $readme_eg_claim, WORKFLOW.md has $template_eg_steps"
fi

# 1.6 Audit script section count
# WORKFLOW.md CLAUDE.md template mentions "12 sections". Script has "# SECTION N:" headers.
template_section_claim=$(grep -oE '[0-9]+ sections' "$WORKFLOW" | grep -oE '[0-9]+' | head -1)
audit_section_count=$(grep -cE '^# SECTION [0-9]+' "$AUDIT" || true)

if [[ -z "$template_section_claim" ]]; then
  warn "AUDIT_SECTIONS" "Could not find section count claim in WORKFLOW.md"
elif [[ "$template_section_claim" -eq "$audit_section_count" ]]; then
  pass "AUDIT_SECTIONS ($audit_section_count)"
else
  fail "AUDIT_SECTIONS" "WORKFLOW.md claims $template_section_claim, audit script has $audit_section_count"
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 2: Cross-File Reference Integrity
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 2: Cross-File Reference Integrity"
echo "══════════════════════════════════════════════════════"

# 2.1 Entry Gate step references in README exist in WORKFLOW.md
readme_kdd=$(extract_section "$DESIGN" "^## Key Design Decisions" "^## ")
eg_section=$(extract_section "$WORKFLOW" "^## Entry Gate" "^---")
missing_eg_refs=""
if [[ -n "$readme_kdd" ]] && [[ -n "$eg_section" ]]; then
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    step_num="${ref%%[a-e]*}"
    if ! echo "$eg_section" | grep -qE "^${step_num}\. |[[:space:]]${ref}[.):,[:space:]]"; then
      missing_eg_refs="$missing_eg_refs $ref"
    fi
  done < <(echo "$readme_kdd" | grep -oE 'Entry Gate step [0-9]+[a-e]?' | grep -oE '[0-9]+[a-e]?' | sort -u)
fi

if [[ -z "$missing_eg_refs" ]]; then
  pass "EG_STEP_REFS"
else
  fail "EG_STEP_REFS" "README references Entry Gate steps not in WORKFLOW.md:$missing_eg_refs"
fi

# 2.2 Close Gate Phase references in README exist in WORKFLOW.md
cg_section=$(extract_section "$WORKFLOW" "^## Close Gate" "^## Sprint Close")
missing_cg_refs=""
if [[ -n "$readme_kdd" ]] && [[ -n "$cg_section" ]]; then
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    phase_num="${ref%%[a-b]*}"
    phase_letter="${ref#"$phase_num"}"
    if [[ -z "$phase_letter" ]]; then
      # Phase N — check for "Phase N" header
      if ! echo "$cg_section" | grep -qE "Phase ${phase_num}"; then
        missing_cg_refs="$missing_cg_refs $ref"
      fi
    else
      # Phase Nx (e.g., 4b) — check for "Phase N" header AND "Nx." or "Nx)" sub-item
      if ! echo "$cg_section" | grep -qE "Phase ${phase_num}" || \
         ! echo "$cg_section" | grep -qE "${ref}[.):,[:space:]]"; then
        missing_cg_refs="$missing_cg_refs $ref"
      fi
    fi
  done < <(echo "$readme_kdd" | grep -oE 'Close Gate Phase [0-9]+[a-b]?' | grep -oE '[0-9]+[a-b]?' | sort -u)
fi

if [[ -z "$missing_cg_refs" ]]; then
  pass "CG_PHASE_REFS"
else
  fail "CG_PHASE_REFS" "README references Close Gate phases not in WORKFLOW.md:$missing_cg_refs"
fi

# 2.3 Sprint Close step references in README exist in WORKFLOW.md
sc_section=$(extract_section "$WORKFLOW" "^## Sprint Close" "^---")
missing_sc_refs=""
if [[ -n "$readme_kdd" ]] && [[ -n "$sc_section" ]]; then
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    step_num="${ref%%[a-g]*}"
    if ! echo "$sc_section" | grep -qE "^${step_num}\. "; then
      missing_sc_refs="$missing_sc_refs $ref"
    fi
  done < <(echo "$readme_kdd" | grep -oE 'Sprint Close step [0-9]+[a-g]?' | grep -oE '[0-9]+[a-g]?' | sort -u)
fi

if [[ -z "$missing_sc_refs" ]]; then
  pass "SC_STEP_REFS"
else
  fail "SC_STEP_REFS" "README references Sprint Close steps not in WORKFLOW.md:$missing_sc_refs"
fi

# 2.4 Audit section numbers referenced in WORKFLOW.md exist in script
missing_audit_refs=""
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  sec_num="${ref%%[a-c]*}"
  if ! grep -qE "^# SECTION ${sec_num}:" "$AUDIT"; then
    missing_audit_refs="$missing_audit_refs Section-$ref"
  fi
done < <(grep -oE 'Section [0-9]+[a-c]?' "$WORKFLOW" | grep -oE '[0-9]+[a-c]?' | sort -u)

if [[ -z "$missing_audit_refs" ]]; then
  pass "AUDIT_SECTION_REFS"
else
  fail "AUDIT_SECTION_REFS" "WORKFLOW.md references audit sections not in script:$missing_audit_refs"
fi

# 2.5 File structure tree parity (README vs WORKFLOW.md)
# Extract only filenames from tree lines (├── or └── prefixed lines, before # comments)
readme_tree_files=$(extract_section "$README" "^your-project" "^\`\`\`" | grep -E '[├└│]' | sed 's/#.*//' | grep -oE '[A-Za-z_<>]+\.(md|sh)' | sort -u)
template_tree_files=$(extract_section "$WORKFLOW" "^project-root" "^\`\`\`" | grep -E '[├└│]' | sed 's/#.*//' | grep -oE '[A-Za-z_<>]+\.(md|sh)' | sort -u)

if [[ -z "$readme_tree_files" ]] || [[ -z "$template_tree_files" ]]; then
  warn "FILE_TREE" "Could not extract file trees (format changed?)"
elif [[ "$readme_tree_files" == "$template_tree_files" ]]; then
  pass "FILE_TREE"
else
  readme_only=$(comm -23 <(echo "$readme_tree_files") <(echo "$template_tree_files") | tr '\n' ' ')
  template_only=$(comm -13 <(echo "$readme_tree_files") <(echo "$template_tree_files") | tr '\n' ' ')
  msg=""
  [[ -n "$readme_only" ]] && msg="README-only: ${readme_only}. "
  [[ -n "$template_only" ]] && msg="${msg}WORKFLOW.md-only: ${template_only}"
  fail "FILE_TREE" "$msg"
fi

# 2.6 Sprint Close log "steps 1-N" matches actual step count
log_step_max=$(echo "$sc_section" | grep -oE 'steps 1-[0-9]+' | grep -oE '[0-9]+$' | tail -1)
sc_step_count=0
if [[ -n "$sc_section" ]]; then
  sc_step_count=$(echo "$sc_section" | grep -cE '^[0-9]+\. ' || true)
fi

if [[ -z "$log_step_max" ]]; then
  warn "SC_LOG_COUNT" "Could not find 'steps 1-N' pattern in Sprint Close"
elif [[ "$log_step_max" -eq "$sc_step_count" ]]; then
  pass "SC_LOG_COUNT ($sc_step_count)"
else
  fail "SC_LOG_COUNT" "Sprint Close log says 'steps 1-$log_step_max' but section has $sc_step_count steps"
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 3: Status Value Consistency
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 3: Status Value Consistency"
echo "══════════════════════════════════════════════════════"

# 3.1 Item status values (open, in_progress, fixed, verified, deferred, blocked)
canonical_statuses="open in_progress fixed verified deferred blocked"
status_ok=true
for s in $canonical_statuses; do
  for file_label in "WORKFLOW:$WORKFLOW" "AUDIT:$AUDIT" "DESIGN:$DESIGN"; do
    label="${file_label%%:*}"
    fpath="${file_label#*:}"
    if ! grep -qw "$s" "$fpath" 2>/dev/null; then
      if [[ "$label" == "DESIGN" ]]; then
        warn "STATUS_$label" "DESIGN.md missing status value: $s"
      else
        fail "STATUS_$label" "$label missing status value: $s"
      fi
      status_ok=false
    fi
  done
done
$status_ok && pass "ITEM_STATUS_VALUES"

# 3.2 Metric status values (PASS, DEFERRED, FAIL, MISSING)
metric_statuses="PASS DEFERRED FAIL MISSING"
metric_ok=true
cg_full=$(extract_section "$WORKFLOW" "^## Close Gate" "^## Sprint Close")
if [[ -z "$cg_full" ]]; then
  warn "METRIC_STATUS" "Could not extract Close Gate section"
  metric_ok=false
else
  for ms in $metric_statuses; do
    if ! echo "$cg_full" | grep -qw "$ms"; then
      fail "METRIC_STATUS" "Close Gate section missing metric status: $ms"
      metric_ok=false
    fi
  done
fi
$metric_ok && pass "METRIC_STATUS_VALUES"

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 4: Content Parity
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 4: Content Parity"
echo "══════════════════════════════════════════════════════"

# 4.1 Language names match between README and WORKFLOW.md tables
readme_langs=""
if [[ -n "$readme_lang_section" ]]; then
  readme_langs=$(echo "$readme_lang_section" | grep -oE '\*\*[^*]+\*\*' | sed 's/\*//g' | sort)
fi
template_langs=""
if [[ -n "$template_lang_section" ]]; then
  template_langs=$(echo "$template_lang_section" | grep -oE '\*\*[^*]+\*\*' | sed 's/\*//g' | sort)
fi

if [[ -z "$readme_langs" ]] || [[ -z "$template_langs" ]]; then
  warn "LANG_NAMES" "Could not extract language names from tables"
elif [[ "$readme_langs" == "$template_langs" ]]; then
  pass "LANG_NAMES"
else
  # Compare base names (before /) for a softer check
  readme_base=$(echo "$readme_langs" | sed 's|/.*||' | sort)
  template_base=$(echo "$template_langs" | sed 's|/.*||' | sort)
  if [[ "$readme_base" == "$template_base" ]]; then
    warn "LANG_NAMES" "Base names match but full names differ (e.g., TypeScript vs TypeScript/React)"
  else
    fail "LANG_NAMES" "Language names do not match between README and WORKFLOW.md"
  fi
fi

# 4.2 Key Design Decisions step/phase references exist in WORKFLOW.md
kdd_bad_refs=""
if [[ -n "$readme_kdd" ]]; then
  # Check all Entry Gate step refs
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    step_num="${ref%%[a-e]*}"
    if [[ -n "$eg_section" ]] && ! echo "$eg_section" | grep -qE "^${step_num}\. |[[:space:]]${ref}[.):,[:space:]]"; then
      kdd_bad_refs="$kdd_bad_refs EG-$ref"
    fi
  done < <(echo "$readme_kdd" | grep -oE 'step [0-9]+[a-e]?' | grep -oE '[0-9]+[a-e]?' | sort -u)

  # Check Close Gate phase refs (Phase N or sub-item Nx like 4b)
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    phase_num="${ref%%[a-b]*}"
    phase_letter="${ref#"$phase_num"}"
    if [[ -n "$cg_section" ]]; then
      if [[ -z "$phase_letter" ]]; then
        echo "$cg_section" | grep -qE "Phase ${phase_num}" || kdd_bad_refs="$kdd_bad_refs CG-Phase-$ref"
      else
        # Sub-item: verify both the Phase header and the sub-item reference
        if ! echo "$cg_section" | grep -qE "Phase ${phase_num}" || \
           ! echo "$cg_section" | grep -qE "${ref}[.):,[:space:]]"; then
          kdd_bad_refs="$kdd_bad_refs CG-Phase-$ref"
        fi
      fi
    fi
  done < <(echo "$readme_kdd" | grep -oE 'Phase [0-9]+[a-b]?' | grep -oE '[0-9]+[a-b]?' | sort -u)

  # Check Sprint Close step refs
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    step_num="${ref%%[a-g]*}"
    if [[ -n "$sc_section" ]] && ! echo "$sc_section" | grep -qE "^${step_num}\. "; then
      kdd_bad_refs="$kdd_bad_refs SC-$ref"
    fi
  done < <(echo "$readme_kdd" | grep -oE 'Sprint Close step [0-9]+[a-g]?' | grep -oE '[0-9]+[a-g]?' | sort -u)
fi

if [[ -z "$kdd_bad_refs" ]]; then
  pass "KDD_REFS"
else
  fail "KDD_REFS" "Broken references in Key Design Decisions:$kdd_bad_refs"
fi

# 4.3 Checkbox notation ([x], [~], [ ]) defined consistently
roadmap_section=$(extract_section "$WORKFLOW" "^### Roadmap.md Template" "^###")
cb_ok=true
for cb in '\[x\]' '\[~\]' '\[ \]'; do
  if [[ -n "$roadmap_section" ]] && ! echo "$roadmap_section" | grep -qE "$cb"; then
    fail "CHECKBOX" "WORKFLOW.md Roadmap section missing checkbox notation: $cb"
    cb_ok=false
  fi
  if [[ -n "$sc_section" ]] && ! echo "$sc_section" | grep -qE "$cb"; then
    fail "CHECKBOX_SC" "Sprint Close section missing checkbox notation: $cb"
    cb_ok=false
  fi
done
$cb_ok && pass "CHECKBOX_NOTATION"

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 5: Internal WORKFLOW.md Consistency
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 5: Internal WORKFLOW.md Consistency"
echo "══════════════════════════════════════════════════════"

# 5.1 §SectionName references resolve to existing headings
all_headings=$(grep -E '^#{2,3} ' "$WORKFLOW" | sed 's/^#* //' | sed 's/ *$//')

# Known §-reference → heading substring mappings
declare -A section_map=(
  ["Setup"]="Setup"
  ["Immutable Contracts"]="Immutable Contracts"
  ["Close Gate"]="Close Gate"
  ["Entry Gate"]="Entry Gate"
  ["Sprint Close"]="Sprint Close"
  ["Anti-Patterns"]="Anti-Pattern"
  ["Scope Negotiation"]="Scope Negotiation"
  ["Failure Mode History"]="Failure Mode History"
  ["Failure Encounters"]="Failure Encounters"
  ["Predicted Failure Modes"]="Predicted Failure Modes"
  ["Open Risks"]="Open Risks"
  ["Document Contract"]="Document Contract"
  ["Update Rule"]="Update Rule"
  ["State Transitions"]="State Transitions"
  ["Index"]="Section Index"
  ["Sprint Abort"]="Sprint Abort"
)

section_missing=""
for ref_name in "${!section_map[@]}"; do
  target="${section_map[$ref_name]}"
  if ! echo "$all_headings" | grep -qi "$target"; then
    section_missing="$section_missing §$ref_name->$target"
  fi
done

if [[ -z "$section_missing" ]]; then
  pass "SECTION_REFS"
else
  fail "SECTION_REFS" "Unresolved section references:$section_missing"
fi

# 5.2 Entry Gate / Close Gate / Sprint Close cross-references valid
cross_bad=""

# Entry Gate step refs used elsewhere in WORKFLOW.md
if [[ -n "$eg_section" ]]; then
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    step_num="${ref%%[a-e]*}"
    if ! echo "$eg_section" | grep -qE "^${step_num}\. "; then
      cross_bad="$cross_bad EG-step-$ref"
    fi
  done < <(grep -oE 'Entry Gate step [0-9]+[a-e]?' "$WORKFLOW" | grep -oE '[0-9]+[a-e]?' | sort -u)
fi

# Sprint Close step refs used elsewhere in WORKFLOW.md
if [[ -n "$sc_section" ]]; then
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    step_num="${ref%%[a-g]*}"
    if ! echo "$sc_section" | grep -qE "^${step_num}\. "; then
      cross_bad="$cross_bad SC-step-$ref"
    fi
  done < <(grep -oE 'Sprint Close step [0-9]+[a-g]?' "$WORKFLOW" | grep -oE '[0-9]+[a-g]?' | sort -u)
fi

if [[ -z "$cross_bad" ]]; then
  pass "GATE_CROSS_REFS"
else
  fail "GATE_CROSS_REFS" "Broken cross-references:$cross_bad"
fi

# ═══════════════════════════════════════════════════════════════
#  CATEGORY 6: ROADMAP-DESIGN-PROMPT.md & Audit Content
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
echo "  CATEGORY 6: ROADMAP-DESIGN-PROMPT.md & Audit Content"
echo "══════════════════════════════════════════════════════"

# 6.1 README references ROADMAP-DESIGN-PROMPT.md
if grep -qF 'ROADMAP-DESIGN-PROMPT.md' "$README"; then
  pass "ROADMAP_README_REF"
else
  fail "ROADMAP_README_REF" "README does not reference ROADMAP-DESIGN-PROMPT.md"
fi

# 6.2 WORKFLOW.md references ROADMAP-DESIGN-PROMPT.md (design-first path)
if grep -qF 'ROADMAP-DESIGN-PROMPT.md' "$WORKFLOW"; then
  pass "ROADMAP_WORKFLOW_REF"
else
  fail "ROADMAP_WORKFLOW_REF" "WORKFLOW.md does not reference ROADMAP-DESIGN-PROMPT.md"
fi

# 6.3 ROADMAP-DESIGN-PROMPT.md has a Format Rules section
if grep -qE '^## Format Rules' "$ROADMAP"; then
  pass "ROADMAP_FORMAT_RULES"
else
  fail "ROADMAP_FORMAT_RULES" "ROADMAP-DESIGN-PROMPT.md missing '## Format Rules' section"
fi

# 6.4 ROADMAP-DESIGN-PROMPT.md mentions CORE-### IDs (workflow compatibility)
if grep -qE 'CORE-[0-9#]' "$ROADMAP"; then
  pass "ROADMAP_CORE_IDS"
else
  fail "ROADMAP_CORE_IDS" "ROADMAP-DESIGN-PROMPT.md missing CORE-### ID convention"
fi

# 6.5 WORKFLOW.md bootstrap step 4 has design-first skip path referencing Roadmap.md.
# Scope: extract only the bootstrap section (Quick Start…Bootstrap → first ``` block)
# to avoid false positives from other "4. … 5." spans in the document.
bootstrap_section=$(sed -n '/^## Quick Start.*Bootstrap/,/^```/p' "$WORKFLOW" | head -n -1)
bootstrap_step4=$(echo "$bootstrap_section" | sed -n '/^4\. /,/^5\. /p' | head -n -1)
if echo "$bootstrap_step4" | grep -qiE 'ROADMAP-DESIGN-PROMPT|skip this step|design-first'; then
  pass "ROADMAP_BOOTSTRAP_SKIP"
else
  fail "ROADMAP_BOOTSTRAP_SKIP" "WORKFLOW.md step 4 missing design-first alternative (skip when Roadmap.md exists)"
fi

# 6.6 Audit script has a check() function
if grep -qE '^check\(\)' "$AUDIT"; then
  pass "AUDIT_CHECK_FN"
else
  fail "AUDIT_CHECK_FN" "Audit script missing check() function definition"
fi

# 6.7 Audit script EXT comment lists all 7 supported language extensions
audit_ext_ok=true
for ext in cs ts py java go rs cpp; do
  if ! grep -qE "\"${ext}\"" "$AUDIT"; then
    fail "AUDIT_LANG_EXT" "Audit script EXT comment missing extension: $ext"
    audit_ext_ok=false
  fi
done
$audit_ext_ok && pass "AUDIT_LANG_EXT (7 extensions)"

# ═══════════════════════════════════════════════════════════════
#  SUMMARY
# ═══════════════════════════════════════════════════════════════
echo ""
echo "══════════════════════════════════════════════════════"
total=$((warnings + failures))
if [[ $failures -gt 0 ]]; then
  echo "Workflow validation: $passes passed, $warnings warning(s), $failures FAILURE(s)."
  echo "FAIL findings indicate real inconsistencies — fix before merging."
  exit 2
elif [[ $warnings -gt 0 ]]; then
  echo "Workflow validation: $passes passed, $warnings warning(s), 0 failures."
  echo "WARN findings may be intentional — review if needed."
  exit 1
else
  echo "Workflow validation CLEAN — $passes checks passed, 0 findings."
  exit 0
fi
