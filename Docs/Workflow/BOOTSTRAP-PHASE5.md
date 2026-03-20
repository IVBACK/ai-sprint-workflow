<instructions>

# Bootstrap Phase 5 — Present Plan

Read `.bootstrap/plan-draft.md` and present to user in plain language.
No workflow jargon (sprint/gate/must/should).
Technical terms for the user's domain are fine (webhook, API, database) — avoid workflow-specific terms only.

```
"Here's what I'll do:

 First: [most important/risky thing, plain language]
   - [key detail]
   - [key detail]

 Then: [next thing]
   - [key detail]

 My assumptions:
   - [assumption 1]
   - [assumption 2]

 Settings I picked based on our conversation:
   - [mode] — [one-line reason]
   - [critical axis or "none"]

 Any of this wrong? Questions? Want to change anything?"
```

Infer settings from conversation (do NOT ask separately):
- **Workflow mode**: Standard (default). Solo + experimental → Lite. Critical system or team compliance → Strict.
- **Critical Axis**: from domain. Every project has one (see Phase 3 list).
- **Commit style**: from existing git history (if conventional commits detected → conventional, else free-form).
- **Sprint scope**: from plan complexity.
- **Cross-LLM audit**: enabled if API key configured.
- **Language**: from conversation language.

```
WHILE user has questions or changes:
  → answer / adjust plan (including settings)
  → continue: "Anything else?"

WHEN user says "looks good" / "start" / equivalent:
  → proceed to file creation
```

## Exit Condition

User confirmed plan.

→ Read **Docs/Workflow/BOOTSTRAP-SETUP.md**

</instructions>
