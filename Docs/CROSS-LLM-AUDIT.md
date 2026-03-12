# Cross-LLM Audit — External Code Review

Send code changes to a second LLM for independent review during implementation.
The primary agent (Claude) sees the external findings and presents them alongside its own assessment.

**Status:** Optional. Disabled by default. Zero impact when off.

**Requirement:** Claude Code. This feature uses Claude Code's hook system (`PostToolUse`, `additionalContext`) and cannot work with other agents or editors.

---

## Why

A second opinion from a different model catches blind spots. Different LLMs have different strengths — using two in tandem significantly improves code quality without slowing down the workflow.

## How It Works

```
Claude implements item → Hook detects source file change →
  Collects git diff + project context →
  Sends to external LLM API →
  External review returns as additionalContext →
  Claude presents both its own and external assessment →
  User decides
```

The hook fires on `PostToolUse(Edit|Write)` and supports three audit modes:

| Mode | Trigger | What's Reviewed | Focus |
|------|---------|-----------------|-------|
| **Per-edit** | Source file change | Uncommitted `git diff` | Bugs, security, AC coverage + integration risk |
| **Wave Review** | `TRACKING.md` edited | Last commit diff (`HEAD~1..HEAD`) | Cross-item integration + code quality (dual-axis) |
| **Close Gate** | `S*_CLOSE_GATE.md` written | Full sprint diff (`git diff main...HEAD`) | Cross-item consistency, architecture, failure mode verification |
| **Entry Gate** | `S*_ENTRY_GATE.md` written | Gate report content | Plan quality, missing risks, AC vs guardrails |

Gate reviews (Close/Entry) fire immediately regardless of wave/item trigger mode.

## Setup

### Guided Setup (Recommended)

Run the interactive setup script in your terminal:

```bash
bash .claude/setup-audit.sh
```

The script walks you through provider selection, API key entry, and optional settings.
Your API key is collected via hidden terminal input (`read -s`) and written directly to `.env`.
**The key never enters the AI conversation.**

After the script completes, make a code change with 3+ lines to verify.

> **Why not paste the key into the AI chat?** Most LLMs reject or flag API keys in
> conversation. Even if accepted, the key would appear in session logs and context.
> The setup script keeps it out of the AI's context entirely.

### Manual Setup

If you prefer manual configuration, follow these steps:

#### 1. Choose a Provider

Two provider modes are supported: **OpenAI-compatible** (default) and **Anthropic** (native).

| Provider | `CROSS_AUDIT_PROVIDER` | API Base | Key Source |
|----------|----------------------|----------|-----------|
| OpenAI | `openai` (default) | `https://api.openai.com/v1` | [platform.openai.com](https://platform.openai.com) |
| Anthropic | `anthropic` | `https://api.anthropic.com` | [console.anthropic.com](https://console.anthropic.com) |
| GitHub Models | `openai` | `https://models.inference.ai.azure.com` | GitHub PAT with `models:read` |
| Azure OpenAI | `openai` | `https://{name}.openai.azure.com/openai/deployments/{deploy}` | Azure portal |
| OpenRouter | `openai` | `https://openrouter.ai/api/v1` | [openrouter.ai](https://openrouter.ai) |
| Ollama (local) | `openai` | `http://localhost:11434/v1` | No key needed (set dummy) |
| LM Studio | `openai` | `http://localhost:1234/v1` | No key needed (set dummy) |

#### 2. Set Environment Variables

**Step 1: API key in `.env`** (secrets only — git-ignored)

Create a `.env` file in the project root:

```bash
ENABLE_CROSS_AUDIT=true
CROSS_AUDIT_API_KEY=your-api-key-here
```

The hook auto-loads `CROSS_AUDIT_API_KEY` and `ENABLE_CROSS_AUDIT` from `.env`. No `export` needed.

Alternatively, add to your shell profile (`~/.bashrc`, `~/.zshrc`, `~/.config/fish/config.fish`):

```bash
export ENABLE_CROSS_AUDIT=true
export CROSS_AUDIT_API_KEY="your-api-key-here"
```

Shell profile vars take precedence — `.env` only fills in values not already set.

**Step 2: All other settings in `.claude/hooks-config.sh`** (centralized config)

All audit settings (provider, model, trigger, language, thresholds, diff limits, etc.) are centralized in `.claude/hooks-config.sh`. Edit that file to change defaults.

For per-developer overrides, create `.claude/hooks-config.local.sh` (git-ignored):

```bash
CROSS_AUDIT_PROVIDER=anthropic
CROSS_AUDIT_MODEL=claude-sonnet-4-20250514
CROSS_AUDIT_LANG=tr
```

#### 3. Verify

Make a code change with 3+ lines. Check stderr for "Cross-audit:" messages. If the API key is valid, Claude will receive the external review as additionalContext.

---

## Configuration Reference

All settings are centralized in `.claude/hooks-config.sh` with a `_D_*` defaults table. To change a setting:
1. Edit `_D_*` value in `hooks-config.sh` (team-wide, git-tracked)
2. Or override in `.claude/hooks-config.local.sh` (personal, git-ignored)
3. Or export as env var (temporary, current shell)

### Core Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `ENABLE_CROSS_AUDIT` | `false` | Master switch — must be `true` to enable |
| `CROSS_AUDIT_PROVIDER` | `openai` | `openai` (OpenAI-compatible) or `anthropic` (native) |
| `CROSS_AUDIT_TRIGGER` | `wave` | `wave` (every N edits) or `item` (every edit) |
| `CROSS_AUDIT_CONTEXT` | `standard` | `minimal`, `standard`, or `full` (see below) |
| `CROSS_AUDIT_LANG` | `en` | `en` (English) or `tr` (Turkish) |
| `CROSS_AUDIT_MIN_CHANGES` | `3` | Edits smaller than this line count are skipped |
| `CROSS_AUDIT_TIMEOUT` | `60` | API request timeout in seconds |
| `CROSS_AUDIT_SKIP_SUBAGENT` | `true` | Skip audit in worktree sub-agents |
| `CROSS_AUDIT_ENFORCE_BLOCK` | `false` | Exit non-zero on BLOCK verdict |

### Wave Batching

| Setting | Default | Description |
|---------|---------|-------------|
| `CROSS_AUDIT_WAVE_SIZE` | `5` | Source file edits before wave fires |
| `CROSS_AUDIT_LOCK_TIMEOUT` | `5` | Flock timeout in seconds |

Force immediate audit in wave mode: `export CROSS_AUDIT_FIRE=true`

### Diff Truncation (max characters sent to external LLM)

| Setting | Default | Mode |
|---------|---------|------|
| `CROSS_AUDIT_MAX_DIFF_PER_EDIT` | `24000` | Per-edit reviews |
| `CROSS_AUDIT_MAX_DIFF_WAVE` | `32000` | Wave reviews |
| `CROSS_AUDIT_MAX_DIFF_ENTRY_GATE` | `32000` | Entry Gate plan reviews |
| `CROSS_AUDIT_MAX_DIFF_CLOSE_GATE` | `48000` | Close Gate holistic reviews |

### Audit Signal Thresholds (CP1 / CP2)

| Setting | Default | Description |
|---------|---------|-------------|
| `AUDIT_CP1_THRESHOLD` | `0.20` | Metric regression threshold (0.20 = 20%) |
| `AUDIT_CP2_MIN_SPRINTS` | `2` | Recurring failure: same category in N+ sprints |

### Log & Health

| Setting | Default | Description |
|---------|---------|-------------|
| `AUDIT_LOG_MAX_BYTES` | `1048576` | Log rotation trigger (1MB) |
| `AUDIT_LOG_KEEP_LINES` | `500` | Lines kept after rotation |
| `AUDIT_HEALTH_STALE_SECONDS` | `3600` | Health check: stale threshold (1 hour) |
| `AUDIT_HEALTH_ERROR_THRESHOLD` | `5` | Health check: error count threshold |

### Dashboard

| Setting | Default | Description |
|---------|---------|-------------|
| `DASHBOARD_SEARCH_DEPTH` | `3` | Directory depth for file search |

### API Base & Model (optional overrides)

Auto-set per provider. Override in `hooks-config.sh` or `hooks-config.local.sh`:

```bash
CROSS_AUDIT_API_BASE=https://openrouter.ai/api/v1
CROSS_AUDIT_MODEL=gpt-4o-mini
```

### CROSS_AUDIT_CONTEXT Detail

| Level | What's Sent | Token Cost |
|-------|-------------|------------|
| `minimal` | Diff + active items from TRACKING.md + critical axis | Low (~2-4k) |
| `standard` (default) | Minimal + CODING_GUARDRAILS.md + Entry Gate failure modes | Medium (~4-8k) |
| `full` | Standard + full content of changed files | High (~8-16k) |

### Internal / Testing Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `CLAUDE_PROJECT_DIR` | Project root directory | `.` (current dir) |
| `CROSS_AUDIT_COUNTER_FILE` | Override wave counter file path | `.claude/.state/cross-audit-counter-<user>` |
| `CROSS_AUDIT_FIRE` | Force immediate audit in wave mode | unset |

---

## Audit Modes

### Per-Edit (default)

Fires on source file changes. Sends uncommitted `git diff` (staged + unstaged, truncated at `CROSS_AUDIT_MAX_DIFF_PER_EDIT`, default ~24k chars). Reviews for bugs, security issues, AC coverage, coding rule violations, and **integration risk** (could this change conflict with other active items?).

Subject to wave/item trigger mode and `MIN_CHANGES` threshold.

### Wave Review (parallel merge checkpoint)

Fires automatically when `TRACKING*.md` is edited — this happens when the coordinator updates item statuses after merging a parallel wave. Sends the last commit diff (`git diff HEAD~1`, falling back to uncommitted changes), excluding TRACKING.md itself and config files.

Reviews two axes (dual-axis):

**A. Integration (primary):**
- Integration conflicts between merged sub-agent work
- API contract mismatches (producer/consumer interfaces)
- Shared state conflicts and race conditions
- Import/dependency coherence
- Naming consistency across merged items

**B. Code quality (secondary — catches what per-edit may have missed):**
- Bugs, edge cases, missed error handling
- Security issues
- Critical axis violations

Bypasses wave counting — always fires immediately. Subject to `MIN_CHANGES` threshold (skips trivial merges).

### Close Gate (holistic sprint review)

Fires automatically when `S*_CLOSE_GATE.md` is written. Sends the full sprint diff (`git diff main...HEAD`, truncated at `CROSS_AUDIT_MAX_DIFF_CLOSE_GATE`, default ~48k chars). Reviews for:
- Cross-item consistency and API contract mismatches
- Naming and pattern consistency across all changed files
- Architectural coherence
- Missing integration points
- Security issues across the full change set
- Failure mode coverage — were predicted risks (from Entry Gate) actually mitigated?

Bypasses wave counting — always fires immediately.

### Entry Gate (plan review)

Fires automatically when `S*_ENTRY_GATE.md` is written. Sends the gate report content itself (truncated at `CROSS_AUDIT_MAX_DIFF_ENTRY_GATE`, default ~32k chars). Reviews for:
- Missing failure modes and obvious risks
- Scope realism (too many must items?)
- Dependency gaps
- Acceptance criteria quality
- Critical axis coverage

Bypasses wave counting — always fires immediately.

---

## What Gets Sent to the External LLM

### Per-Edit Mode
- Git diff (`git diff HEAD` — staged + unstaged combined, truncated at `CROSS_AUDIT_MAX_DIFF_PER_EDIT`)
- Active items from TRACKING.md (items with status `in_progress` or `fixed`)
- Critical axis from CLAUDE.md (single line)
- In `standard`/`full`: CODING_GUARDRAILS.md + Entry Gate failure modes
- In `full`: Full content of the currently edited file (first 8000 chars). Note: in close-gate mode, `$FILE` is the gate report itself, not source files — so this layer is most useful in per-edit mode

### Wave Review Mode
- Last commit diff (`git diff HEAD~1`, `CROSS_AUDIT_MAX_DIFF_WAVE` max), excluding TRACKING.md and config files
- Falls back to uncommitted changes if no previous commit
- Active items, critical axis, guardrails, failure modes (same context layers as per-edit)

### Close Gate Mode
- Full sprint diff against main branch (`git diff main...HEAD`, auto-detects main/master, `CROSS_AUDIT_MAX_DIFF_CLOSE_GATE` max)
- Active items, critical axis, guardrails, failure modes (same context layers)

### Entry Gate Mode
- The gate report content (`CROSS_AUDIT_MAX_DIFF_ENTRY_GATE` max)
- Critical axis from CLAUDE.md
- Active items from TRACKING.md (items with status `in_progress` or `fixed`)
- In `standard`/`full`: CODING_GUARDRAILS.md (AC quality evaluated against project standards)

### Skipped Files (never trigger the hook)

The hook silently exits for these file patterns — they are never sent:

- `CLAUDE.md`, `WORKFLOW*.md` — workflow state files (note: `TRACKING*.md` triggers wave-review mode instead of being skipped)
- `*Roadmap*.md`, `*ROADMAP*.md` — planning docs
- `*SPRINT_CLOSE*`, `*GUARDRAILS*`, `*LESSONS*` — sprint artifacts
- `*.json`, `*.yaml`, `*.yml`, `*.toml`, `*.lock` — config/lock files
- `*.env*` — secrets, credentials

Also never sent (by design, not by skip pattern):
- Full codebase (only diffs are sent)
- Other sprint history

---

## How Claude Handles the Review

The external audit result arrives as `additionalContext` with a verdict:

| Verdict | Claude's Behavior |
|---------|-------------------|
| **PASS** | Mentions it as additional confidence signal |
| **WARN** | Presents warnings alongside own assessment; user decides |
| **BLOCK** | Presents blocking issues; does not proceed until user reviews |
| **BLOCK** (enforced) | When `CROSS_AUDIT_ENFORCE_BLOCK=true`: hook exits non-zero, Claude Code treats as hook failure |

### Conflicting Opinions

When Claude and the external LLM disagree:
- Claude presents **both perspectives** clearly
- States its own position
- **User decides** — neither opinion auto-overrides the other

---

## Cost Visibility

Every audit result includes token usage:

```
Model: gpt-4o | Lines changed: 47 | Tokens: ~3200 in / ~800 out
```

This helps you monitor API costs. To reduce costs:
- Use `CROSS_AUDIT_CONTEXT=minimal`
- Use `CROSS_AUDIT_TRIGGER=wave` (fewer calls)
- Increase `CROSS_AUDIT_MIN_CHANGES` (skip small edits)
- Use a cheaper model (`gpt-4o-mini`, local Ollama, etc.)

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| API key missing | Hook exits silently. No impact on workflow |
| API timeout / network error | Skipped. Warning in stderr. Workflow continues |
| API returns error (rate limit, auth) | Skipped. Error logged to stderr. Workflow continues |
| Empty response | Skipped. Warning in stderr |
| Response not valid JSON | Displayed as-is. Claude interprets best-effort |

By default, the cross-audit is non-blocking at the infrastructure level. When `CROSS_AUDIT_ENFORCE_BLOCK=true`, BLOCK verdicts cause the hook to exit non-zero, mechanically blocking the edit.

---

## Data Safety

The hook includes multiple layers of protection against secret leakage:

### Layer 1: File Exclusions
Sensitive files are excluded from `git diff` before anything is sent:
- `*.env`, `*.env.*` — environment files
- `*.key`, `*.pem`, `*.p12` — certificates and keys
- `*credentials*`, `*secrets*` — credential files

### Layer 2: File Skip Patterns
The hook silently exits for workflow/config files (see [Skipped Files](#skipped-files-never-trigger-the-hook) above).

### Layer 3: Secret Scrubbing
Before sending any diff to the external LLM, the hook scrubs known secret patterns:
- **Token prefixes:** `sk-*`, `sk-ant-*`, `ghp_*`, `gho_*`, `ghu_*`, `xox[bpsar]-*` (OpenAI, Anthropic, GitHub, Slack)
- **AWS keys:** `AKIA*` (permanent access keys), `ASIA*` (temporary/STS credentials)
- **Key-value assignments:** `password=`, `secret=`, `api_key:`, `token=`, `credential=`, `auth_token=` (8+ char values)
- **Bearer tokens:** `Bearer <token>` in HTTP headers
- **Private keys:** `-----BEGIN * PRIVATE KEY-----` and `-----END * PRIVATE KEY-----` blocks
- **Connection strings:** `postgres://user:password@host`, `mongodb://...`, etc.

Scrubbing replaces values with `[REDACTED]` while preserving the key name for review context.

### Layer 4: .gitignore
The project `.gitignore` includes `.env`, `*.key`, `*.pem`, `credentials.json`, `secrets.yaml` to prevent accidental commits. Bootstrap step 3 ensures these entries are created.

### Layer 5: Safe Variable Expansion
The `.env` parser uses `printenv` for indirect variable lookup instead of `eval`, preventing command injection via crafted `.env` values. Keys are validated against a strict regex (`^[A-Z][A-Z0-9_]*$`) before import.

### Layer 6: Payload Handling
Large prompts (up to 48KB for holistic sprint reviews) are written to a temporary file and passed to `jq` via `--rawfile` instead of shell arguments, avoiding `ARG_MAX` limits and shell escaping issues. The temp file is cleaned up via `trap EXIT`.

### Recommendations
- **Never hardcode API keys in source files.** Use environment variables.
- **Keep `CROSS_AUDIT_API_KEY` in your shell profile** (`~/.bashrc`, `~/.config/fish/config.fish`), not in project files.
- **Use `CROSS_AUDIT_CONTEXT=minimal`** if your project handles sensitive data — this sends only the diff and item summaries.
- **Use local models (Ollama, LM Studio)** for maximum data privacy — nothing leaves your machine.

---

## Integration with Workflow Modes

The cross-LLM audit hook (`cross-llm-audit.sh`) is **independent of workflow mode** — `ENABLE_CROSS_AUDIT` is not affected by Lite/Standard/Strict presets:

- Can be enabled in Lite mode for extra safety on fast iterations
- Can be disabled in Strict mode if team prefers internal review only
- `hooks-config.sh` strict mode enforcement does NOT force cross-audit on

**Note:** The audit _signal_ hooks (CP1 metric regression, CP2 recurring failures via `detect-audit-signals.sh`) **are** controlled by workflow mode — Lite mode disables them by default. Override with `HOOK_DETECT_AUDIT_SIGNALS=true` in `hooks-config.local.sh` if needed

---

## GitHub Models Example (Copilot subscription)

If you have a GitHub Copilot subscription, you can use GitHub Models:

```bash
export ENABLE_CROSS_AUDIT=true
export CROSS_AUDIT_API_BASE="https://models.inference.ai.azure.com"
export CROSS_AUDIT_API_KEY="$(gh auth token)"  # Uses your GitHub CLI token
export CROSS_AUDIT_MODEL="gpt-4o"
```

Note: GitHub Models availability depends on your Copilot plan. Check [GitHub Models docs](https://docs.github.com/en/github-models) for current model list.

---

## Anthropic API Example

Use Claude as the cross-audit reviewer (useful when your primary agent is GPT, Gemini, etc.):

```bash
export ENABLE_CROSS_AUDIT=true
export CROSS_AUDIT_PROVIDER="anthropic"
export CROSS_AUDIT_API_KEY="sk-ant-..."
# API_BASE and MODEL are auto-set for anthropic provider
# Defaults: https://api.anthropic.com + claude-sonnet-4-20250514
```

To use a specific Claude model:

```bash
export CROSS_AUDIT_MODEL="claude-haiku-4-5-20251001"  # faster, cheaper
```

---

## Audit Log & Health Check

Every hook invocation (skip, success, or error) is logged to `.claude/.state/cross-audit-log.jsonl` in JSONL format:

```json
{"ts":"2026-03-12T10:30:00Z","status":"success","reason":"","verdict":"PASS","file":"src/app.ts","mode":"per-edit"}
{"ts":"2026-03-12T10:31:00Z","status":"skip","reason":"wave-below-threshold","verdict":"","file":"src/utils.ts","mode":"per-edit"}
{"ts":"2026-03-12T10:35:00Z","status":"error","reason":"api-network-error","verdict":"","file":"src/api.ts","mode":"per-edit"}
```

**Log rotation:** When the log exceeds `AUDIT_LOG_MAX_BYTES` (default: 1MB), it's automatically truncated to the last `AUDIT_LOG_KEEP_LINES` entries (default: 500). Both are configurable in `hooks-config.sh`.

### Health Check

Run the health check script to verify the audit system is working:

```bash
bash .claude/hooks/audit-health-check.sh           # Default: 1 hour staleness threshold
bash .claude/hooks/audit-health-check.sh 1800       # Custom: 30 minutes
```

Reports: last successful audit, status breakdown, recent errors, and overall health verdict (exit 0 = healthy, exit 1 = unhealthy).

---

## Pre-Merge Audit

Audit sub-agent work **before** merging it into the sprint branch. This catches issues proactively instead of reactively (the default wave-review fires after merge).

```bash
bash .claude/hooks/pre-merge-audit.sh /tmp/worktree-agent-1     # Worktree path
bash .claude/hooks/pre-merge-audit.sh sprint-1-agent-branch      # Branch name
```

- Generates a diff between HEAD and the sub-agent's changes
- Sends to the audit LLM with a pre-merge focused prompt
- Outputs structured JSON to stdout (for coordinator consumption)
- Exit 0 = PASS/WARN (safe to merge), exit 1 = BLOCK (do not merge)
- Uses the same API configuration as the main hook

### Integration with Coordinator Workflow

Add between steps 1 and 2 of the coordinator's between-wave review (see PARALLEL-EXECUTION.md):

```
1. Review all agent outputs (watchdog)
1b. Pre-merge audit: bash .claude/hooks/pre-merge-audit.sh <worktree>
    BLOCK → do not merge. Fix or re-run agent.
    PASS/WARN → proceed with merge.
2. Resolve file conflicts...
```

---

## Evidence Verification

Verify sub-agent D.7 AC exit check evidence by checking `file:line` references:

```bash
bash .claude/hooks/verify-evidence.sh < agent-report.txt
bash .claude/hooks/verify-evidence.sh report.txt
```

- Extracts `file:line` references from the report
- Checks each file exists and line number is in range
- Shows context snippets around valid references
- Exit 0 = all evidence valid, exit 1 = invalid evidence found

### What It Checks

| Check | Result |
|-------|--------|
| File exists | VALID / INVALID (file not found) |
| Line in range | VALID / INVALID (line N out of range, file has M lines) |
| Context snippet | Displayed for coordinator to visually confirm relevance |

**Note:** Semantic verification (does the code at that line actually satisfy the AC?) is left to the coordinator's judgment. The script only validates structural correctness of the references.

---

## Disabling

Remove the env vars, or:

```bash
export ENABLE_CROSS_AUDIT=false
```

The hook checks this first and exits immediately with zero overhead.
