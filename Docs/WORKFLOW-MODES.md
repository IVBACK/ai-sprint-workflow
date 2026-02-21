# Workflow Modes — Lite / Standard / Strict

The same workflow template supports three rigor levels. Choose based on your
project size, team structure, and risk tolerance.

## Mode Comparison

| Aspect | Lite | Standard | Strict |
|--------|------|----------|--------|
| **Target** | Solo dev, small projects | Default for most projects | Teams, critical systems |
| **Entry Gate** | Abbreviated only | Full or abbreviated (AI recommends) | Full always (abbreviated disabled) |
| **Close Gate** | sprint-audit.sh + verdict | Full 5-phase | Full 5-phase + peer sign-off |
| **Sprint Close** | Steps 1-3, 14 (checkmarks, status, checkpoint, handoff) | Full (steps 1-15) | Full + team review |
| **Failure mode analysis** | Skipped | Per item (3 categories) | Per item + Critical Axis depth |
| **Metric sufficiency** | Basic (9b-lite) | Full (9c) | Full + threshold review |
| **Hooks (Claude Code)** | Core safety only (4/9) | All hooks (9/9) | All hooks, overrides disabled |
| **sprint-audit.sh** | Optional | Recommended | Mandatory (exit code 1 blocks gate) |
| **Checkpoints (CP1-4)** | Disabled | Enabled | Enabled + no signal suppression |
| **Overhead** | ~5 min/gate | ~15 min/gate | ~25 min/gate |

## Lite Mode

Best for: solo developers, prototypes past throwaway stage, projects with < 5 files.

**What's active:**
- CLAUDE.md protection (never overwrite)
- TRACKING.md validation (legal status values)
- Session start protocol (read TRACKING.md first)
- ID uniqueness (no duplicate CORE-### IDs)
- Abbreviated Entry Gate (always)
- Basic Close Gate (sprint-audit.sh + verdict only)
- Simplified Sprint Close (checkmarks, status update, handoff)

**What's skipped:**
- Failure mode analysis (step 9a)
- Metric sufficiency deep check (step 9c)
- Checkpoint signals (CP1-4)
- Entry Gate session boundary enforcement
- Close Gate and Sprint Close report validation hooks
- Architecture Review triggers

**How to activate:**
```bash
# .claude/hooks-config.sh
WORKFLOW_MODE="lite"
```

For non-Claude agents: tell the agent at session start:
> "Use lite mode — abbreviated entry gates, skip failure mode analysis and metric sufficiency."

## Standard Mode

Best for: most projects, solo or small teams, 5-50 file codebases.

This is the default. All workflow features and hooks are active.
The AI recommends abbreviated vs. full Entry Gate based on sprint size.

**How to activate:**
```bash
# .claude/hooks-config.sh
WORKFLOW_MODE="standard"
```

## Strict Mode

Best for: teams, production systems, regulated domains (finance, medical, security-critical).

**Everything in Standard, plus:**
- Abbreviated Entry Gate disabled — full gate always runs
- All hooks are forced on (individual overrides ignored)
- Checkpoint signals cannot be suppressed (CP3/CP4 are already non-suppressible; strict makes CP1/CP2 non-suppressible too)
- Close Gate requires explicit peer sign-off before Sprint Close
- sprint-audit.sh exit code 1 blocks Close Gate (in Standard, findings are reviewed but non-blocking)

**How to activate:**
```bash
# .claude/hooks-config.sh
WORKFLOW_MODE="strict"
```

For non-Claude agents: tell the agent at session start:
> "Use strict mode — full entry gates always, no abbreviated mode, all findings must be resolved before gate closes."

**Additional strict mode conventions (team):**
- Atomic commits required (not monolithic)
- Entry Gate report reviewed by second team member before approval
- Close Gate verdict requires team lead sign-off
- Sprint Close retrospective presented to team

## Switching Modes

Modes can be changed at any time between sprints. Changing mid-sprint is valid
but requires logging in TRACKING.md Change Log:

```
- [date] Workflow mode changed: [old] → [new]. Reason: [why].
```

**Upgrading (lite → standard → strict):** No data loss. Additional checks will
run at the next gate boundary.

**Downgrading (strict → standard → lite):** Some checks will stop running.
Existing data (failure modes, metrics, baselines) is preserved in TRACKING.md
and will be picked up again if mode is upgraded later.

## Mode Selection Guide

```
Is this a throwaway prototype?
  YES → Don't use this workflow at all
  NO  ↓

Solo developer, < 5 files, low risk?
  YES → Lite
  NO  ↓

Team project or production system?
  YES → Strict
  NO  → Standard
```
