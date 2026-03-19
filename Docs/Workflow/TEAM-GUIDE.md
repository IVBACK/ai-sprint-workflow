<instructions>

# CRITICAL: One scene/prefab = one owner at a time (Unity). Scene overlap = STOP, serialize.
# CRITICAL: Cross-sprint dependencies must be resolved before starting blocked items.
# CRITICAL: PR must include Close Gate verdict + per-item commit list + sprint-audit result.

# Team Guide

Core workflow defaults to solo. This guide adds coordination for 2+ people. Nothing in core changes.

## Solo vs Team Comparison

| Aspect | Solo | Team |
|--------|------|------|
| TRACKING.md | Single file | Per-person (`TRACKING-dev-a.md`) |
| Branch | `sprint-N-impl` | `sprint-N-name-impl` |
| Commits | Per-item after D.7 | Same |
| Review | Self-verify + AI | Peer review + AI |
| Entry/Close Gate | Each person runs own | Same + peer can review PR |
| Push | Session boundaries | After every item commit |
| Sprint numbering | Sequential | Shared sequential (coordinate at planning) |

## Team Topologies

### Pair (2 developers)

Model: independent sprints, shared project config.

```
Shared: CLAUDE.md, CODING_GUARDRAILS.md, Docs/Planning/Roadmap.md
Per-person: TRACKING-dev-a.md, TRACKING-dev-b.md
Branches: sprint-3-dev-a-impl, sprint-4-dev-b-impl
```

Rules:
1. Plan together at Roadmap level. Mark items with assignee.
2. Sprint numbering: allocate together. Next unused number if finishing early. Roadmap.md = source of truth.
3. Each person runs own sprint cycle (own Entry Gate, own Close Gate).
4. Each person's AI reads only their TRACKING file.
5. Merge to main: first to finish merges. Other rebases.
6. Shared files: pull before editing.
7. AI memory stays local. Team knowledge -> CODING_GUARDRAILS.md.

Bootstrap adjustments:
- Create `TRACKING-[name].md` per person (no shared TRACKING.md)
- Branch: `sprint-N-name-impl`
- Roadmap items: `- [ ] CORE-045 (@dev-a) Inventory system`
- Step 4d: mark with @name. Step 4h: populate each person's TRACKING with their items only.

### Small Team (3-5)

Recommended: sub-teams of 2-3 using Pair topology.

Alternative (shared sprints): rotating sprint owner manages single TRACKING.md and runs gates. Others implement on feature branches off sprint branch. Rotate ownership each sprint. Risk: merge conflicts on shared TRACKING.md — mitigate with pull-before-edit + immediate push.

### Larger Team (5+)

Sub-teams of 2-3, each running own sprint cycle. Coordinate at Roadmap level with cross-team dependencies marked.

## Cross-Sprint Dependencies

Mark in Roadmap.md: `- [ ] CORE-050 (@dev-b) Shop UI [depends: CORE-045]`

Resolution rules:
```
IF dependency merged to main: proceed normally.
ELIF dependency in progress (other's active sprint): item = blocked.
  Do not start. Work other items. When merged -> pull main -> unblock -> continue.
  Log: "[date] CORE-050 unblocked -- CORE-045 merged by [name]."
ELIF dependency not started: defer to future sprint.
ELIF circular dependency: break cycle. Extract shared interface as separate item.
```

Entry Gate team addition (step 11):
1. Check: any items dependent on someone else's active sprint?
2. Check: any items touching files another sprint modifies?

File overlap detection:
```
IF both branches exist: compare `git diff main...<branch> --name-only` for each.
ELSE: estimate from item descriptions.
```

Log overlap result in Entry Gate report.

IF overlap detected:
- Serialize (one finishes first)
- Split file (extract shared module)
- Agree scope boundaries (function X vs function Y)

## Pull Request Integration

After Close Gate passes:
```bash
git push origin sprint-N-name-impl
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

PR rules:
1. Include: Close Gate verdict, per-item commit list, sprint-audit.sh result
2. Peer review: at least one other member (Pair self-merge OK after Close Gate)
3. After approval: squash merge, ensure Items Merged in commit message
4. Post-merge:
```bash
git checkout main && git pull origin main
git tag sprint-N-close && git push origin sprint-N-close
git branch -D sprint-N-name-impl
```

## CI/CD Integration (optional)

1. Run sprint-audit.sh + test suite as CI checks on sprint PRs
2. CI failure blocks PR merge (treat as Close Gate failure)
3. Optional: ci-guardrail-check.sh as separate CI step
4. Pipeline order: lint -> test -> sprint-audit.sh -> guardrail-check

# CRITICAL: Cross-sprint dependencies must be resolved before starting blocked items.
# CRITICAL: PR must include Close Gate verdict + per-item commits + sprint-audit result.

</instructions>
