# Sub-agents Target (S7)

*Captured: 2026-05-14*
*Spec: IMP-20260514-framework-subagents — Task S7*
*Measured at: HEAD after S5 wired delegation to spec-author + splitter (Specify) and task-planner (Plan).*

Post-change main-context token measurement, compared against the S1
baseline. Per spec FR-5, target is ≥30% reduction. **Actual: 32.2%** ✅
(passes, but with only 2.2 points of margin — see § What didn't shrink).

## Walk-through assumed

Same as S1: a throwaway CR Specify-stage round 1 with 3 typical
questions. Files loaded per `framework/prompts/create-spec.prompt.md`
Steps 1, 2, 5 (Steps 3 + 4 now delegate to sub-agents).

## Methodology

Identical to S1 — `bytes / 4` token approximation for English markdown.
Both runs use the same heuristic, so the relative comparison is robust.

## Measured at HEAD (post-S5)

Main-thread load on Claude Code path:

| File | Bytes | ~Tokens | Notes |
|---|---:|---:|---|
| workspace `.github/copilot-instructions.md` | 1,916 | 479 | unchanged |
| `framework/spec-workflows/spec-types.md` | 3,169 | 792 | unchanged |
| `framework/spec-workflows/questions/cr-questions.md` | 3,983 | 995 | unchanged |
| `framework/prompts/create-spec.prompt.md` | 3,073 | 768 | slightly slimmer than S1 (3,116 → 3,073 — Steps 3+4 delegations replaced inline instructions) |
| `framework/skills/writing-specs/SKILL.md` | 1,925 | 481 | unchanged |
| `framework/skills/agent-protocol/SKILL.md` | 1,304 | 326 | unchanged |
| `framework/boundaries.md` | 4,353 | 1,088 | unchanged |
| `docs/spec-asking-questions.md` | 1,412 | 353 | unchanged (Step 2 still references) |
| `framework/spec-workflows/spec-lifecycle.md` | 8,024 | 2,006 | unchanged (Step 5 Visualize trigger lookup still references) |
| **Main-thread total (Claude Code path)** | **29,159** | **~7,288** | |

## Files moved off the main thread

These files were in the S1 realistic baseline but are no longer loaded
by the main thread under the Claude Code delegating path — they live
inside the spec-author / splitter sub-agent contexts:

| File | ~Tokens removed | Moved into |
|---|---:|---|
| `docs/spec-format.md` | 1,077 | `framework/agents/spec-author.md` context |
| `docs/acceptance-criteria-patterns.md` | 844 | `framework/agents/spec-author.md` context |
| `docs/splitting-specs.md` | 643 | `framework/agents/splitter.md` context |
| `framework/skills/writing-specs/references/splitting-rules.md` | 890 | `framework/agents/splitter.md` context |
| **Subtotal** | **~3,454** | |

## Delta vs. S1 baseline

| Metric | S1 baseline | S7 target | Delta |
|---|---:|---:|---:|
| Main-thread tokens (realistic) | ~10,753 | ~7,288 | **−3,465** |
| Percent reduction | — | — | **32.2%** |
| FR-5 threshold | ≥30% | — | **PASS** (+2.2 pts margin) |

## What didn't shrink (and why margin is narrow)

Two contributors stayed on the main thread despite delegation:

1. **`spec-lifecycle.md` (~2,006 tokens)** — the largest single file in the load. Step 5 of `create-spec.prompt.md` still references the Visualize-trigger section (`#visualize-triggers` anchor added in IMP-20260514-dedup-rule-statements). Moving Visualize into its own sub-agent (a future enhancement) would push this off the main thread, but per S5's scope decision, no Visualize agent landed in this IMP.

2. **`boundaries.md` (~1,088 tokens)** — auto-imported via every system template (`@boundaries.md`). Cannot be delegated; it IS the universal behavioural rule set. Stays canonical on every agent thread.

If the framework later adds a `visualize-author` agent + folds `spec-lifecycle.md` Visualize section into it, the post-delegation main load drops from ~7,288 → ~5,282 tokens (≈51% reduction vs. S1). Out of scope for this IMP; logged for a future follow-up.

## Non-Claude harnesses (Copilot Chat, OpenAI Codex CLI)

These harnesses do NOT implement the `Agent` sub-call mechanism. Per the
fallback paragraph in each delegating prompt (see `framework/agents/README.md`),
the agent body is inlined into the main context. The fallback path
loads the agent files alongside everything else:

| File | ~Tokens |
|---|---:|
| `framework/agents/spec-author.md` | 729 |
| `framework/agents/splitter.md` | 781 |
| Subtotal of agent bodies | ~1,510 |

Non-Claude main-thread load ≈ S7 minimal (7,288) + agent bodies (1,510) = **~8,798 tokens**.

Reduction vs. S1 realistic baseline (~10,753): ~18%. Below the 30%
threshold, but the threshold per spec OS-1 explicitly applies to
Claude Code; non-Claude users see "≤5% improvement (just from the
slimmer prompt itself)" was the original framing — actual is ~18% due
to docs-not-being-loaded-on-fallback-either (the prompt's slimmed
Steps don't reference spec-format.md or splitting-rules.md anymore,
so even Copilot users don't pull them in). Net positive across all
harnesses.

## Closure verdict

| AC | Evidence |
|---|---|
| AC-4 (≥30% reduction on Claude Code path) | 32.2% — PASS |
| Multi-tool compatibility preserved | Non-Claude harnesses get ~18% reduction via inlined fallback; no regression |
| Tripwire (<30%) — does NOT fire | margin 2.2 pts |
| Re-Specify trigger — does NOT fire | n/a |

## Methodology caveats (carried from S1)

- `bytes / 4` is an estimate; ±15% vs. actual tokenizers. Same heuristic
  on both sides of the comparison, so the relative figure is robust.
- This is a **static-file measurement**, not a live LLM context inspection.
  The framework's "Load context" step deterministically loads these
  files; static count is the right proxy.
- Margin is narrow (2.2 pts). If the boundaries.md or
  spec-lifecycle.md files grow in future work, the reduction could
  drop below 30% and the FR-5 contract would fail without intervention.
  Recommend a `make measure-subagent-savings` target (out of S7 scope)
  to track this over time.
