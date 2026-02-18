#!/usr/bin/env bash
# validate-model.sh — Formal model checker for workflow-model.yaml
#
# Verifies that workflow-model.yaml is internally consistent AND that every
# entity declared in it (decision points, loops, guards) actually exists in
# WORKFLOW.md. Uses Python3 for YAML parsing and graph algorithms.
#
# Usage:
#   ./validate-model.sh              # Run all checks
#   ./validate-model.sh --self-test  # Negative tests only (do NOT run in main CI)
#
# Exit codes:
#   0 = All checks pass
#   1 = Warnings (non-blocking)
#   2 = Failures (blocking)
#
# Automated semantic checks:
#   F1/F2/F3 — FSM transition validity, reachability, no trapped states
#   C1/C2/C3 — Loop termination: max iterations, escalation, fallback, resolved
#   A (partial) — Decision point location + option count
#
# Dependencies: bash 4+, python3 with PyYAML (stdlib on most distros)

set -uo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODEL="$SCRIPT_DIR/workflow-model.yaml"
WORKFLOW="$REPO_ROOT/WORKFLOW.md"

passes=0
warnings=0
failures=0

pass()  { echo "  PASS  [$1]"; passes=$((passes + 1)); }
warn()  { echo "  WARN  [$1] $*"; warnings=$((warnings + 1)); }
fail()  { local n="$1"; shift; echo "  FAIL  [$n] $*"; failures=$((failures + 1)); }

# ─── CHECK 1a: YAML SYNTAX ────────────────────────────────────────────────────
echo "── CHECK 1a: YAML Syntax ──"
if ! python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$MODEL" 2>/dev/null; then
  fail "YAML_SYNTAX" "workflow-model.yaml failed to parse"
  python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$MODEL" 2>&1 || true
  exit 2
else
  pass "YAML_SYNTAX"
fi
echo ""

# ─── CHECK 1b: WORKFLOW HASH ──────────────────────────────────────────────────
echo "── CHECK 1b: Template Hash (drift detection) ──"
ACTUAL_HASH=$(python3 -c "import hashlib; print(hashlib.sha256(open('$WORKFLOW','rb').read()).hexdigest())")
STORED_HASH=$(python3 -c "import yaml, sys; m=yaml.safe_load(open(sys.argv[1])); print(m.get('meta',{}).get('workflow_hash',''))" "$MODEL")

if [[ -z "$STORED_HASH" ]]; then
  warn "WORKFLOW_HASH" "meta.workflow_hash not set in workflow-model.yaml — drift detection disabled"
  warnings=$((warnings + 1))
elif [[ "$ACTUAL_HASH" == "$STORED_HASH" ]]; then
  pass "WORKFLOW_HASH"
else
  fail "WORKFLOW_HASH" "WORKFLOW.md has changed since model was last validated."
  echo ""
  echo "  Stored:  ${STORED_HASH:0:16}..."
  echo "  Current: ${ACTUAL_HASH:0:16}..."
  echo ""
  echo "  Review workflow-model.yaml to confirm all decision_points/loops/guards"
  echo "  are still correct for the new WORKFLOW.md. Then update the hash:"
  echo ""
  echo "    python3 -c \"import hashlib; print(hashlib.sha256(open('WORKFLOW.md','rb').read()).hexdigest())\""
  echo ""
  failures=$((failures + 1))
fi
echo ""

IGNORE_HASH=false
for arg in "$@"; do [[ "$arg" == "--ignore-hash" ]] && IGNORE_HASH=true; done

if [[ "$failures" -gt 0 ]] && [[ "$IGNORE_HASH" == false ]]; then
  echo "══════════════════════════════════════════════════════"
  echo "Model validation FAILED  — hash mismatch blocks further checks."
  echo "  Use --ignore-hash to run all checks despite mismatch (debug only)."
  exit 2
fi

# ─── PYTHON DRIVER: all remaining checks ──────────────────────────────────────
SELF_TEST=""
for arg in "$@"; do [[ "$arg" == "--self-test" ]] && SELF_TEST="--self-test"; done

python3 - "$MODEL" "$WORKFLOW" "$SELF_TEST" <<'PYEOF'
import sys, yaml, re, hashlib
from collections import deque

model_path, template_path, mode = sys.argv[1], sys.argv[2], sys.argv[3]

with open(model_path) as f:
    model = yaml.safe_load(f)
with open(template_path) as f:
    template_lines = f.readlines()
template_text = "".join(template_lines)

passes = 0
warnings = 0
failures = 0

def ok(name):
    global passes
    print(f"  PASS  [{name}]")
    passes += 1

def warn(name, msg):
    global warnings
    print(f"  WARN  [{name}] {msg}")
    warnings += 1

def info(name, msg):
    print(f"  INFO  [{name}] {msg}")

def fail(name, msg):
    global failures
    print(f"  FAIL  [{name}] {msg}")
    failures += 1

def resolve_hint(hint, lines=None, text=None):
    """Two-stage hint resolution. Returns (matched: bool, context: str).
    hint can be a string (search entire template) or a dict with anchor+pattern.
    """
    tlines = lines if lines is not None else template_lines
    ttext  = text  if text  is not None else template_text
    try:
        if isinstance(hint, str):
            if not re.search(hint, ttext):
                return False, ""
            for i, line in enumerate(tlines):
                if re.search(hint, line):
                    start = max(0, i - 30)
                    end   = min(len(tlines), i + 30)
                    return True, "".join(tlines[start:end])
            return True, ttext  # matched text but not a specific line
        elif isinstance(hint, dict):
            anchor  = hint.get("anchor",  "")
            pattern = hint.get("pattern", "")
            window  = hint.get("window",  30)
            for i, line in enumerate(tlines):
                if re.search(anchor, line):
                    end   = min(len(tlines), i + window)
                    block = "".join(tlines[i:end])
                    if re.search(pattern, block):
                        return True, block
            return False, ""
        return False, ""
    except re.error:
        return False, ""

def hint_matches(hint, lines=None, text=None):
    matched, _ = resolve_hint(hint, lines, text)
    return matched

def context_near_hint(hint, lines=None, text=None):
    _, ctx = resolve_hint(hint, lines, text)
    return ctx

def hint_display(hint):
    if isinstance(hint, str):
        return hint[:60]
    elif isinstance(hint, dict):
        return f"anchor={hint.get('anchor','')!r} pattern={hint.get('pattern','')!r}"
    return str(hint)

# ─── CHECK 2: FSM — exit targets are valid state IDs ─────────────────────────
print("── CHECK 2: FSM Exit Target Validity ──")

state_ids = {s["id"] for s in model.get("item_states", [])}

for state in model.get("item_states", []):
    sid = state["id"]
    for target in state.get("exits", []):
        if target not in state_ids:
            fail(f"FSM_EXIT_{sid.upper()}_{target.upper()}", f"exit '{target}' not a known state ID")
        else:
            ok(f"FSM_EXIT_{sid.upper()}_{target.upper()}")

print("")

# ─── CHECK 3: FSM — reachability (BFS from "open", required states only) ─────
print("── CHECK 3: FSM Reachability ──")

transitions = {s["id"]: set(s.get("exits", [])) for s in model.get("item_states", [])}

if "open" not in transitions:
    fail("FSM_REACHABILITY", "No 'open' state — cannot compute reachability")
else:
    visited = set()
    queue = deque(["open"])
    while queue:
        cur = queue.popleft()
        if cur in visited:
            continue
        visited.add(cur)
        for nxt in transitions.get(cur, []):
            if nxt not in visited:
                queue.append(nxt)

    for state in model.get("item_states", []):
        sid = state["id"]
        required = state.get("required", True)  # default: required
        if not required:
            info(f"REACHABLE_{sid.upper()}", f"required=false — skipping reachability check")
            continue
        if sid in visited:
            ok(f"REACHABLE_{sid.upper()}")
        else:
            fail(f"REACHABLE_{sid.upper()}", f"State '{sid}' (required=true) is unreachable from 'open'")

print("")

# ─── CHECK 4: FSM — no trapped non-terminal states ───────────────────────────
print("── CHECK 4: FSM No Trapped States ──")

terminal_ids = {s["id"] for s in model.get("item_states", []) if s.get("terminal", False)}

reverse_graph = {s["id"]: set() for s in model.get("item_states", [])}
for s in model.get("item_states", []):
    for target in s.get("exits", []):
        if target in reverse_graph:
            reverse_graph[target].add(s["id"])

safe = set(terminal_ids)
queue = deque(terminal_ids)
while queue:
    cur = queue.popleft()
    for pred in reverse_graph.get(cur, []):
        if pred not in safe:
            safe.add(pred)
            queue.append(pred)

for state in model.get("item_states", []):
    sid = state["id"]
    regression_exits = set(state.get("regression_exits", []))
    normal_exits = set(state.get("exits", [])) - regression_exits

    if state.get("terminal", False):
        ok(f"NOT_TRAPPED_{sid.upper()}")
        if regression_exits:
            info(f"REGRESSION_EXIT_{sid.upper()}",
                 f"exits {sorted(regression_exits)} are regression-only (expected, not a trap)")
    elif sid in safe:
        ok(f"NOT_TRAPPED_{sid.upper()}")
    else:
        fail(f"NOT_TRAPPED_{sid.upper()}", f"Non-terminal state '{sid}' has no path to any terminal state")

print("")

# ─── CHECK 5: Decision point location_hint matches WORKFLOW.md ───────────────
print("── CHECK 5: Decision Point Locations ──")

for dp in model.get("decision_points", []):
    did = dp["id"]
    hint = dp.get("location_hint", "")
    if not hint:
        warn(f"DP_LOCATION_{did}", "No location_hint defined")
        continue
    if hint_matches(hint):
        ok(f"DP_LOCATION_{did}")
    else:
        fail(f"DP_LOCATION_{did}", f"location_hint not found in WORKFLOW.md: {hint_display(hint)}")

print("")

# ─── CHECK 6: Decision point option count (all_branches_required) ────────────
print("── CHECK 6: Decision Point Option Count ──")

for dp in model.get("decision_points", []):
    did = dp["id"]
    if not dp.get("all_branches_required", False):
        continue
    options = dp.get("options", [])
    if len(options) >= 2:
        ok(f"DP_OPTIONS_{did}")
    else:
        fail(f"DP_OPTIONS_{did}", f"all_branches_required=true but only {len(options)} option(s) declared")

print("")

# ─── CHECK 7: Loop termination ────────────────────────────────────────────────
print("── CHECK 7: Loop Termination ──")

ESCALATION_PATTERN = r"escalat|[Mm]ax\s+[0-9]|fallback|abort|known gap|protocol violation"

for loop in model.get("loops", []):
    lid = loop["id"]
    hint = loop.get("location_hint", "")

    if not hint:
        warn(f"LOOP_LOCATION_{lid}", "No location_hint defined")
    elif hint_matches(hint):
        ok(f"LOOP_LOCATION_{lid}")
    else:
        fail(f"LOOP_LOCATION_{lid}", f"location_hint not found in WORKFLOW.md: {hint_display(hint)}")

    if loop.get("escalation_required", False):
        ctx = context_near_hint(hint) if hint else ""
        if re.search(ESCALATION_PATTERN, ctx):
            ok(f"LOOP_ESCALATION_{lid}")
        else:
            fail(f"LOOP_ESCALATION_{lid}", f"escalation_required=true but no escalation language near: {hint_display(hint)}")

    if loop.get("fallback_required", False):
        ctx = context_near_hint(hint) if hint else ""
        if re.search(r"fallback|known gap|target sprint", ctx):
            ok(f"LOOP_FALLBACK_{lid}")
        else:
            fail(f"LOOP_FALLBACK_{lid}", f"fallback_required=true but no fallback language near: {hint_display(hint)}")

    if loop.get("resolved_defined", False):
        ctx = context_near_hint(hint) if hint else ""
        if re.search(r"[Rr]esolution\s*=|user confirms|confirms.*OK|resolved.*user", ctx):
            ok(f"LOOP_RESOLVED_{lid}")
        else:
            fail(f"LOOP_RESOLVED_{lid}", f"resolved_defined=true but no definition near: {hint_display(hint)}")

print("")

# ─── CHECK 8: Guard blocking text ────────────────────────────────────────────
print("── CHECK 8: Guard Conditions ──")

BLOCKING_PATTERN = r"block|cannot proceed|gate blocked|must not proceed|protocol violation|mandatory"

for guard in model.get("guards", []):
    gid = guard["id"]
    hint = guard.get("location_hint", "")

    if not hint:
        warn(f"GUARD_LOCATION_{gid}", "No location_hint defined")
        continue

    if hint_matches(hint):
        ok(f"GUARD_LOCATION_{gid}")
    else:
        fail(f"GUARD_LOCATION_{gid}", f"location_hint not found in WORKFLOW.md: {hint_display(hint)}")

    if guard.get("must_block_gate", False):
        ctx = context_near_hint(hint)
        if re.search(BLOCKING_PATTERN, ctx):
            ok(f"GUARD_BLOCKING_{gid}")
        else:
            fail(f"GUARD_BLOCKING_{gid}", f"must_block_gate=true but no blocking language near: {hint_display(hint)}")

    if guard.get("skip_is_protocol_violation", False):
        ctx = context_near_hint(hint)
        if re.search(r"protocol violation", ctx):
            ok(f"GUARD_PROTOCOL_VIOLATION_{gid}")
        else:
            fail(f"GUARD_PROTOCOL_VIOLATION_{gid}", f"skip_is_protocol_violation=true but 'protocol violation' not near: {hint_display(hint)}")

print("")

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
print("══════════════════════════════════════════════════════")
if failures > 0:
    print(f"Model validation FAILED  — {passes} passed, {warnings} warnings, {failures} failures.")
    sys.exit(2)
elif warnings > 0:
    print(f"Model validation WARNED  — {passes} passed, {warnings} warnings.")
    sys.exit(1)
else:
    print(f"Model validation CLEAN   — {passes} checks passed, 0 findings.")
    sys.exit(0)
PYEOF

EXIT_CODE=$?
[[ "$EXIT_CODE" -ge 2 ]] && exit 2

# ─── SELF-TEST MODE (do NOT run in main CI — use separate optional job) ───────
if [[ "$SELF_TEST" == "--self-test" ]]; then
  echo ""
  echo "── Self-test: Negative checks ──"
  echo "Running negative tests against temp copies of WORKFLOW.md..."
  echo "(This mode is for local/pre-commit use; excluded from main CI job)"
  echo ""

  TMPDIR_ST="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR_ST"' EXIT

  st_passes=0
  st_failures=0

  # self_test_negative: remove a pattern from WORKFLOW.md, expect a specific FAIL check name.
  # For dict location_hints: remove the anchor line to break the two-stage lookup.
  self_test_negative() {
    local test_name="$1"
    local remove_pattern="$2"
    local expected_check="$3"

    local TMPWORKFLOW="$TMPDIR_ST/WORKFLOW_${test_name}.md"
    grep -vE "$remove_pattern" "$WORKFLOW" > "$TMPWORKFLOW"

    local OUTPUT
    OUTPUT=$(python3 - "$MODEL" "$TMPWORKFLOW" "" 2>&1 <<'INNERPY'
import sys, yaml, re

model_path, template_path, _ = sys.argv[1], sys.argv[2], sys.argv[3]
with open(model_path) as f:
    model = yaml.safe_load(f)
with open(template_path) as f:
    tlines = f.readlines()
ttext = "".join(tlines)

def resolve_hint(hint):
    try:
        if isinstance(hint, str):
            return bool(re.search(hint, ttext))
        elif isinstance(hint, dict):
            anchor  = hint.get("anchor",  "")
            pattern = hint.get("pattern", "")
            window  = hint.get("window",  30)
            for i, line in enumerate(tlines):
                if re.search(anchor, line):
                    block = "".join(tlines[i:min(len(tlines), i + window)])
                    if re.search(pattern, block):
                        return True
            return False
    except:
        return False

failures = []
for dp in model.get("decision_points", []):
    hint = dp.get("location_hint", "")
    if hint and not resolve_hint(hint):
        failures.append(f"DP_LOCATION_{dp['id']}")
for loop in model.get("loops", []):
    hint = loop.get("location_hint", "")
    if hint and not resolve_hint(hint):
        failures.append(f"LOOP_LOCATION_{loop['id']}")
for guard in model.get("guards", []):
    hint = guard.get("location_hint", "")
    if hint and not resolve_hint(hint):
        failures.append(f"GUARD_LOCATION_{guard['id']}")
print(",".join(failures))
INNERPY
)

    if echo "$OUTPUT" | grep -qF "$expected_check"; then
      echo "  PASS  [$test_name] Removing '$remove_pattern' triggered FAIL on [$expected_check]"
      st_passes=$((st_passes + 1))
    else
      echo "  FAIL  [$test_name] Removing '$remove_pattern' did NOT trigger [$expected_check]"
      echo "        Got: $OUTPUT"
      st_failures=$((st_failures + 1))
    fi
  }

  # EG_08 uses dict anchor+pattern: remove anchor line to break two-stage lookup
  self_test_negative "ST_EG08"   '^8\. Strategic alignment'                                    "DP_LOCATION_EG_08"
  self_test_negative "ST_EG12E"  'return to the relevant phase'                               "DP_LOCATION_EG_12E"
  self_test_negative "ST_CG_MET" '[Uu]nmet metric escalation|DEFERRED.*escalation'            "DP_LOCATION_CG_MET"
  # MS_SC3 uses dict anchor+pattern: remove anchor heading
  self_test_negative "ST_MS_SC3" '^### Mid-Sprint Scope Change'                               "DP_LOCATION_MS_SC3"
  self_test_negative "ST_IL_SVR" 'Max 3 rounds|escalate.*user before continuing'             "LOOP_LOCATION_IL_SVR"
  self_test_negative "ST_IL_VIS" 'Max 3 attempts.*if still failing.*log visual gap'            "LOOP_LOCATION_IL_VIS"
  self_test_negative "ST_CG_AMD" 'ALL metrics.*DEFERRED.*gate blocked|[Gg]uard.*ALL metrics' "GUARD_LOCATION_CG_AMD"
  self_test_negative "ST_CG_PM1" 'mandatory.*run before every Close Gate|AI must not proceed to Phase 0 without' "GUARD_LOCATION_CG_PM1"

  echo ""
  echo "══════════════════════════════════════════════════════"
  if [[ "$st_failures" -gt 0 ]]; then
    echo "Self-test FAILED — $st_failures negative test(s) did not trigger expected FAILs."
    exit 2
  else
    echo "Self-test CLEAN  — $st_passes tests: all correctly triggered expected FAILs."
    exit 0
  fi
fi

exit $EXIT_CODE
