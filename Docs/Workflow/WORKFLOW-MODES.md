<instructions>

# CRITICAL: Strict mode = full gates always, no abbreviated, no hook overrides, no CP suppression.
# CRITICAL: Mode changes mid-sprint require TRACKING.md Change Log entry.

# Workflow Modes: Freestyle / Lite / Standard / Strict

## Mode Comparison

| Aspect | Freestyle | Lite | Standard | Strict |
|--------|-----------|------|----------|--------|
| Target | Hackathon, experiments | Solo, small projects | Default most projects | High-risk (any size) |
| Entry Gate | None enforced | Abbreviated only | Full or abbreviated | Full always |
| Close Gate | None enforced | sprint-audit + verdict | Full 6-phase | Full 6-phase + peer sign-off |
| Sprint Close | None enforced | Steps 1-3, 5, 14 | Full (1-15) | Full + team review |
| Failure analysis | Skip | Skip | Per item (3 cat) | Per item + Critical Axis |
| Metric sufficiency | Skip | Basic (9b-lite) | Full (9c) | Full + threshold review |
| Hooks | Core safety (8/14) | Core + close + test + audit (11/14) | All (14/14) | All, overrides disabled |
| sprint-audit.sh | Optional | Optional | Recommended | Mandatory (blocks gate) |
| CP1-2 | Disabled | Disabled | Enabled (suppress x2) | Enabled, no suppression |
| CP3-4 | Disabled | Enabled | Enabled | Enabled |
| Perf Baseline | Not recorded | Recorded | Recorded | Recorded |
| Cross-audit | Off | On | On | On, enforce-block |
| Parallel exec | No | No | Optional | Recommended |
| Overhead | ~0 min | ~7 min | ~15 min | ~25 min |

## Freestyle

Activate: `WORKFLOW_MODE="freestyle"` in hooks-config.sh

Active: CLAUDE.md protection, secret protection, TRACKING validation, session start, ID uniqueness, memory sync.
Skipped: all gate enforcement, all checkpoints, test regression, failure analysis, perf baseline.

Cross-audit: not tuned. AI can skip any gate without enforcement.

## Lite

Activate: `WORKFLOW_MODE="lite"` in hooks-config.sh

Active (adds to Freestyle): close gate validation (CP4), test regression (CP3), abbreviated entry gate, basic close gate, sprint close with perf baseline (step 5).
Skipped: failure mode analysis (9a), metric sufficiency (9c), fitness review (1c), CP1/CP2, entry gate session enforcement, sprint close report validation.

Phase 0 (sprint type detection) and step 0pre (roadmap sanity) still run. UNTRACKED_DEBT blocker applies when sprint-audit.sh runs.

## Standard

Activate: `WORKFLOW_MODE="standard"` (default)

All workflow features and hooks active. AI recommends abbreviated vs full entry gate by sprint size.
Cross-audit: on, non-blocking.
Parallel: optional (4+ independent items -> 40-60% gate time reduction at 2-3x tokens).

## Strict

Activate: `WORKFLOW_MODE="strict"`

Everything in Standard plus:
1. Abbreviated entry gate disabled. Full gate always (including fitness 9c, approach A.6).
2. All hooks forced on (individual overrides ignored).
3. CP1/CP2 non-suppressible (CP3/CP4 already non-suppressible).
4. Close Gate requires peer sign-off.
5. Close Gate Phase 1c (fitness review) always runs. CONCERN verdicts must be resolved.
6. sprint-audit.sh exit code 1 blocks Close Gate.
7. UNTRACKED_DEBT findings require team review to dismiss.

Cross-audit: on, enforce-block true (BLOCK verdict halts the agent).
Parallel: recommended (2-3x tokens, 40-50% faster).

Team conventions (strict) — see [TEAM-GUIDE.md](TEAM-GUIDE.md) for full team coordination:
- Atomic commits required
- Entry Gate reviewed by second member
- Close Gate verdict requires lead/peer sign-off
- Sprint Close retrospective presented to team

## Inspect Mode Effects

Check `hooks-config.sh` directly to see all hooks on/off, audit defaults, and overrides. Each setting is marked by its source: mode default, user override, or `.env`.

## Switching Modes

Log mid-sprint changes: `[date] Workflow mode changed: [old] -> [new]. Reason: [why].`

Upgrading (freestyle->lite->standard->strict): no data loss. Additional checks run at next gate.
Downgrading: some checks stop. Existing data preserved, picked up if upgraded later.

## Mode Selection

```
IF throwaway prototype: don't use workflow.
ELIF hackathon/experiment/learning: Freestyle.
ELIF solo, <10 files, low risk: Lite.
ELIF high-risk factor exists: Strict.
ELSE: Standard.
```

High-risk factors: regulated domain, production with real users, deploy >1x/week, data loss/breach causes significant harm.

When in doubt: start Standard. Downgrade to Lite if overhead excessive. Upgrade to Strict when high-risk factor emerges.

# CRITICAL: Strict = full gates, no abbreviated, no overrides, no CP suppression.
# CRITICAL: Mode changes mid-sprint require TRACKING.md Change Log entry.

</instructions>
