# Workflow Modes — Freestyle / Lite / Standard / Strict

The same workflow template supports four rigor levels. Choose based on your
project size, team structure, and risk tolerance.

## Mode Comparison

| Aspect | Freestyle | Lite | Standard | Strict |
|--------|-----------|------|----------|--------|
| **Target** | Hackathon, experiments, learning | Solo dev, small projects | Default for most projects | High-risk projects (any team size) |
| **Entry Gate** | None enforced | Abbreviated only | Full or abbreviated (AI recommends) | Full always (abbreviated disabled) |
| **Close Gate** | None enforced | sprint-audit.sh + verdict (hook enforced) | Full 6-phase | Full 6-phase + peer sign-off |
| **Sprint Close** | None enforced | Steps 1-3, 5, 14 (checkmarks, status, baseline, handoff) | Full (steps 1-15) | Full + team review |
| **Failure mode analysis** | Skipped | Skipped | Per item (3 categories) | Per item + Critical Axis depth |
| **Metric sufficiency** | Skipped | Basic (9b-lite) | Full (9c) | Full + threshold review |
| **Hooks (Claude Code)** | Core safety only (5/11) | Core + close gate + test regression (7/11) | All hooks (11/11) | All hooks, overrides disabled |
| **sprint-audit.sh** | Optional | Optional | Recommended | Mandatory (exit code 1 blocks gate) |
| **Checkpoints (CP1-2)** | Disabled | Disabled | Enabled (suppressible ×2) | Enabled + no suppression |
| **Checkpoints (CP3-4)** | Disabled | Enabled (never suppressed) | Enabled (never suppressed) | Enabled (never suppressed) |
| **Performance Baseline** | Not recorded | Recorded (Sprint Close step 5) | Recorded | Recorded |
| **Cross-audit defaults** | N/A (not tuned) | wave-size 8, min-changes 5 | wave-size 5, min-changes 3 | wave-size 3, min-changes 1, enforce-block |
| **Parallel execution** | Not recommended | Not recommended | Optional (if agent supports) | Recommended (if agent supports) |
| **Overhead** | ~0 min/gate | ~7 min/gate | ~15 min/gate | ~25 min/gate |

## Freestyle Mode

Best for: hackathons, jam sessions, experiments, learning, single-file scripts.

AI follows WORKFLOW.md voluntarily but no hooks enforce gates or audits.
This is the fastest mode — zero workflow overhead.

**What's active:**
- CLAUDE.md protection (never overwrite)
- Secret file protection (blocks AI from reading `.env`, `*.key`, `*.pem`, `credentials.json`)
- TRACKING.md validation (legal status values)
- Session start protocol (read TRACKING.md first)
- ID uniqueness (no duplicate CORE-### IDs)

**What's skipped:**
- All gate enforcement (Entry Gate, Close Gate, Sprint Close)
- All checkpoint signals (CP1-4)
- Test regression detection
- Failure mode analysis
- Performance Baseline recording
- Architecture Review triggers

**Cross-audit:** Not tuned for this mode. If enabled manually, uses global defaults.

**Cascade effect:** AI can skip any gate without enforcement. Quality debt may
accumulate silently. Acceptable for throwaway or experimental work.

**How to activate:**
```bash
# .claude/hooks-config.sh
WORKFLOW_MODE="freestyle"
```

For non-Claude agents: tell the agent at session start:
> "Use freestyle mode — follow sprint structure loosely, skip formal gates."

## Lite Mode

Best for: solo developers, prototypes past throwaway stage, projects with < 10 files.

Lightweight but controlled — close gate and test regression are enforced to prevent
silent quality debt. Entry gate runs abbreviated but is not hook-enforced.

**What's active:**
- CLAUDE.md protection (never overwrite)
- Secret file protection (blocks AI from reading `.env`, `*.key`, `*.pem`, `credentials.json`)
- TRACKING.md validation (legal status values)
- Session start protocol (read TRACKING.md first)
- ID uniqueness (no duplicate CORE-### IDs)
- **Close Gate validation hook (CP4)** — ensures close gate report exists and has no unverified must items
- **Test regression detection (CP3)** — surfaces test failures instead of silently continuing
- Abbreviated Entry Gate (always)
- Basic Close Gate (sprint-audit.sh + verdict)
- Simplified Sprint Close with **Performance Baseline recording** (step 5)

**What's skipped:**
- Failure mode analysis (step 9a)
- Metric sufficiency deep check (step 9c) — including fitness check
- Close Gate Phase 1c (fitness review) — skipped for abbreviated-gate sprints
- Checkpoint signals CP1/CP2 (metric regression, recurring failures)
- Entry Gate session boundary enforcement
- Sprint Close report validation hook
- Architecture Review triggers

**Cross-audit defaults:** wave-size 8, min-changes 5.
Relaxed settings appropriate for small projects — fewer API calls, less context sent.

**Parallel execution:** Not recommended. Abbreviated gate + small scope means
parallelization overhead exceeds the time savings. Run sequentially.

**Key difference from Freestyle:** Close Gate cannot be silently skipped — the
`validate-close-gate` hook ensures a verdict exists. Test failures are surfaced
via CP3. Performance Baseline is recorded, enabling CP1 detection if upgraded
to Standard later.

**Note:** Sprint type detection (Phase 0) and roadmap sanity check (step 0pre) still run
in Lite mode — they are lightweight and prevent data corruption regardless of rigor level.
UNTRACKED_DEBT blocker in sprint-audit.sh also applies in Lite mode when the script is run.

**How to activate:**
```bash
# .claude/hooks-config.sh
WORKFLOW_MODE="lite"
```

For non-Claude agents: tell the agent at session start:
> "Use lite mode — abbreviated entry gates, basic close gate with verdict, skip failure mode analysis and metric sufficiency."

## Standard Mode

Best for: most projects, solo or small teams, 5-50 file codebases.

This is the default. All workflow features and hooks are active.
The AI recommends abbreviated vs. full Entry Gate based on sprint size.

**Cross-audit defaults:** wave-size 5, min-changes 3.
Balanced settings — moderate review frequency with standard context (includes sprint goal, AC, contracts).

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

**Cross-audit defaults:** wave-size 3, min-changes 1, enforce-block true.
Tightest settings — every small change reviewed, full file context sent (includes sprint goal, AC, contracts, full file), BLOCK verdicts exit non-zero to prevent continuing past critical issues.

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

## Inspecting Mode Effects

To see the full impact of the current mode (which hooks are on/off, all audit defaults, active overrides):

```bash
sprint-workflow config mode --show
```

The `config` display also marks each setting with `(mode)`, `(override)`, or `(.env)` to show where each value comes from. Setting a mode-aware value warns when it diverges from the mode default.

## Switching Modes

Modes can be changed at any time between sprints. Changing mid-sprint is valid
but requires logging in TRACKING.md Change Log:

```
- [date] Workflow mode changed: [old] → [new]. Reason: [why].
```

**Upgrading (freestyle → lite → standard → strict):** No data loss. Additional checks will
run at the next gate boundary. Performance Baseline data (if recorded in lite+) will be
picked up by CP1 in standard/strict.

**Downgrading (strict → standard → lite → freestyle):** Some checks will stop running.
Existing data (failure modes, metrics, baselines) is preserved in TRACKING.md
and will be picked up again if mode is upgraded later.

## Mode Selection Guide

```
Is this a throwaway prototype?
  YES → Don't use this workflow at all
  NO  ↓

Hackathon, experiment, or learning exercise?
  YES → Freestyle
  NO  ↓

Solo developer, < 10 files, low risk?
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
- **Minimal risk:** Hackathons, jam sessions, learning, experiments. Freestyle is sufficient —
  no gates, just sprint structure for organization.
- **Low risk:** Internal tools, personal projects, pre-launch products with no real user data.
  Lite provides basic close-gate enforcement without heavy overhead.
- **Medium risk:** Products with users but non-critical domain, open-source libraries,
  internal services with fallback. Standard provides adequate safety nets.
- **High risk:** Financial transactions, medical/health data, authentication/authorization,
  infrastructure, multi-tenant SaaS, anything with regulatory compliance requirements.
  Strict is strongly recommended — the overhead pays for itself in prevented incidents.

When in doubt, start with Standard. Downgrade to Lite if overhead feels excessive for
your project size. Upgrade to Strict when a high-risk factor emerges
(first production incident, regulatory requirement, real user data at stake).
