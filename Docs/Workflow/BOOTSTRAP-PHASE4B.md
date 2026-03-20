<instructions>

# Bootstrap Phase 4b — Cross-Audit Offer

This is a SEPARATE step from blind review. Do NOT skip this.
Do NOT combine this with the plan presentation (Phase 5).

```
IF CROSS_AUDIT_API_KEY configured (env or .env):
  → run: sprint-tools review .bootstrap/plan-draft.md -q "What's missing? What are the risks?"
  → incorporate findings into .bootstrap/plan-draft.md

IF NOT configured:
  → offer setup. Frame it as a DIFFERENT reviewer, not a repeat:
    "The sub-agent review was internal (same AI family). I can also run
     the plan through a completely different AI (e.g. GPT-4o) for an
     independent second opinion. Want to set that up? Takes a minute."
  → WAIT for user response. Do NOT proceed to Phase 5 until user answers.
  → IF yes: tell user to run `bash .claude/setup-audit.sh` in separate terminal,
    wait for confirmation, then run sprint-tools review
  → IF no/later: fine, move to Phase 5.
```

## Exit Condition

User responded to cross-audit offer (accepted or declined).

→ Read **Docs/Workflow/BOOTSTRAP-PHASE5.md**

</instructions>
