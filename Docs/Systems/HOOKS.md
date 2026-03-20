# Hook System

## Overview

Hooks are shell scripts that fire on Claude Code lifecycle events. They serve three purposes:

1. **Context injection** -- remind the AI to read TRACKING.md, inject sprint digests, surface audit signals
2. **Rule enforcement** -- block secret reads, prevent CLAUDE.md overwrites, validate data integrity
3. **External audit** -- send diffs to a second LLM for independent code review

All hooks live in `.claude/hooks/`. Wiring is in `.claude/settings.json`. Feature flags are in `.claude/hooks-config.sh`.

Every hook sources `hooks-config.sh` first and checks its own feature flag. If the flag is `false`, the hook exits immediately with code 0.

## Event-to-Hook Mapping

Derived from `.claude/settings.json`:

| Event | Matcher | Hook | Purpose |
|-------|---------|------|---------|
| SessionStart | (all) | session-start.sh | Inject sprint digest or read instructions |
| SessionStart | (all) | detect-audit-signals.sh | CP1/CP2: metric regression, recurring failures |
| SessionStart | (all) | memory-sync.sh | Inject "Read TRACKING.md" + tool list |
| PreToolUse | Write | protect-claude.sh | Block Write tool on existing CLAUDE.md |
| PreToolUse | Write\|Edit | bootstrap-phase-gate.sh | Block file creation until bootstrap markers exist |
| PreToolUse | Read\|Bash | protect-secrets.sh | Block reads of .env, .key, .pem, credentials |
| PostToolUse | Edit\|Write | validate-tracking.sh | Check legal statuses, evidence on verified items |
| PostToolUse | Edit\|Write | validate-id-uniqueness.sh | Detect duplicate CORE-### IDs |
| PostToolUse | Edit\|Write | cross-llm-audit.sh | Send diff to external LLM for review |
| PostToolUse | Edit\|Write | detect-audit-signals.sh | Re-check CP1/CP2 after TRACKING edits |
| PostToolUse | Write | entry-gate-session.sh | Recommend session boundary after Entry Gate |
| PostToolUse | Write | validate-close-gate.sh | CP4: unverified items, all-deferred guard |
| PostToolUse | Write | validate-sprint-close.sh | Check roadmap marks, deferred acknowledgment |
| PostToolUse | Bash | detect-test-regression.sh | CP3: scan test runner output for failures |
| PostToolUse | Bash | memory-sync.sh | After git commit: remind to update TRACKING |
| PostToolUse | Read\|WebSearch\|WebFetch\|Agent | bootstrap-guard.sh | Inject phase context + create markers |
| PreCompact | (all) | memory-sync.sh | Inject "re-read TRACKING after compaction" + last 5 session notes |
| Stop | (all) | memory-sync.sh | Block stop if TRACKING not updated |

## memory-sync.sh

The central memory persistence hook. Handles four events:

**SessionStart** -- Emits `additionalContext` telling the AI to read TRACKING.md. If `Tools/sprint-tools` exists, includes the tool list (state, review, item, checkpoint, etc.).

**PreCompact** -- Worded for post-compaction recovery: "Context is being compacted. After compaction, read TRACKING.md to restore sprint state." Also extracts the last 5 session notes from §Session Notes table and injects them into `additionalContext`, so recent decisions/observations survive compaction.

**PostToolUse/Bash** -- Detects successful `git commit` by matching the command string against `git commit` and the output against the `[branch hash]` pattern. Extracts the commit hash and emits a reminder to update TRACKING.md board, changelog, and risks. If sprint-tools exists, suggests `sprint-tools item` instead of manual edit.

**Stop** -- Calls `tracking_needs_update()` to decide whether to block. The function returns true (needs update) when:
- TRACKING.md does not contain today's date, AND
- There are uncommitted changes to non-TRACKING files, OR there are commits made today

If blocking, emits a JSON `{"decision":"block","reason":"..."}` listing what must be updated before stopping. Uses `stop_hook_active` to avoid infinite recursion.

TRACKING file detection: checks `.dev/TRACKING.md` first (dogfooding), then `TRACKING.md` (user projects).

## session-start.sh

Runs at SessionStart. Three paths:

1. **No TRACKING.md and no CLAUDE.md** -- Checks if WORKFLOW.md exists. If yes, injects first-time setup guidance ("bootstrap this project"). If no workflow file either, exits silently (not a sprint project).

2. **sprint-tools available** -- Runs `sprint-tools state` to get a pre-formatted sprint digest. Injects it directly as `additionalContext`, saving the AI from reading the file itself.

3. **No sprint-tools** -- Falls back to instructing the AI to read CLAUDE.md and TRACKING.md manually.

Additional checks:
- **Version mismatch**: Compares `workflow-version` comment in WORKFLOW.md against `HOOKS_VERSION` in hooks-config.sh. Warns if they differ.
- **Cross-audit status**: Reports whether `CROSS_AUDIT_API_KEY` is configured in `.env`.
- **Deprecated var**: Warns if `ENABLE_CROSS_AUDIT` is still in `.env` (removed variable).

## Protection Hooks

**protect-claude.sh** (PreToolUse/Write) -- Blocks the Write tool on any file named `CLAUDE.md` that already exists. The Edit tool is allowed (partial modifications are safe). Write is allowed if the file does not exist yet (bootstrap creation) or if the file still contains `[REQUIRED` placeholders (bootstrap fill).

**bootstrap-phase-gate.sh** (PreToolUse/Write|Edit) -- Blocks creation of project files (CLAUDE.md, TRACKING.md, Roadmap.md, CODING_GUARDRAILS.md) until bootstrap markers (`.bootstrap/research-done`, `.bootstrap/review-done`) exist. Only active during bootstrap (detected by `[REQUIRED` in CLAUDE.md skeleton). Outside bootstrap, exits silently.

**protect-secrets.sh** (PreToolUse/Read|Bash) -- Two layers:
- Read tool: blocks `.env`, `.env.*`, `*.key`, `*.pem`, `*.p12`, `credentials.json`, `secrets.yaml`. Allows `.env.example`.
- Bash tool: blocks `cat|head|tail|less|more|bat|source` commands that reference secret file patterns. Intentionally simple -- a tripwire, not a sandbox.

## Validation Hooks

**validate-tracking.sh** (PostToolUse/Edit|Write) -- Fires only when the edited file contains "TRACKING.md" in the path. Checks:
1. Status values must be one of: `open|in_progress|fixed|verified|deferred|blocked`
2. `verified` rows must have non-empty evidence column
3. `deferred` rows must have a reason

Exits 1 on violations (non-blocking warning).

**validate-id-uniqueness.sh** (PostToolUse/Edit|Write) -- Fires only on TRACKING.md. Extracts all `CORE-###` IDs and reports duplicates. Non-blocking.

## Gate Hooks

**entry-gate-session.sh** (PostToolUse/Write) -- Fires when a file matching `*_ENTRY_GATE.md*` is written. Injects a mandatory session boundary recommendation: "Entry Gate complete. Recommend starting a new session for implementation."

**validate-close-gate.sh** (PostToolUse/Write) -- Fires on `*_CLOSE_GATE.md*`. Two checks:
- CP4: scans TRACKING for items with status open/in_progress/fixed and empty evidence
- All-deferred guard: blocks if every item is deferred (at least one must be verified)

**validate-sprint-close.sh** (PostToolUse/Write) -- Fires on `*_SPRINT_CLOSE.md*`. Checks:
- Roadmap.md has checked items (`[x]` or `[~]`)
- Warns about deferred item count for acknowledgment in close report

## Bootstrap Hooks

**bootstrap-guard.sh** (PostToolUse/Read|WebSearch|WebFetch|Agent) -- Active only during bootstrap (CLAUDE.md has `[REQUIRED` placeholders). Detects which bootstrap phase file was read and injects phase-specific context via `additionalContext`. Creates marker files (`.bootstrap/research-done` on WebSearch/WebFetch, `.bootstrap/review-done` on Agent when `plan-draft.md` exists). Markers gate the phase-gate hook above. Also warns about crash recovery when stale `.bootstrap/plan-draft.md` is found.

## Audit Signal Hooks

**detect-audit-signals.sh** (SessionStart + PostToolUse/Edit|Write on TRACKING.md) -- Detects two checkpoint signals by parsing structured tables in TRACKING.md:
- CP1: Metric regression >=20% between consecutive sprints (reads `Performance Baseline Log` table)
- CP2: Same failure category appearing in 2+ sprints (reads `Failure Mode History` table)

Silent when sections are missing. Persists findings to `.findings-log`. Thresholds configurable via `AUDIT_CP1_THRESHOLD` and `AUDIT_CP2_MIN_SPRINTS`.

**detect-test-regression.sh** (PostToolUse/Bash) -- Gate 1: checks if the Bash command matches a known test runner (pytest, jest, go test, cargo test, etc. -- 20+ patterns). Gate 2: scans output for failure patterns specific to each runner. Gate 3: if no failures matched, resets the escalation counter and exits. On failure, tracks consecutive failures in `.claude/.state/escalation-counter.json` and injects CP3 AUDIT SIGNAL with graduated messaging: 1st failure = standard required actions, 2nd = L2 approach escalation reminder (IMPL-LOOP §B.2), 3rd+ = 3-strike stop directive. Counter resets on any passing run (including empty output). Agent response procedure: see AGENT-RULES.md §CP3 Response.

**cross-llm-audit.sh** (PostToolUse/Edit|Write) -- Sends diffs to an external LLM. Three audit modes based on the edited file:
- `wave-review`: fires on TRACKING.md edit (item completion boundary)
- `entry-gate`: sends the gate report content for plan review
- `close-gate`: full sprint diff against main branch
- Other source file edits are skipped (gates + wave-review provide sufficient coverage)

Excludes config/workflow files. Scrubs secrets from diffs. Builds context layers from TRACKING, CLAUDE.md, Roadmap, guardrails, and Entry Gate. Returns structured JSON verdict (PASS/WARN/BLOCK) with a self-audit checklist directive. Logs all invocations to `.claude/.state/cross-audit-log.jsonl`. WARN/BLOCK findings are persisted to `.findings-log`.

## Feature Flags and Workflow Modes

`.claude/hooks-config.sh` controls everything. Each hook has a flag (`HOOK_*=true|false`).

Four workflow modes set flag presets — see [WORKFLOW-MODES.md](../Workflow/WORKFLOW-MODES.md) for the full comparison table. Modes range from Freestyle (safety hooks only) to Strict (all hooks forced on, no overrides).

Override priority: env var > `.env` file > hooks-config.sh defaults. In strict mode, all hooks are forced on after `.env` loading.

## Dependencies

- **jq** -- Required by all hooks. Each hook checks `command -v jq` and exits gracefully if missing.
- **python3** -- Required only if using sprint-tools (session-start.sh digest injection).
- **curl** -- Required only by cross-llm-audit.sh for API calls.
- **git** -- Used by memory-sync.sh (commit detection, tracking update check) and cross-llm-audit.sh (diff gathering). Hooks degrade gracefully in VCS=none mode.

## Hook Simulation for Testing

Hooks read JSON from stdin. Simulate any event by piping the right JSON:

```bash
# SessionStart
echo '{"hook_event_name":"SessionStart"}' | bash .claude/hooks/memory-sync.sh

# PreCompact
echo '{"hook_event_name":"PreCompact"}' | bash .claude/hooks/memory-sync.sh

# Stop (check if it would block)
echo '{"hook_event_name":"Stop"}' | bash .claude/hooks/memory-sync.sh

# PostToolUse after a git commit
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"},"tool_response":{"output":"[main abc1234] test"}}' | bash .claude/hooks/memory-sync.sh

# PostToolUse Edit on TRACKING.md
echo '{"tool_name":"Edit","tool_input":{"file_path":"TRACKING.md"}}' | bash .claude/hooks/validate-tracking.sh

# PreToolUse Write on CLAUDE.md
echo '{"tool_name":"Write","tool_input":{"file_path":"CLAUDE.md"}}' | bash .claude/hooks/protect-claude.sh

# Cross-audit wave-review (requires API key, fires on TRACKING.md edit)
echo '{"tool_name":"Edit","tool_input":{"file_path":"TRACKING.md"}}' | bash .claude/hooks/cross-llm-audit.sh
```

Set `CLAUDE_PROJECT_DIR` to the project root when testing outside Claude Code.
