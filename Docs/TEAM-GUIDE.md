# Team Guide

Team adaptation layer for the AI-Assisted Sprint Workflow.
The core workflow (WORKFLOW.md) defaults to **solo** — this guide adds coordination
rules for teams of 2+. Nothing in the core workflow changes; only coordination is added.

> **Prerequisite:** Read WORKFLOW.md first. This guide assumes familiarity with
> Entry Gate, Close Gate, Implementation Loop, and sprint branch model.

---

## Solo vs Team — Quick Comparison

| Aspect | Solo (default) | Team (adaptation) |
|--------|----------------|-------------------|
| TRACKING.md | Single file | Per-person recommended (`TRACKING-dev-a.md`); shared OK with rotating owner |
| Branch | `sprint-N-impl` | `sprint-N-name-impl` (per person) |
| Commits | Per-item after D.7 | Same |
| Review | Self-verify + AI agent | Peer review + AI agent |
| Entry Gate | Each person runs their own | Same |
| Close Gate | Each person runs their own | Same + peer can review PR |
| Push | Backup cadence (session boundaries) | After every item commit |
| Sprint numbering | Sequential (1, 2, 3…) | Shared sequential (coordinate at planning) |

---

## Team Topologies

Skip this section entirely if working solo.

### Pair (2 equal developers)

Two friends making a game, two co-founders building a product — no hierarchy, no owner.

**Model: independent sprints, shared project config.**

```
Shared (git-tracked, both read & occasionally edit)
├── CLAUDE.md
├── CODING_GUARDRAILS.md
├── Docs/Planning/Roadmap.md

Per-person (git-tracked, only owner edits)
├── TRACKING-dev-a.md        ← Dev-A's AI manages this
├── TRACKING-dev-b.md        ← Dev-B's AI manages this

Branches
├── main
├── sprint-3-dev-a-impl      ← Dev-A's current sprint
└── sprint-4-dev-b-impl      ← Dev-B's current sprint
```

**How it works:**
- Plan together at the Roadmap level: "I'll do inventory, you do combat." Mark items with assignee.
- **Sprint numbering:** Allocate numbers together at planning time (Dev-A takes 3, Dev-B takes 4).
  If someone finishes early and starts a new sprint, pick the next unused number and tell the other person.
  Roadmap.md is the source of truth for which sprint numbers are allocated to whom.
- Each person runs their own sprint cycle independently (own Entry Gate, own Close Gate).
- Each person's AI reads only their TRACKING file. CLAUDE.md and GUARDRAILS are shared.
- Merge to main: first to finish merges first. Other rebases onto updated main.
- Shared files (CLAUDE.md, GUARDRAILS): pull before editing — with 2 people, conflict risk is negligible.
- AI memory (`.claude/memory/`) stays local per person. Team knowledge goes into CODING_GUARDRAILS.md.

**Bootstrap adjustment (WORKFLOW.md step 3):**
- Create per-person TRACKING files instead of a single `TRACKING.md`:
  `TRACKING-[name].md` — same template, scoped to this person's items.
- Do NOT create a shared `TRACKING.md` — each person gets their own.
- Branch naming: `sprint-N-name-impl` instead of `sprint-N-impl`.
- Roadmap.md items include assignee: `- [ ] CORE-045 (@dev-a) Inventory system`.
- Step 4d: mark each item with `@name`. Step 4h: populate each person's TRACKING file
  with only their assigned items.

### Small Team (3-5 developers)

**Recommended model: sub-teams using Pair topology.**

Split into sub-teams of 2-3. Each sub-team runs independent sprints with per-person
TRACKING files, using the same model as Pair above (independent sprints, shared project
config). Groups of 3 work identically — each person has their own TRACKING file and
sprint branch. This avoids the single-TRACKING bottleneck and scales naturally.

**Alternative model: sprint owner with rotation.**

If the team prefers shared sprints (all working on the same sprint together):
- Each sprint has a **rotating owner** who manages a single shared TRACKING.md and runs gates.
- Other members implement assigned items on feature branches off the sprint branch.
- Owner updates TRACKING.md based on PR merges and team communication.
- Ownership rotates each sprint to prevent bottleneck and share context.
- Risk: shared TRACKING.md may cause merge conflicts if multiple members edit concurrently.
  Mitigate with pull-before-edit discipline and immediate push after edits.

### Larger Team (5+)

Split into sub-teams of 2-3. Each sub-team runs its own sprint cycle (Pair model).
Coordination happens at the Roadmap level — a shared Roadmap.md with cross-team dependencies marked.

---

## Cross-Sprint Item Dependencies

When one person's item depends on another person's work:

**At Roadmap planning time:**
Mark dependencies explicitly in Roadmap.md:
```markdown
- [ ] CORE-050 (@dev-b) Shop UI [depends: CORE-045]
- [ ] CORE-045 (@dev-a) Inventory system
```

**Dependency resolution rules:**
1. **Dependency already merged to main** → no issue. Dependent item proceeds normally.
2. **Dependency in progress (other person's active sprint)** → dependent item is `blocked`.
   - Do not start blocked items. Work on other items in your sprint first.
   - When the dependency merges to main → pull main → unblock item → continue.
   - Log in your TRACKING: `[date] CORE-050 unblocked — CORE-045 merged to main by [name].`
3. **Dependency not yet started** → do not schedule the dependent item until the dependency
   is at least planned in someone's sprint. Defer to a future sprint.
4. **Circular dependency** → break the cycle at Roadmap planning. Extract a shared interface
   or API contract as a separate item that both depend on. That item goes first.

**Entry Gate check (team addition):**
When running Entry Gate step 11 (dependency graph), also check:
- Are any items in my sprint dependent on items in someone else's active sprint?
- Are any of my items touching files that someone else's active sprint is also modifying?

**File overlap detection:**
Check whether both sprints modify the same files. Method depends on context:
- **Both branches exist:** compare `git diff main...<branch> --name-only` output for each branch.
  Any file appearing in both lists is an overlap.
- **One or both branches not yet started:** estimate from item descriptions and known file locations.

Log overlap check result in Entry Gate report.

If overlap detected → coordinate before starting. Options:
- Serialize (one person finishes and merges first)
- Split the file (extract shared code into a separate module first)
- Agree on scope boundaries ("I only modify function X, you handle function Y")

---

## Pull Request Integration (team)

When multiple people contribute, replace local merge ceremony with PR-based flow:

- After Close Gate passes, preserve per-item commit history and create a PR:
  ```bash
  git push origin sprint-N-name-impl
  # Generate per-item commit log for PR description (same info as solo merge message)
  ITEM_LOG=$(git log --oneline sprint-N-start..sprint-N-name-impl)
  gh pr create --title "Sprint N: [goal]" --body "$(cat <<EOF
## Close Gate Verdict
[verdict + summary]

## Items Merged
$ITEM_LOG

## sprint-audit.sh
[result summary]
EOF
  )"
  ```
- PR description must include: Close Gate verdict, per-item commit list, sprint-audit.sh result.
  The per-item commit list preserves regression traceability in the squash merge commit message
  (GitHub copies PR description into the squash commit message by default).
- Peer review: at least one other team member reviews the PR (not required for Pair if both
  contributed to the sprint — self-merge is OK after Close Gate passes).
- After approval → squash merge via PR (ensure "Items Merged" section is in the commit message).
  Then pull main and tag locally:
  ```bash
  git checkout main
  git pull origin main
  git tag sprint-N-close
  git push origin sprint-N-close
  git branch -D sprint-N-name-impl   # clean up local branch (remote auto-deleted by GitHub PR merge)
  ```

---

## CI/CD Integration (team, optional)

- Run `sprint-audit.sh` and test suite as CI checks on sprint branch PRs.
- CI failure blocks PR merge — treat as Close Gate failure (fix on branch, re-push).
- Optional: run `ci-guardrail-check.sh` as a separate CI step.
- Recommended pipeline: lint → test → sprint-audit.sh → guardrail-check.

