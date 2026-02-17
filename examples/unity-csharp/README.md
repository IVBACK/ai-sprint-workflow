# Example: Unity 6 + URP (C#) — Procedural Terrain Project

This example shows how the AI Sprint Workflow was adapted for a real
Unity 6 + URP project building a procedural planet system using
SDF + Marching Cubes.

The project completed 4 sprints, accumulated 50+ guardrail rules,
and runs 89+ EditMode tests with 3 automated audit scripts.

## Project Characteristics

- **Language:** C# (.NET Standard 2.1)
- **Framework:** Unity 6 + URP 17
- **Build:** Unity Editor (no standalone CLI build)
- **Tests:** NUnit (EditMode + PlayMode)
- **Performance-sensitive:** Yes (real-time rendering, GPU compute)
- **Developer:** Solo + AI agent

## Discovery Question Answers

| # | Answer |
|---|--------|
| 1 | Solo developer |
| 2 | Medium (5-8 items) |
| 3 | Yes — 6-phase, 24-sprint roadmap exists |
| 4 | Yes — real-time game, GPU compute |
| 5 | Desktop (PC) |
| 6 | No CI — manual gate checks |
| 7 | NUnit (Unity Test Framework) |
| 8 | No existing linter — guardrails from scratch |
| 9 | Yes — 14.5 sprints of experience from predecessor project |
| 10 | English (code, comments, commits); Turkish (internal docs) |
| 11 | Free-form (atomic preferred, monolithic acceptable for solo) |
| 12 | SDF format, density grid size, buffer type (see contracts below) |

## Immutable Contracts (from CLAUDE.md)

These were identified early and never changed:

```
- SDF format: float4(density, materialID, temperature, moisture)
- Density grid: 35x35x35 (32 cube + ghost)
- Convention: density > 0 => solid, density < 0 => air
- Shader: #pragma use_dxc mandatory
- Buffer: RWStructuredBuffer + InterlockedAdd (AppendStructuredBuffer forbidden)
- Noise: computed on unit sphere (normalize(worldPos - center))
```

## Guardrail Examples (from CODING_GUARDRAILS.md)

Rules that emerged from real bugs during the project:

### Compute Shader Rules
```
- G-001: Never use AppendStructuredBuffer (Vulkan glslang #3638 bug)
  → Use RWStructuredBuffer + separate counter buffer + InterlockedAdd

- G-002: All .compute and .shader files must have #pragma use_dxc
  → Without DXC, wave intrinsics and SM6.0 features silently fail

- G-003: Never use SetFloats() for float4 uniforms
  → Use SetVector() or SetVectorArray(). SetFloats pads incorrectly.
```

### Memory / Performance Rules
```
- Every compute dispatch, mesh upload, cache R/W: wrap with ProfilerMarker
- GPU buffer uploads use dirty-flag: no re-upload if data unchanged
- No per-frame allocations in Update/LateUpdate (pool or cache)
- Camera.main, GetComponent must be cached in Awake/OnEnable
```

## Sprint-Audit.sh Adaptations

The generic `sprint-audit.sh` was customized with Unity-specific patterns:

| Section | Generic Pattern | Unity Adaptation |
|---------|----------------|-----------------|
| Hot path alloc | `new T[]` in loop | `new List<`, `new NativeArray` in Update files |
| Cached refs | repeated lookup | `Camera.main`, `GetComponent`, `FindObjectOfType` |
| Framework anti-pattern | varies | `AppendStructuredBuffer`, `SetFloats`, `ComputeBufferType.Append` |
| Resource guard | missing close/dispose | `NativeArray` without `.Dispose()`, `ComputeBuffer` without `.Release()` |
| Observability | missing logging | Missing `ProfilerMarker` in dispatch/upload methods |

## File Structure (actual)

```
ProjectRoot/
├── CLAUDE.md                              # ~80 lines, auto-loaded
├── TRACKING.md                            # ~150 lines, sprint board
├── Docs/
│   ├── CODING_GUARDRAILS.md               # ~1400 lines, 15 sections
│   ├── SPRINT_WORKFLOW.md                 # ~580 lines, full flow docs
│   ├── LESSONS_INDEX.md                   # Bug → rule mapping
│   ├── Planning/
│   │   └── Roadmap.md                     # 6-phase, 24-sprint plan
│   └── Archive/
│       └── changelog-S1-S3.md             # Archived changelogs
├── Tools/
│   ├── sprint-audit.sh                    # 11-section heuristic scan
│   ├── ci-guardrail-check.sh             # Hard-fail forbidden patterns
│   └── perf-regression-check.sh          # Performance regression gate
└── Assets/
    └── ProjectName/
        ├── Runtime/                       # Production code
        ├── Shaders/                       # Compute + render shaders
        └── Tests/
            ├── EditMode/                  # 89+ NUnit tests
            └── PlayMode/                  # GPU/lifecycle tests
```

## Key Learnings

1. **Guardrails from predecessor project saved weeks.** 14.5 sprints of PG-II experience was encoded as Day 0 rules. Zero repeat bugs from known issues.

2. **sprint-audit.sh reduced close gate context from ~4000 lines to ~500 lines.** The script pre-filters mechanical issues, freeing AI context window for semantic analysis.

3. **Strategic alignment check (Entry Gate Step 8) caught 2 obsolete items** that had been completed in earlier sprints but were still listed as Must.

4. **"AI flags, user decides" rule prevented 3 unintended scope changes** where the AI would have autonomously removed items based on its own assessment.

5. **Sprint scope > sprint duration.** With an AI agent, a "medium sprint" (5-8 items) completes in 1-2 sessions regardless of calendar time. Calendar-based planning is meaningless.
