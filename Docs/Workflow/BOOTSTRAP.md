<instructions>

# CRITICAL: Never overwrite CLAUDE.md. Never overwrite source code. Never modify CI without user confirmation.

# Bootstrap — Project Setup

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
