# Workflow Modes — Lite / Standard / Strict

The same workflow template supports three rigor levels. Choose based on your
project size, team structure, and risk tolerance.

## Mode Comparison

| Aspect | Lite | Standard | Strict |
|--------|------|----------|--------|
| **Target** | Solo dev, small projects | Default for most projects | High-risk projects (any team size) |
| **Entry Gate** | Abbreviated only | Full or abbreviated (AI recommends) | Full always (abbreviated disabled) |
| **Close Gate** | sprint-audit.sh + verdict | Full 6-phase | Full 6-phase + peer sign-off |
| **Sprint Close** | Steps 1-3, 14 (checkmarks, status, checkpoint, handoff) | Full (steps 1-15) | Full + team review |
| **Failure mode analysis** | Skipped | Per item (3 categories) | Per item + Critical Axis depth |
| **Metric sufficiency** | Basic (9b-lite) | Full (9c) | Full + threshold review |
| **Hooks (Claude Code)** | Core safety only (5/10) | All hooks (10/10) | All hooks, overrides disabled |
| **sprint-audit.sh** | Optional | Recommended | Mandatory (exit code 1 blocks gate) |
| **Checkpoints (CP1-4)** | Disabled | Enabled | Enabled + no signal suppression |
| **Parallel execution** | Not recommended | Optional (if agent supports) | Recommended (if agent supports) |
| **Overhead** | ~5 min/gate | ~15 min/gate | ~25 min/gate |

## Lite Mode

Best for: solo developers, prototypes past throwaway stage, projects with < 5 files.

**What's active:**
- CLAUDE.md protection (never overwrite)
- Secret file protection (blocks AI from reading `.env`, `*.key`, `*.pem`, `credentials.json`)
- TRACKING.md validation (legal status values)
- Session start protocol (read TRACKING.md first)
- ID uniqueness (no duplicate CORE-### IDs)
- Abbreviated Entry Gate (always)
- Basic Close Gate (sprint-audit.sh + verdict only)
- Simplified Sprint Close (checkmarks, status update, handoff)

**What's skipped:**
- Failure mode analysis (step 9a)
- Metric sufficiency deep check (step 9c) — including fitness check
- Close Gate Phase 1c (fitness review) — skipped for abbreviated-gate sprints
- Approach selection (step A.6) — still runs if triggered, but abbreviated gate produces less context
- Checkpoint signals (CP1-4)
- Entry Gate session boundary enforcement
- Close Gate and Sprint Close report validation hooks
- Architecture Review triggers

**Parallel execution:** Not recommended. Abbreviated gate + small scope means
parallelization overhead exceeds the time savings. Run sequentially.

**Note:** Sprint type detection (Phase 0) and roadmap sanity check (step 0pre) still run
in Lite mode — they are lightweight and prevent data corruption regardless of rigor level.
UNTRACKED_DEBT blocker in sprint-audit.sh also applies in Lite mode when the script is run.

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

**Parallel execution:** Optional. If the agent supports sub-agents and the sprint has
4+ independent items, parallel execution can reduce gate time by 40-60% at ~2-3x token cost.
See [PARALLEL-EXECUTION.md](PARALLEL-EXECUTION.md) §Token Cost Trade-off. Evaluate at Entry Gate via dependency graph.

**How to activate:**
```bash
# .claude/hooks-config.sh
WORKFLOW_MODE="standard"
```

## Strict Mode

Best for: high-risk projects regardless of team size — production systems, regulated domains (finance, medical, security-critical).

**Parallel execution:** Recommended when agent supports it. Full gate with per-item
failure mode analysis and fitness review benefits most from parallel waves (~2-3x tokens,
~40-50% faster). See [PARALLEL-EXECUTION.md](PARALLEL-EXECUTION.md) §Token Cost Trade-off.

**Everything in Standard, plus:**
- Abbreviated Entry Gate disabled — full gate always runs (including fitness check at 9c, approach selection at A.6)
- All hooks are forced on (individual overrides ignored)
- Checkpoint signals cannot be suppressed (CP3/CP4 are already non-suppressible; strict makes CP1/CP2 non-suppressible too)
- Close Gate requires explicit peer sign-off before Sprint Close
- Close Gate Phase 1c (fitness review) always runs — CONCERN verdicts must be resolved or explicitly approved
- sprint-audit.sh exit code 1 blocks Close Gate (in Standard, findings are reviewed but non-blocking)
- UNTRACKED_DEBT blocker findings cannot be dismissed as false positives without team review

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
- Close Gate verdict requires team lead sign-off (or peer sign-off for Pair topology)
- Sprint Close retrospective presented to team
- See [TEAM-GUIDE.md](TEAM-GUIDE.md) for per-person TRACKING files, branch naming, and dependency rules

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

Team project?
  YES ↓                          NO ↓
  Any high-risk factor?          Any high-risk factor?
  (see list below)               (see list below)
  YES → Strict                   YES → Strict
  NO  → Standard                 NO  → Standard

High-risk factors:
  • Regulated domain (finance, medical, legal, security-critical)
  • Production system with real users
  • Deployment frequency > 1x/week
  • Data loss or security breach would cause significant harm
```

**Risk assessment guidance:**
- **Low risk:** Internal tools, personal projects, learning exercises, pre-launch products
  with no real user data. Lite is sufficient.
- **Medium risk:** Products with users but non-critical domain, open-source libraries,
  internal services with fallback. Standard provides adequate safety nets.
- **High risk:** Financial transactions, medical/health data, authentication/authorization,
  infrastructure, multi-tenant SaaS, anything with regulatory compliance requirements.
  Strict is strongly recommended — the overhead pays for itself in prevented incidents.

When in doubt, start with Standard. Upgrade to Strict when a high-risk factor emerges
(first production incident, regulatory requirement, real user data at stake).
