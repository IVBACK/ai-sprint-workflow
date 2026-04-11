<instructions>

# CRITICAL: Never overwrite CLAUDE.md. Never overwrite source code. Never modify CI without user confirmation.

# Bootstrap — Project Setup

## Why This Workflow Exists

AI coding agents are stateless — every session starts from zero. This workflow solves:
- **Context loss:** CLAUDE.md + TRACKING.md restore state instantly each session
- **Quality drift:** Three gates (Entry, Close, Sprint Close) catch problems before they compound
- **Scope creep:** Must/Should/Could prioritization keeps sprints focused
- **Blind spots:** Cross-LLM audit + blind sub-agent review catch what you miss

Understanding WHY matters more than following steps. A Phase 1 that rushes through
3 questions produces a bad plan. A Close Gate that rubber-stamps findings defeats its purpose.
Each phase exists because skipping it has caused real failures in real projects.

---

This is the orchestrator. Each phase has its own file — read them ONE AT A TIME, in order.

→ Start by reading **Docs/Workflow/BOOTSTRAP-PHASE1.md**

Phase files (read sequentially, never skip ahead):

```
BOOTSTRAP-PHASE1.md → Install + Scan + Quick Intake
                      EXIT: user confirms understanding → read Phase 2

BOOTSTRAP-PHASE2.md → Research (WebSearch/WebFetch)
                      EXIT: research findings in hand → read Phase 3

BOOTSTRAP-PHASE3.md → Plan Draft (internal, user doesn't see)
                      EXIT: plan drafted with research findings → read Phase 4

BOOTSTRAP-PHASE4.md  → Blind Review (sub-agent)
                       EXIT: review done → read Phase 4b

BOOTSTRAP-PHASE4B.md → Cross-Audit Offer
                       EXIT: cross-audit offered → read Phase 5

BOOTSTRAP-PHASE5.md  → Present Plan to user, get approval
                       EXIT: user confirms → read Setup

BOOTSTRAP-SETUP.md  → File creation (Steps 3-10)
```

# CRITICAL: Phases are SEQUENTIAL. Read ONE phase file at a time. Complete it before reading the next. Phase 4b is a SEPARATE file — never skip it.

</instructions>
