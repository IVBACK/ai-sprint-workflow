<instructions>

# CRITICAL: Status changes MUST use `sprint-tools item` (handles status + evidence + changelog + roadmap sync). Do NOT edit TRACKING.md manually for status transitions.
# CRITICAL: Deferred items require reason + target sprint. Regressions require Change Log entry.

# State Transitions

## Item Lifecycle

```
open --> in_progress --> fixed --> verified
  |          |            |          |
  v          v            v          v
blocked    blocked    in_progress   open
(dependency) (external)  (rework)   (regression -> log reason in Change Log)

Any status --> deferred (requires reason + target sprint)
```

Transition rules:
1. open -> in_progress: work started
2. in_progress -> fixed: implementation done
3. fixed -> verified: test evidence provided
4. Any -> blocked: dependency or external blocker discovered
5. blocked -> open: blocker resolved
6. verified -> open: regression found (log reason in Change Log)
7. fixed -> in_progress: rework needed before verification
8. Any -> deferred: intentional skip (requires reason + target sprint)

## Sprint Lifecycle

```
planned -> entry gate PASS -> in progress -> must done -> close gate PASS -> done -> next sprint
             |                    |                          |
           fail: flag user      abort: abbreviated close    fail: fix, re-run
```

## Document Update Triggers

| Event | Update |
|-------|--------|
| Work started | TRACKING.md status -> in_progress |
| Bug fixed | TRACKING.md status -> fixed |
| Bug verified | TRACKING.md status -> verified + evidence |
| Item blocked | TRACKING.md status -> blocked + risk entry |
| Item deferred | TRACKING.md status -> deferred + reason |
| Regression found | TRACKING.md verified -> open + change log |
| New rule found | GUARDRAILS.md (rule + anti-pattern + why note) |
| Sprint starts | TRACKING.md Current Focus |
| Sprint closes | Roadmap (checkmarks), CLAUDE.md (checkpoint) |
| Sprint archived | Docs/Archive/changelog-S<N>.md |
| Decision made | TRACKING.md change log |
| Tech debt found | TRACKING.md new ID + forward note |
| Scope change | TRACKING.md change log + new/modified items |
| Contract revised | CLAUDE.md Immutable Contracts + change log |
| Sprint aborted | TRACKING.md items -> deferred + change log |
| Entry Gate run | Docs/Planning/S<N>_ENTRY_GATE.md created |
| Sprint closed | Docs/Planning/S<N>_ENTRY_GATE.md deleted |
| Failure logged | TRACKING.md Failure Encounters |
| Perf baseline | TRACKING.md metrics recorded, compare prev |

# CRITICAL: Use `sprint-tools item CORE-NNN <status> "evidence"` for all status transitions above. Deferred requires reason + target sprint.

</instructions>
