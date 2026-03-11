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
| **Per-edit** | Source file change | Uncommitted `git diff` | Bugs, security, AC coverage |
| **Close Gate** | `S*_CLOSE_GATE.md` written | Full sprint diff (`git diff main...HEAD`) | Cross-item consistency, architecture |
| **Entry Gate** | `S*_ENTRY_GATE.md` written | Gate report content | Plan quality, missing risks |

Gate reviews (Close/Entry) fire immediately regardless of wave/item trigger mode.

## Setup

### 1. Choose a Provider

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

### 2. Set Environment Variables

**Option A: Project `.env` file (recommended)**

Create a `.env` file in the project root (already git-ignored):

```bash
ENABLE_CROSS_AUDIT=true
CROSS_AUDIT_API_KEY=your-api-key-here

# Optional — defaults shown
CROSS_AUDIT_PROVIDER=openai
CROSS_AUDIT_MODEL=gpt-4o
CROSS_AUDIT_TRIGGER=wave
CROSS_AUDIT_CONTEXT=standard
CROSS_AUDIT_LANG=en
CROSS_AUDIT_MIN_CHANGES=10
CROSS_AUDIT_TIMEOUT=60
```

The hook auto-loads `CROSS_AUDIT_*` and `ENABLE_CROSS_AUDIT` vars from `.env`. No `export` needed.

**Option B: Shell profile**

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, `~/.config/fish/config.fish`):

```bash
export ENABLE_CROSS_AUDIT=true
export CROSS_AUDIT_API_KEY="your-api-key-here"
```

Shell profile vars take precedence — `.env` only fills in values not already set.

Either way: `.env` is git-ignored, shell profile is outside the repo. Neither enters git.

### 3. Verify

Make a code change with 10+ lines. Check stderr for "Cross-audit:" messages. If the API key is valid, Claude will receive the external review as additionalContext.

---

## Configuration Reference

### CROSS_AUDIT_TRIGGER

| Value | Behavior | Best For |
|-------|----------|----------|
| `wave` (default) | Fires every ~5 source file edits, batching changes | Normal workflow. Less API calls, lower cost |
| `item` | Fires on every source file edit that meets MIN_CHANGES | Granular review. Higher cost but catches issues earlier |

Force immediate audit in wave mode: `export CROSS_AUDIT_FIRE=true`

### CROSS_AUDIT_CONTEXT

Controls how much project context is sent to the external LLM:

| Level | What's Sent | Token Cost |
|-------|-------------|------------|
| `minimal` | Diff + active items from TRACKING.md + critical axis | Low (~2-4k) |
| `standard` (default) | Minimal + CODING_GUARDRAILS.md + Entry Gate failure modes | Medium (~4-8k) |
| `full` | Standard + full content of changed files | High (~8-16k) |

### CROSS_AUDIT_LANG

- `en` — Review in English (default)
- `tr` — Review in Turkish

### Internal / Testing Variables

These are not typically set by users but are available for testing and advanced use:

| Variable | Purpose | Default |
|----------|---------|---------|
| `CLAUDE_PROJECT_DIR` | Project root directory | `.` (current dir) |
| `CROSS_AUDIT_COUNTER_FILE` | Override wave counter file path | `/tmp/.cross-audit-counter-<hash>` |
| `CROSS_AUDIT_FIRE` | Force immediate audit in wave mode | unset |

---

## Audit Modes

### Per-Edit (default)

Fires on source file changes. Sends uncommitted `git diff` (staged + unstaged, truncated at ~24k chars). Reviews for bugs, security issues, AC coverage, and coding rule violations.

Subject to wave/item trigger mode and `MIN_CHANGES` threshold.

### Close Gate (holistic sprint review)

Fires automatically when `S*_CLOSE_GATE.md` is written. Sends the full sprint diff (`git diff main...HEAD`, truncated at ~48k chars). Reviews for:
- Cross-item consistency and API contract mismatches
- Naming and pattern consistency across all changed files
- Architectural coherence
- Missing integration points
- Security issues across the full change set

Bypasses wave counting — always fires immediately.

### Entry Gate (plan review)

Fires automatically when `S*_ENTRY_GATE.md` is written. Sends the gate report content itself (truncated at ~32k chars). Reviews for:
- Missing failure modes and obvious risks
- Scope realism (too many must items?)
- Dependency gaps
- Acceptance criteria quality
- Critical axis coverage

Bypasses wave counting — always fires immediately.

---

## What Gets Sent to the External LLM

### Per-Edit Mode
- Git diff (`git diff HEAD` — staged + unstaged combined, truncated at ~24k chars)
- Active items from TRACKING.md (items with status `in_progress` or `fixed`)
- Critical axis from CLAUDE.md (single line)
- In `standard`/`full`: CODING_GUARDRAILS.md + Entry Gate failure modes
- In `full`: Full content of the currently edited file (first 8000 chars). Note: in close-gate mode, `$FILE` is the gate report itself, not source files — so this layer is most useful in per-edit mode

### Close Gate Mode
- Full sprint diff against main branch (`git diff main...HEAD`, auto-detects main/master, ~48k chars max)
- Active items, critical axis, guardrails, failure modes (same context layers)

### Entry Gate Mode
- The gate report content (~32k chars max)
- Critical axis from CLAUDE.md

### Skipped Files (never trigger the hook)

The hook silently exits for these file patterns — they are never sent:

- `TRACKING*.md`, `CLAUDE.md`, `WORKFLOW*.md` — workflow state files
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

The cross-audit is **never blocking** at the infrastructure level. Only the *findings* can be blocking (via BLOCK verdict that Claude respects).

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

### Layer 5: Safe Variable Expansion
The `.env` parser uses `printenv` for indirect variable lookup instead of `eval`, preventing command injection via crafted `.env` values. Keys are validated against a strict regex (`^[A-Z][A-Z0-9_]*$`) before import.

### Layer 6: Payload Handling
Large prompts (up to 48KB for holistic sprint reviews) are written to a temporary file and passed to `jq` via `--rawfile` instead of shell arguments, avoiding `ARG_MAX` limits and shell escaping issues. The temp file is cleaned up via `trap EXIT`.

### Layer 4: .gitignore
The project `.gitignore` includes `.env`, `*.key`, `*.pem`, `credentials.json`, `secrets.yaml` to prevent accidental commits.

### Recommendations
- **Never hardcode API keys in source files.** Use environment variables.
- **Keep `CROSS_AUDIT_API_KEY` in your shell profile** (`~/.bashrc`, `~/.config/fish/config.fish`), not in project files.
- **Use `CROSS_AUDIT_CONTEXT=minimal`** if your project handles sensitive data — this sends only the diff and item summaries.
- **Use local models (Ollama, LM Studio)** for maximum data privacy — nothing leaves your machine.

---

## Integration with Workflow Modes

The cross-LLM audit is **independent of workflow mode** (Lite/Standard/Strict):

- Can be enabled in Lite mode for extra safety on fast iterations
- Can be disabled in Strict mode if team prefers internal review only
- `hooks-config.sh` strict mode enforcement does NOT force cross-audit on

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

## Disabling

Remove the env vars, or:

```bash
export ENABLE_CROSS_AUDIT=false
```

The hook checks this first and exits immediately with zero overhead.
