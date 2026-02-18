# Semantic Workflow Verification Prompt

Copy-paste this prompt into any session to run a structured semantic check.
Scripts (`validate-workflow.sh`, `validate-paths.sh`) handle structural/path checks.
This prompt covers what scripts cannot: logic, completeness, dead ends.

---

```
First run the deterministic checks:
  bash validate-workflow.sh
  bash validate-paths.sh
  bash validate-paths.sh --self-test

Then read TEMPLATE.md and answer every question below.
Format: PASS/FAIL + line number(s) as evidence.
Do NOT skip questions. Do NOT add commentary — only PASS/FAIL + lines.
At the end, list all FAILs as a summary table.

═══ A. DECISION POINT COMPLETENESS (4 checks) ═══

A1. Entry Gate step 8 (strategic alignment failure):
    Do all 4 user responses (keep/modify/defer/remove)
    have a defined next-action? PASS/FAIL + lines.

A2. Entry Gate step 12e (user does not approve):
    Are all 3 outcomes defined — rework to Phase 0,
    rework to Phase 3, Sprint Abort? PASS/FAIL + lines.

A3. Close Gate Phase 0 escalation (unmet metric):
    Does every DEFERRED metric require: reason, target sprint,
    user approval? PASS/FAIL + lines.

A4. Mid-Sprint Scope Change step 3:
    Does every option (add Must, defer existing, hotfix, defer to next)
    specify what happens to TRACKING.md and Roadmap? PASS/FAIL + lines.

═══ B. INCOMPLETE BRANCHES (4 checks) ═══

B1. Bootstrap Q3 (line ~127): If the user already HAS a roadmap,
    what does the AI do? Is this path specified? PASS/FAIL + line.

B2. Bootstrap Q8 (line ~119-121): If there is exactly one clear
    language (not multi-language), is the "else" path stated
    or just implied? PASS/FAIL + line.

B3. Phase 0 (line ~391): "Should it be Should?" — if the AI flags
    a Must item as potentially Should, does the text define what
    happens for BOTH answers (yes-demote, no-keep)? PASS/FAIL + line.

B4. Scope Change (line ~663): "Does it invalidate verified items?"
    — is the NO path (no invalidation, just add) explicitly stated
    or only implied? PASS/FAIL + line.

═══ C. LOOP TERMINATION (3 checks) ═══

C1. Self-verify recheck loop (step C, line ~946):
    "All pass? NO → fix, recheck" — is there a max iteration
    limit or escalation if the fix keeps failing? PASS/FAIL + line.

C2. Close Gate re-run loop (line ~1097):
    "All phases pass? NO → fix, re-run" — same question:
    max iterations or escalation path? PASS/FAIL + line.

C3. Visual verification loop (line ~966):
    "loop until resolved" — is "resolved" formally defined?
    Is there a fallback if the visual issue cannot be fixed?
    PASS/FAIL + line.

═══ D. DEAD ENDS / UNRESOLVED TERMINALS (4 checks) ═══

D1. Line ~473: "0 Must items → sprint is empty, redesign or skip."
    Is "redesign" defined (what steps)? Is "skip" defined
    (skip to what)? PASS/FAIL + line.

D2. Close Gate Phase 0: MISSING or FAIL metric (not DEFERRED).
    The text says "fix before closing." What if fixing is impossible?
    Is there an escalation path or abort fallback? PASS/FAIL + line.

D3. Close Gate Phase 1a: Exit code 2 from sprint-audit.sh
    (setup error). The text says "fix script configuration."
    What if the script cannot be fixed (e.g., unsupported language)?
    Is a fallback defined? PASS/FAIL + line.

D4. Sprint Close step 6: "Mismatch → fix before closing sprint."
    What if the mismatch cannot be resolved? Is an escalation
    path defined? PASS/FAIL + line.

═══ E. CROSS-REFERENCE INTEGRITY (2 checks) ═══

E1. Every §SectionName reference in TEMPLATE.md:
    does the target section actually exist in the same file
    or in the file template it refers to? List any broken refs.
    PASS/FAIL + lines of broken refs (if any).

E2. Every "see Step N" or "see Phase N" reference:
    does that step/phase number exist in the referenced gate?
    PASS/FAIL + lines of broken refs (if any).

═══ F. STATE MACHINE COVERAGE (3 checks) ═══

F1. For each arrow in the Item Lifecycle diagram
    (§State Transitions): is there at least one workflow step
    that triggers this transition? List any orphan arrows.
    PASS/FAIL + orphan arrow details.

F2. Are there any states in the diagram with NO entry path
    (unreachable states)? PASS/FAIL + state name.

F3. Are there any non-terminal states with NO exit path
    (trapped states)? Terminal = verified, deferred.
    PASS/FAIL + state name.

═══ G. DATA PROVENANCE (2 checks) ═══

G1. Close Gate Phase 1b is now item-based (spec-driven), not file-based.
    It loads Entry Gate 9a predictions and 9b invariants, then uses
    git diff filtered by item context. Verify:
    (a) Is there a step that explicitly loads/references the Entry Gate
        9a+9b data before Phase 1b begins? PASS/FAIL + line.
    (b) For items with no Entry Gate 9a prediction recorded (e.g.,
        first sprint, missing plan), does Phase 1b define a fallback?
        PASS/FAIL + line.

G2. CODING_GUARDRAILS.md content (§Entry Gate, §Close Gate):
    is there an explicit step that says when/where this content
    is initially written? PASS/FAIL + line.

═══ H. USER DECISION GATES (3 checks) ═══

H1. Search for every place where AI changes sprint SCOPE or STRATEGY:
    adding/removing/deferring items, changing item priority (Must↔Should↔Could),
    modifying metric gates, or aborting a sprint.
    Does each such decision require explicit user approval?
    Exclude execution-level AI judgments (e.g., "script not applicable",
    "untestable item", "known gap after max retries") — these are
    operational classifications, not scope/strategy decisions.
    PASS = all scope/strategy changes require user approval.
    FAIL = any unilateral scope/strategy change. + lines.

H2. Search for every place where Roadmap or TRACKING.md status fields
    are updated (item status, metric status, checkbox state).
    Does each status-changing update happen AFTER the relevant user
    approval step? Exclude working notes (predictions, factual logs,
    report references) — these are analytical output, not decisions.
    PASS = all status mutations are post-approval.
    FAIL = any premature status mutation. + lines.

H3. Every Close Gate / Sprint Close finding or decision that
    affects sprint outcome (deferral, classification, status change):
    is it presented to the user before the gate proceeds to the
    next phase?
    PASS = all outcome-affecting decisions are user-visible.
    FAIL = any silent decision. + lines.

═══ I. INFORMATION FLOW & VISIBILITY (3 checks) ═══

I1. Every "list" / "read" / "check" / "identify" action in
    Entry Gate phases 1-2: does the output have a defined consumer?
    A consumer is either a later step that explicitly uses the data,
    OR an explicit "present to user" / "include in report" directive.
    Information gathered without a consumer is a dead data point.
    PASS = no orphan information. FAIL = read without consumer. + lines.

I2. Close Gate phase boundaries where findings are generated
    (Phase 0→1a, 1a→1b, 1b→2, 2→3, 4→close): is there a
    "present to user" or equivalent visibility step at or before
    each boundary? Exclude Phase 3→4 (regression results are
    self-evident). Phase 4 generates coverage gap findings —
    these must be presented before final test run.
    PASS = user sees findings at each relevant boundary.
    FAIL = silent phase transition with unreported findings. + lines.

I3. Sprint Close step 2 (TRACKING update): does it cover ALL
    completed items (Must + Should + Could that were worked on),
    not just Must? The text must explicitly mention non-Must items.
    PASS/FAIL + line.

═══ J. SCOPE & STATUS CONSISTENCY (3 checks) ═══

J1. Close Gate Phase 0 scope qualifiers: wherever item types or
    metric scopes are listed, are they consistent within the section?
    Since all items have metric gates, references should not exclude
    any priority level. If two statements use different scopes for
    the same concept, that is an inconsistency.
    PASS/FAIL + lines of inconsistent scopes.

J2. Entry Gate Phase 1 step 3 (previous sprint items):
    for each non-terminal status that an item can have
    (open, in_progress, blocked, fixed), does the step define
    what to do with items in that status? Especially: does it
    check whether blocked items' blockers are now resolved?
    PASS = all statuses handled. FAIL = any status unhandled. + line.

J3. Entry Gate step 0c (metric gates):
    Do ALL item types (Must, Should, Could) receive metric gates?
    The workflow should not have a rigor gap where some items
    skip metrics or failure mode analysis based on priority level.
    PASS = all items get metrics. FAIL = any priority level skipped. + line.

═══ SUMMARY ═══

List all FAILs in a table:
| ID | Description | Line(s) | Suggested fix |
```
