# AI-Assisted Sprint Workflow Template
<!-- workflow-version: 3.1 -->

A project-agnostic sprint workflow designed for human + AI agent collaboration.
Copy this file and the `Docs/Workflow/` directory into any project and follow the setup instructions.
The AI agent reads the relevant workflow document and bootstraps the project structure automatically.

> **Team convention:** All references to `TRACKING.md` throughout this document
> also apply to per-person tracking files (`TRACKING-[name].md`) when using
> team topology. Read your own tracking file unless stated otherwise.
> Similarly, `sprint-N-impl` branch references become `sprint-N-name-impl` in team mode.
> See [Docs/Workflow/TEAM-GUIDE.md](Docs/Workflow/TEAM-GUIDE.md) for details.

---

## Document Map

This workflow has been split into focused documents. Read only the file relevant to your current task:

| When | Read |
|------|------|
| Project first setup | [BOOTSTRAP.md](Docs/Workflow/BOOTSTRAP.md) |
| Creating project files | [TEMPLATES.md](Docs/Workflow/TEMPLATES.md) |
| Starting a sprint | [ENTRY-GATE.md](Docs/Workflow/ENTRY-GATE.md) |
| Writing code | [IMPL-LOOP.md](Docs/Workflow/IMPL-LOOP.md) |
| Closing a sprint | [CLOSE-GATE.md](Docs/Workflow/CLOSE-GATE.md) |
| Post-gate finalization | [SPRINT-CLOSE.md](Docs/Workflow/SPRINT-CLOSE.md) |
| Scope change, abort, audit | [PROCEDURES.md](Docs/Workflow/PROCEDURES.md) |
| Every session (agent rules) | [AGENT-RULES.md](Docs/Workflow/AGENT-RULES.md) |
| State transitions | [STATE-TRANSITIONS.md](Docs/Workflow/STATE-TRANSITIONS.md) |
| Project size adaptation | [ADAPTATION.md](Docs/Workflow/ADAPTATION.md) |
| Setting up hooks | [HOOK-TEMPLATES.md](Docs/Workflow/HOOK-TEMPLATES.md) |
| Cross-LLM audit setup | [CROSS-LLM-AUDIT.md](Docs/Workflow/CROSS-LLM-AUDIT.md) |
| Parallel execution | [PARALLEL-EXECUTION.md](Docs/Workflow/PARALLEL-EXECUTION.md) |
| Team topology | [TEAM-GUIDE.md](Docs/Workflow/TEAM-GUIDE.md) |
| Unity/C# projects | [UNITY-GUIDE.md](Docs/Workflow/UNITY-GUIDE.md) |
| Workflow mode selection | [WORKFLOW-MODES.md](Docs/Workflow/WORKFLOW-MODES.md) |

---

## Upgrade from v2.x

If you have the monolithic WORKFLOW.md (v2.x), see [ADAPTATION.md](Docs/Workflow/ADAPTATION.md) §Upgrade for migration instructions.
