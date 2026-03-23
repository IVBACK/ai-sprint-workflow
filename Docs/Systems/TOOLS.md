# Sprint Tools

Dispatcher-based CLI for sprint workflow automation. A single entry point (`sprint-tools`) routes to 13 single-responsibility Python tools.

```
sprint-tools <command> [args...]
```

The dispatcher (`Tools/sprint-tools`) is a bash script with zero logic — a `case` statement that `exec`s the matching Python script.

Tools fall into two categories:
- **Anytime** — safe to run at any point: `state`, `review`
- **Workflow-step** — used at specific phases: `item`, `checkpoint`, `baseline`, `metrics`, `close`, `index`, `git`

## Anytime Tools

### state

Compact sprint digest for LLM context injection. Parses TRACKING.md, Roadmap.md, and gate reports into a single summary (target: <=23 lines). Auto-infers the current phase (`planned`, `entry_gate`, `impl_loop`, `impl_done`, `close_gate`, `sprint_close`, `done`).

```
sprint-tools state              # text output
sprint-tools state --json       # structured JSON (SprintDigest)
sprint-tools state /path/to/project  # explicit project root
sprint-tools state --check-escalations  # check recurring failure patterns needing escalation
```

Output includes: sprint number, phase, item statuses (sorted by priority), risks, working context, baselines, recurring failures, entry gate existence. The `--check-escalations` flag counts failure encounters by category and reports patterns that have hit the escalation threshold (>=3 occurrences).

### review

Blind review via external LLM (OpenAI or Anthropic). The reviewer receives the artifact with zero author reasoning — independent assessment only. Requires `CROSS_AUDIT_API_KEY` env var or `.env` file.

```
sprint-tools review report.md                    # review a file
sprint-tools review report.md -q "Is scope realistic?"  # specific question
sprint-tools review report.md -c "Entry Gate report"     # artifact context
sprint-tools review --stdin                      # pipe content
sprint-tools review report.md --json             # structured JSON output
git diff | sprint-tools review --stdin           # review a diff
```

Output: severity-tagged findings (`critical`/`warning`/`info`), summary, missing items list.

### verify

Three modes: (1) item verification checklist for `fixed` items, (2) audit-all evidence audit across all verified items, (3) bootstrap completion check. The item mode pulls failure modes and verification plan from the Entry Gate report, lists changed files, and detects test commands. The agent (or a sub-agent) uses the checklist to verify the item before marking `verified`.

```
sprint-tools verify CORE-001                # human-readable checklist
sprint-tools verify CORE-001 --json         # structured JSON (for sub-agent input)
sprint-tools verify CORE-001 --auto-apply   # hint: auto-mark verified on pass
sprint-tools verify --audit-all             # audit evidence levels on all verified items
sprint-tools verify --audit-all --json      # structured JSON audit output
sprint-tools verify --bootstrap             # 13-point bootstrap completion check
sprint-tools verify --bootstrap --json      # structured JSON bootstrap output
```

Output: checklist with failure modes, verification plan, changed files, test commands, evidence template. Item mode requires item status = `fixed`.

## Workflow-Step Tools

### item

Status transition with changelog, evidence, and roadmap sync. Single command replaces 4 manual edits.

**Phase:** Implementation loop (any item state change).

```
sprint-tools item CORE-001 in_progress
sprint-tools item CORE-001 fixed "login endpoint passes all tests"
sprint-tools item CORE-001 verified "VERIFIED: pytest 14/14 passed"
sprint-tools item CORE-001 deferred
```

**Evidence validation** (on `verified` transitions): evidence string should be prefixed with a confidence level (`VERIFIED:`, `INFERRED:`, or `UNCERTAIN:`). Missing prefix emits a warning (advisory). Wrong level for item priority is a hard block (exit 2): must items require `VERIFIED:`, should items require `VERIFIED:` or `INFERRED:`. Unknown priority is treated as must (fail-closed). See AGENT-RULES.md §Evidence Standards.

**Modifies:** TRACKING.md (Sprint Board status + evidence column, Change Log section), Roadmap.md (checkbox on `verified`/`deferred`).

### checkpoint

Updates `CLAUDE.md` Last Checkpoint section. Auto-derives the next step from status text (e.g. "Entry Gate complete" -> "Start implementation").

**Phase:** After any milestone (gate completion, implementation progress).

```
sprint-tools checkpoint "Entry Gate complete — S1"
sprint-tools checkpoint "Implementation in progress — S1, CORE-003 done"
```

**Modifies:** CLAUDE.md (Date, Active focus, Status, Next step fields).

### baseline

Appends a row to TRACKING.md Performance Baseline Log. Auto-extracts sprint label from current focus.

**Phase:** After measuring a metric (Entry Gate baselines, Close Gate comparisons).

```
sprint-tools baseline coverage 82 "%" "pytest --cov"
sprint-tools baseline response_time 12 ms "httpx benchmark"
```

**Modifies:** TRACKING.md (Performance Baseline Log table).

### metrics

Extracts metric list from an Entry Gate report for Close Gate verification. Can output a scaffold table.

**Phase:** Close Gate preparation.

```
sprint-tools metrics S1              # list metrics from Entry Gate
sprint-tools metrics S1 --scaffold   # markdown table scaffold for Close Gate
```

**Modifies:** Nothing (read-only, stdout only).

### close

Sprint-end chores: changelog size check, archive to `Docs/Archive/`, entry gate file flagging.

**Phase:** Sprint Close (after Close Gate passes).

```
sprint-tools close 1              # run sprint close for S1
sprint-tools close 1 --dry-run    # preview actions without writing
```

**Modifies:** Creates `Docs/Archive/changelog-S{N}.md`. Warns if changelog exceeds 50 lines.

### index

Rebuilds `SPRINT-INDEX.md` from HTML comment tags in TRACKING.md and archive files. Tags follow the format `<!-- topics:auth,api type:failure sprint:5 item:CORE-220 -->`.

**Phase:** Sprint Close or on-demand.

```
sprint-tools index       # rebuild full index
sprint-tools index 1     # filter to sprint 1
```

**Modifies:** SPRINT-INDEX.md (full rewrite, grouped by topic then type).

### git

Git ceremony wrapper with sprint conventions: branch naming (`sprint-N-impl`), tagging (`sprint-N-start`, `sprint-N-close`), squash merge with evidence hash update.

**Phase:** Sprint init, commits during implementation, sprint merge/abort.

```
sprint-tools git init 3                           # create branch + start tag
sprint-tools git commit CORE-001 "feat: add auth" # git add -u + prefixed commit
sprint-tools git push                             # push current branch
sprint-tools git merge 3                          # squash merge to main + close tag
sprint-tools git abort 3                          # delete branch + start tag
```

**Modifies:** Git refs (branches, tags). `merge` also updates TRACKING.md evidence column (replaces pre-squash hashes with squash hash).

## sprint-migrate

Upgrades a project from an older workflow version (v2.x) to the current version (v3.x). Performs 18-point validation: detects legacy file layout, renames/moves files, updates cross-references, and verifies consistency after migration.

**Phase:** One-time upgrade when user has an older workflow version.

```
sprint-tools migrate              # detect version, run migration
sprint-tools migrate --dry-run    # show what would change without modifying files
```

**Modifies:** WORKFLOW.md, Docs/Workflow/ structure, CLAUDE.md references, hooks-config.sh version tag.

## sprint_lib

Shared Python library under `Tools/sprint_lib/`. Core modules (5 primary + supporting):

- **models.py** — Dataclasses for all structured data: `Item`, `Risk`, `BaselineEntry`, `TrackingData`, `SprintDigest`, etc. Defines `VALID_STATUSES` (`open`, `in_progress`, `fixed`, `verified`, `deferred`, `blocked`) and `VALID_TRANSITIONS`:
  ```
  open        -> in_progress, blocked, deferred
  in_progress -> fixed, blocked, deferred
  fixed       -> verified, in_progress, deferred
  verified    -> open (regression)
  blocked     -> open, in_progress, deferred
  deferred    -> open
  ```

- **tracking_parser.py** — Read-only parser for TRACKING.md. Extracts sections by `##` headers, parses markdown tables into model objects. Public API: `parse()`, `get_item()`, `get_sprint_items()`, `get_risks()`, `get_recurring_failures()`, `get_latest_baselines()`, `get_latest_session_notes()`.

- **roadmap_parser.py** — Read-only parser for Roadmap.md. Extracts sprint sections, items, checkboxes. Public API: `parse()`, `get_active_sprint()`, `get_sprint()`.

- **gate_parser.py** — Read-only parser for Entry Gate and Close Gate reports. Public API: `find_gate_file()`, `extract_metrics()`, `parse_entry_gate()`, `parse_close_gate()`, `extract_close_gate_details()`.

- **writers.py** — In-place mutators for TRACKING.md, Roadmap.md, CLAUDE.md. Does NOT import any parser (write-side errors stay isolated). Single-item functions: `set_item_status()`, `append_changelog()`, `update_roadmap_checkbox()`, `add_risk()`, `remove_risk()`, `add_baseline_entry()`, `update_checkpoint()`. Batch functions: `set_items_status_batch()`, `append_changelog_batch()`, `update_roadmap_checkboxes_batch()`. Session/failure tracking: `append_session_note()`, `append_failure_encounter()`, `clear_session_notes()`, `update_working_context()`.

## Tool Usage Rules

From AGENT-RULES.md: tools are **MANDATORY** when available. Manual editing of TRACKING.md, CLAUDE.md checkpoint, or Roadmap.md checkboxes is prohibited.

**Why:** Each tool performs atomic multi-step operations. `sprint-tools item CORE-001 verified "hash"` does status change + evidence + changelog + roadmap checkbox in one call. Manual editing skips steps, leading to missing evidence, stale roadmap, and inconsistent changelog. Observation: manual editing produces 5x more audit findings than tool usage.

**Exception:** Working Context in TRACKING.md is always manual — no tool for it.

## Dependencies

- Python 3.10+ (type union syntax `X | None`)
- Standard library only for all tools except `review`
- `review` requires: `curl`, `CROSS_AUDIT_API_KEY` env var
- PyYAML: test suite only

## Adding a New Tool

1. Create `Tools/sprint-<name>.py` with a `main()` entry point
2. Add a line to the `case` statement in `Tools/sprint-tools`:
   ```bash
   name) exec "${PYTHON:-python3}" "$SCRIPT_DIR/sprint-<name>.py" "$@" ;;
   ```
3. Add a help line in the `help|--help|-h)` block
4. If the tool needs shared data models or file parsing, import from `sprint_lib`
5. Use `sprint_lib.utils.find_project_root()` for project root detection
6. Exit codes: 0 success, 1 general error, 2 validation error, 3 setup error
