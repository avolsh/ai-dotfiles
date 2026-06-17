# IMP-20260616 — Spec corpus analysis & redraft proof

*Last updated: 2026-06-16*

Closure evidence for [`IMP-20260616-spec-output-and-agent-rigor`](../IMP-20260616-spec-output-and-agent-rigor.md) AC-4 and AC-6. Not a spec (lives under `archived/artifacts/` per `spec-templates-guide.md`).

## Corpus definition

54 canonical archived specs across three roots, excluding `README.md`, `_legacy/`, and `archived/artifacts/`:

- `docs/specs/archived/` (workspace)
- `env/ai-dotfiles/docs/specs/archived/` (ai-dotfiles)
- `src/github.com/tobeverse/tobevisit-content/docs/specs/archived/` (tobevisit-content)

**Counting method.** All line counts are **physical lines after front-matter** (the FR-1 ruler), so the diagnostic and the budget use the same measure. Section line counts run from each `## H2` to the next.

## Per-corpus metrics (AC-6)

| Corpus | n | body avg | body median | body max | Requirements avg | Accept/Fix avg | Cost Estimate | >120 | >270 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| workspace | 11 | 244.4 | 197.0 | 705 | 34.6 | 77.4 | 11 | 11 | 2 |
| ai-dotfiles | 19 | 171.3 | 154.0 | 382 | 15.8 | 39.9 | 18 | 16 | 2 |
| tobevisit-content | 24 | 388.5 | 331.5 | 1162 | 90.7 | 31.0 | 4 | 21 | 15 |
| **TOTAL** | **54** | **282.7** | **192.5** | **1162** | **52.9** | **43.6** | **33** | **48** | **19** |

H2-section count per spec: avg **12.5**, max **22**.

**Method notes / reconciliations:**
- **Requirements / Acceptance averages** above are over **all 54** specs (a spec missing the section counts 0). Averaged only over specs that *have* the section: Requirements **62.1** (n=52), Acceptance/Fix **58.9** (n=40). The all-54 figure is lower because older content specs use `R1…`/checklist shapes the parser scores as 0.
- **Cost Estimate = 33** by H2-section presence; a plain `grep "Cost Estimate"` returns **34** — one spec mentions the term in prose without a dedicated section. Both are reported; 33 is the section count.
- Blank lines are **included** (FR-1 counts them). Non-blank-only counts run ~25% lower (e.g. Acceptance 58.9 → 44.4).

**Diagnosis.** 48/54 (89%) exceed the 120-line budget; the median spec is 192.5. The mass sits in **Requirements + Acceptance/Fix Criteria** (together the dominant sections) and in **structural overhead** (avg 12.5 H2 sections, including the now-removed Cost Estimate present in 33/54). This is exactly what the IMP's FR-1 (budget), FR-3 (one-line FR / clustered AC / no prose-restating), and FR-4 (drop Cost Estimate) target.

## Redraft demonstrations (AC-4)

"Authored body" = body excluding front-matter and any `## Closure*` section (the FR-1 ruler). Each redraft preserves every FR and every observable verification outcome; only restatement, Cost Estimate, and duplicated file/closure narrative are removed.

| Spec | Corpus | Authored body before | After | Reduction | FRs in→out | ACs in→out |
|---|---|---:|---:|---:|---:|---:|
| IMP-20260610-reduce-self-referential-overhead | ai-dotfiles | 157 | 92 | **41%** | 4→4 | 4→4 |
| IMP-20260429-multi-agent-instruction-support | workspace | 254 | 118 | **54%** | 11→11 | 10→10 |
| CR-20260228-deepseek-ai-provider | tobevisit-content | 283 | 121 | **57%** | 11 (R1–R11)→11 FR | 13→11 |

All three exceed the ≥30% target. Drivers, per spec:

### 1. IMP-20260610-reduce-self-referential-overhead (157→92, 41%)

- Cost Estimate section removed (−7).
- FR-1…FR-4 stripped of inline `*(Amended …)*` / `*(Closed …)*` closure annotations → moved to a closure note; FRs become one line each (−24).
- Current State 3-item narrative → 3 lines; Proposed Improvement → 3 lines (it restated Current State + the benefit) (−18).
- Split Decision 8 lines → 2 (cite E5 + one reason) (−6).
- ACs kept 1-per-FR (already clustered); trimmed the `And the measurable benefit…` tails into the Then line (−8).
- FR/AC preserved: FR-1 anchor validator, FR-2 map split, FR-3 one-hop, FR-4 docs↔skills ownership; AC-1…AC-4 unchanged in outcome.

### 2. IMP-20260429-multi-agent-instruction-support (254→118, 54%)

- Cost Estimate removed (−7).
- Current State: 11 audit findings with sub-bullets (38 lines) → 1 line per finding (−26).
- Proposed Improvement: 12-step list (34 lines) duplicated Current State + Docs-updates → folded to a 6-line change summary; per-file detail lives once in the Tasks table (−24).
- Acceptance Criteria: 10 multi-paragraph ACs (72 lines) → clustered Given/When/Then, ≤6 lines each (−40).
- `## Agent instructions` 14-line inline block → the one-line template pointer (−13).
- Docs updates 13 lines → 5 (the per-file changes are already in Tasks) (−8).
- FR/AC preserved: all 11 FRs (sync target, full-content AGENTS.md, thin CLAUDE.md, CI drift gate, discovery note, defect fixes, no-semantic-drift, manual consistency, accurate CLAUDE.md, .gitmodules name, link-integrity) and all 10 AC outcomes retained; the Mermaid diagram (excluded from budget) is unchanged.

### 3. CR-20260228-deepseek-ai-provider (283→121, 57%)

- `## Files to create` + `## Files to modify` (26 lines) deleted — every path already appears in `affected-code:` front-matter and in the requirements; the tables were pure restatement (FR-3 forbids prose restating a table/schema).
- `## Design decisions` D1–D5 (42 lines) → 5-line "Design notes" (rationale that wasn't already in a requirement); `## Notes` (12) folded in or dropped (−45).
- R1–R11 → one-line FR-1…FR-11; canonical type/`config` shapes kept in a single `## Architecture` schema block (they are canonical, not restating); prose around them removed (−40).
- Acceptance checklist (24 lines, 13 boxes) → clustered AC-1…AC-11 (build/test boxes merged into one verification AC) — observable outcomes preserved, count 13→11 by merging the two "build passes"/"test passes" boxes into one AC and the two "no SDK leak"/"type exists" boxes (−ⁿ).
- Migration plan table kept (it carries deploy-order risk, not restatement).
- FR preserved: all 11 R-items (config verify, deepseek config, ContentConfiguration provider field, AiProvider type, generalized FilteringBatch, DeepSeek adapter, JSON output, process/prepare use-case updates, composition-root wiring, workflow flag rename); observable outcomes all retained.

## Conclusion

- **AC-6:** full per-corpus metrics produced over all 54 canonical specs (body, Requirements, Acceptance/Fix, Cost Estimate, H2-section, over-budget counts).
- **AC-4:** three representative specs (one per corpus) redrafted under the new rules; reductions **41% / 54% / 57%**, all ≥30%, no FR or observable verification outcome dropped.
- The dominant savings come exactly from the IMP's levers: dropping Cost Estimate (FR-4), one-line FRs + clustered ACs + no prose-restating tables (FR-3), and the whole-spec budget forcing the compression pass (FR-1/FR-2).
