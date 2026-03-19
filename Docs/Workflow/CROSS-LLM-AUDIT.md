<instructions>

# Cross-LLM Audit

**CRITICAL: Log ALL WARN/BLOCK findings to TRACKING.md Change Log. Never skip logging even if disagreed with.**
**CRITICAL: BLOCK verdicts require user review before proceeding. Claude cannot dismiss alone.**

## 1. Overview

Send code diffs to a second LLM for independent review. Results arrive as `additionalContext`. Requires Claude Code hook system (`PostToolUse`). Zero impact when no API key configured.

## 2. Audit Modes

Hook fires on `PostToolUse(Edit|Write)`:

| Mode | Trigger | Diff Source | Focus |
|------|---------|-------------|-------|
| **Per-edit** | Source file change (wave-batched) | `git diff HEAD` (uncommitted) | Bugs, security, AC, integration risk |
| **Wave Review** | `TRACKING.md` edited | `git diff HEAD~1` (last commit) | Cross-item integration + code quality (dual-axis) |
| **Close Gate** | `S*_CLOSE_GATE.md` written | `git diff main...HEAD` (full sprint) | Cross-item consistency, architecture, failure modes |
| **Entry Gate** | `S*_ENTRY_GATE.md` written | Gate report content | Plan quality, missing risks, AC vs guardrails |

Gate reviews (Close/Entry) fire immediately, bypass wave counting.

## 3. Setup

### Guided (Recommended)
```bash
bash .claude/setup-audit.sh
```
Verify: make a 3+ line code change, check stderr for "Cross-audit:" messages.

### Manual
1. Set API key in `.env` (git-ignored): `CROSS_AUDIT_API_KEY=your-key-here`
2. Optionally override provider/model in `.env`:
```bash
CROSS_AUDIT_PROVIDER=anthropic   # or openai (default)
CROSS_AUDIT_MODEL=claude-sonnet-4-20250514
CROSS_AUDIT_LANG=tr              # en (default) or tr
```

### Supported Providers

| Provider | `CROSS_AUDIT_PROVIDER` | API Base |
|----------|----------------------|----------|
| OpenAI | `openai` (default) | `https://api.openai.com/v1` |
| Anthropic | `anthropic` | `https://api.anthropic.com` |
| GitHub Models | `openai` | `https://models.inference.ai.azure.com` |
| Azure OpenAI | `openai` | `https://{name}.openai.azure.com/openai/deployments/{deploy}` |
| OpenRouter | `openai` | `https://openrouter.ai/api/v1` |
| Ollama (local) | `openai` | `http://localhost:11434/v1` |
| LM Studio | `openai` | `http://localhost:1234/v1` |

Config precedence: env var > `.env` > `hooks-config.sh` defaults (`_D_*`).

## 4. Configuration Reference

### Core Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `CROSS_AUDIT_PROVIDER` | `openai` | `openai` or `anthropic` |
| `CROSS_AUDIT_LANG` | `en` | `en` or `tr` |
| `CROSS_AUDIT_TIMEOUT` | `60` | API timeout (seconds) |
| `CROSS_AUDIT_ENFORCE_BLOCK` | `false` | Exit non-zero on BLOCK verdict |
| `CROSS_AUDIT_WAVE_SIZE` | `5` | Edits before wave fires |
| `CROSS_AUDIT_MAX_DIFF` | `32000` | Base diff limit (chars). Per-edit=x0.75, wave=x1, entry-gate=x1, close-gate=x1.5 |

Force immediate audit: `export CROSS_AUDIT_FIRE=true`

Override per-mode limits: `CROSS_AUDIT_MAX_DIFF_PER_EDIT`, `_WAVE`, `_ENTRY_GATE`, `_CLOSE_GATE`.

### Audit Signal Thresholds

| Setting | Default | Description |
|---------|---------|-------------|
| `AUDIT_CP1_THRESHOLD` | `0.20` | Metric regression threshold (20%) |
| `AUDIT_CP2_MIN_SPRINTS` | `2` | Recurring failure: same category in N+ sprints |

## 5. What Gets Sent

### Context Layers (all modes)
- Diff (mode-specific source)
- Sprint goal + progress from Roadmap.md / TRACKING.md
- Active items (status `in_progress` or `fixed`)
- Critical axis from CLAUDE.md
- Immutable contracts (except entry-gate: plan review, not code)
- Guardrails + failure modes + acceptance criteria
- Per-edit: full content of edited file (first 8000 chars)

### Skipped Files (never trigger hook)
`CLAUDE.md`, `WORKFLOW*.md`, `*Roadmap*.md`, `*SPRINT_CLOSE*`, `*GUARDRAILS*`, `*LESSONS*`, `*.json`, `*.yaml`, `*.yml`, `*.toml`, `*.lock`, `*.env*`

Note: `TRACKING*.md` triggers wave-review mode, not skipped.

## 6. Verdict Handling

| Verdict | Action |
|---------|--------|
| **PASS** | Mention as confidence signal |
| **WARN** | Present warnings, user decides |
| **BLOCK** | Present blocking issues, halt until user reviews |
| **BLOCK** (enforced) | `CROSS_AUDIT_ENFORCE_BLOCK=true`: hook exits non-zero |

IF Claude and external LLM disagree:
  Present BOTH perspectives clearly.
  State own position.
  User decides. Neither auto-overrides.

## 7. Dual Review Protocol

```
External verdict arrives →
  Claude runs self-audit (8-item checklist) on same diff →
  IF AGREE → auto-fix, inform user
  ELIF DISAGREE on BLOCK → escalate (mandatory)
  ELIF DISAGREE on WARN → log disagreement, continue
  IF close-gate mode → report only, NO auto-fix
```

### Decision Matrix

| Verdict | Agreement | Action |
|---------|-----------|--------|
| BLOCK | Agree | Auto-fix, inform user |
| BLOCK | Disagree | Escalate both perspectives (mandatory) |
| WARN | Agree | Auto-fix + log in Change Log |
| WARN | Disagree | Log disagreement, continue |
| PASS | -- | Lightweight self-audit (items 1-3 only) |

### Self-Audit Checklist

Full (BLOCK/WARN):
1. BUG SCAN: off-by-one, null/undefined, type mismatch, boundary, resource leak
2. SECURITY SCAN: input validation, auth/authz, no secrets, injection vectors
3. AC COMPLIANCE: diff supports AC, no missing AC
4. GUARDRAIL COMPLIANCE: CODING_GUARDRAILS.md rules
5. INTEGRATION RISK: conflicts with active items, shared state, API changes
6. CRITICAL AXIS CHECK: improves or degrades critical axis?
7. FAILURE MODE CHECK: predicted modes from Entry Gate + new unpredicted
8. REGRESSION RISK: changes behavior validated by existing tests

Lightweight (PASS): items 1-3 only.

## 8. Error Handling

| Scenario | Behavior |
|----------|----------|
| API key missing | Silent skip, zero impact |
| API timeout/network error | Skip, stderr warning, continue |
| API error (rate limit, auth) | Skip, stderr log, continue |
| Empty response | Skip, stderr warning |
| Invalid JSON response | Display as-is, best-effort |

Default: non-blocking. `CROSS_AUDIT_ENFORCE_BLOCK=true` makes BLOCK verdicts exit non-zero.

## 9. Data Safety

### Layer 1: File Exclusions from git diff
`*.env`, `*.env.*`, `*.key`, `*.pem`, `*.p12`, `*credentials*`, `*secrets*`

### Layer 2: Secret Scrubbing
Before sending any diff, scrub: `sk-*`, `sk-ant-*`, `ghp_*`, `gho_*`, `ghu_*`, `xox[bpsar]-*`, `AKIA*`, `ASIA*`, password/secret/api_key/token assignments, Bearer tokens, private key blocks, connection strings. Replace with `[REDACTED]`.

### Layer 3: Safe Implementation
- `.env` parser uses `printenv` (no `eval`), keys validated against `^[A-Z][A-Z0-9_]*$`
- Large payloads via temp file + `jq --rawfile` (avoids ARG_MAX). Cleanup via `trap EXIT`
- `.gitignore` includes `.env`, `*.key`, `*.pem`, `credentials.json`, `secrets.yaml`

## 10. Pre-Merge Audit

```bash
bash .claude/hooks/pre-merge-audit.sh /tmp/worktree-agent-1   # worktree path
bash .claude/hooks/pre-merge-audit.sh sprint-1-agent-branch    # branch name
```
Exit 0 = PASS/WARN (safe to merge). Exit 1 = BLOCK (do not merge).
Insert between coordinator steps 1-2 in between-wave review.

## 11. Evidence Verification

```bash
bash .claude/hooks/verify-evidence.sh < agent-report.txt
```
Checks `file:line` references exist and are in range. Exit 0 = all valid, exit 1 = invalid found.
Semantic verification left to coordinator judgment.

## 12. Audit Log & Health Check

Log: `.claude/.state/cross-audit-log.jsonl` (JSONL). Auto-rotates at 1MB, keeps last 500 entries.

```bash
bash .claude/hooks/audit-health-check.sh        # 1 hour staleness
bash .claude/hooks/audit-health-check.sh 1800   # 30 min
```

## 13. Workflow Mode Interaction

Cross-LLM audit is **disabled** in freestyle mode (`HOOK_CROSS_LLM_AUDIT=false`). In lite, standard, and strict modes it activates when API key is present.

| Mechanism | Freestyle | Lite | Standard | Strict |
|-----------|:---------:|:----:|:--------:|:------:|
| cross-llm-audit hook | off | on | on | on |
| Wave size (edits before fire) | — | 8 | 5 | 3 |
| enforce-block (BLOCK → exit 1) | — | no | no | yes |
| sprint-tools review (blind) | available | available | available | available |
| pre-merge-audit (parallel exec) | — | — | optional | recommended |
| detect-audit-signals (CP1/CP2) | off | off | on | on (no suppress) |
| detect-test-regression (CP3) | off | on | on | on |
| validate-close-gate (CP4) | off | on | on | on |
| Entry Gate blind review (12a) | not enforced | abbreviated | full/abbreviated | full always |
| Close Gate blind review | not enforced | basic | full 6-phase | full + peer sign-off |

`sprint-tools review` is available in all modes but not mechanically enforced — soft-enforced via AGENT-RULES.md §Blind Review. Requires API key; skips gracefully without one.

Audit signal hooks (CP1/CP2 via `detect-audit-signals.sh`) are controlled by workflow mode. Override: `HOOK_DETECT_AUDIT_SIGNALS=true`.

## 14. Disabling

Remove API key from `.env`. Hook silently skips without a key.

**CRITICAL: Log ALL WARN/BLOCK findings to TRACKING.md Change Log. Never skip logging even if disagreed with.**
**CRITICAL: BLOCK verdicts require user review before proceeding. Claude cannot dismiss alone.**

</instructions>
