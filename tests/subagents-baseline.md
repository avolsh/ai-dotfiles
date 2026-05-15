# Sub-agents Baseline (S1)

*Captured: 2026-05-14*
*Spec: IMP-20260514-framework-subagents — Task S1*
*Measured at: HEAD before any `framework/agents/` or prompt-delegation edits*

Baseline main-context token measurement for running the current
non-delegating `create-spec.prompt.md` flow. S7 will re-measure after
sub-agents are wired (S2-S6) and compute the reduction. Per spec FR-5,
the goal is ≥30% main-context reduction; this file captures the
"before" number.

## Walk-through assumed

A throwaway CR in the tobevisit workspace, Specify-stage round 1.
Files loaded per `framework/prompts/create-spec.prompt.md § Steps #1`
plus auto-imports.

## Methodology

- **Unit:** tokens, estimated as `bytes / 4` for English markdown.
- **Tokenizer caveat:** ±15% vs. Anthropic/OpenAI tokenizers in practice. The relative comparison (S1 vs. S7) is what matters; both runs use the same heuristic so the bias cancels.
- **Scope:** main-thread context only. Sub-agent context (after S2-S6) doesn't count toward the main figure.

## Measured at HEAD on 2026-05-14

| File | Bytes | ~Tokens | Lines | Bucket |
|---|---:|---:|---:|---|
| workspace `.github/copilot-instructions.md` | 1,916 | 479 | 48 | minimal |
| `framework/spec-workflows/spec-types.md` | 3,169 | 792 | 59 | minimal |
| `framework/spec-workflows/questions/cr-questions.md` | 3,983 | 995 | 81 | minimal |
| `framework/prompts/create-spec.prompt.md` *(the prompt itself)* | 3,116 | 779 | 26 | minimal |
| `framework/skills/writing-specs/SKILL.md` | 1,925 | 481 | 30 | minimal |
| `framework/skills/agent-protocol/SKILL.md` | 1,304 | 326 | 24 | minimal |
| `framework/boundaries.md` | 4,353 | 1,088 | 56 | minimal |
| **Minimal subtotal** | **19,766** | **~4,940** | **324** | |
| `docs/spec-asking-questions.md` | 1,412 | 353 | 29 | realistic-only |
| `docs/spec-format.md` | 4,309 | 1,077 | 149 | realistic-only |
| `docs/acceptance-criteria-patterns.md` | 3,378 | 844 | 119 | realistic-only |
| `docs/splitting-specs.md` | 2,574 | 643 | 70 | realistic-only |
| `framework/skills/writing-specs/references/splitting-rules.md` | 3,560 | 890 | 64 | realistic-only |
| `framework/spec-workflows/spec-lifecycle.md` | 8,024 | 2,006 | 150 | realistic-only |
| **Realistic total** | **43,023** | **~10,753** | **905** | |

## Two baseline numbers (S7 will compare against the realistic figure)

- **Minimal load (~4,940 tokens):** the floor — files that EVERY Specify walk-through loads (Step 1 direct list + auto-imports + skill stubs). Even a one-question round pulls this much.
- **Realistic load (~10,753 tokens):** the typical — minimal + deep-dive docs the agent ends up reading during a thoughtful question round (spec-format, acceptance-criteria-patterns, splitting-rules, etc.). This is the more honest comparison number.

S7 should target ≥30% reduction against the **realistic** figure (~10,753). Hitting ≥30% on the minimal figure alone wouldn't reflect real-world savings.

## What the post-delegation main thread will load (S7 prediction)

After S2-S6 land, the main thread for a Specify walk-through should load only:
- `boundaries.md` (auto-imported — unchanged)
- the slimmed prompt (referencing the sub-agent, not duplicating its body)
- the agent contract pointer (`framework/agents/README.md` or just the spec-author front-matter)
- minimal project context

Predicted main-thread load: ~3,500-5,000 tokens.
Predicted reduction: ~50-65% vs. realistic baseline. Comfortably above the 30% FR-5 threshold.

If the actual S7 figure falls below 30%, the re-Specify tripwire fires (delegation overhead exceeds context savings).

## Reproducing this measurement

```bash
python3 - <<'PY'
from pathlib import Path
ROOT = Path('env/ai-dotfiles')  # or wherever ai-dotfiles lives
WORKSPACE = Path('.')           # workspace root, where .github/copilot-instructions.md lives

files = [
    (WORKSPACE / ".github/copilot-instructions.md", "workspace copilot-instructions"),
    (ROOT / "framework/spec-workflows/spec-types.md", "spec-types"),
    (ROOT / "framework/spec-workflows/questions/cr-questions.md", "cr-questions"),
    (ROOT / "framework/prompts/create-spec.prompt.md", "create-spec prompt"),
    (ROOT / "framework/skills/writing-specs/SKILL.md", "writing-specs SKILL"),
    (ROOT / "framework/skills/agent-protocol/SKILL.md", "agent-protocol SKILL"),
    (ROOT / "framework/boundaries.md", "boundaries"),
]
total = sum(len(p.read_bytes()) for p, _ in files if p.is_file())
print(f"minimal: {total} bytes, ~{total // 4} tokens")
PY
```
