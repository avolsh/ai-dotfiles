# Rule Canonical Map — audit narrative (archived)

*Last updated: 2026-06-10*

Working narrative of the D1 audit from `IMP-20260514-dedup-rule-statements`,
split out of the live `docs/rule-canonical-map.md` by
`IMP-20260610-reduce-self-referential-overhead` Task T3. The live file now
carries only the machine-read inventory consumed by `scripts/lint-rules.py`;
everything historical lives here. All action items below are **done** —
this file is a record, not a queue.

---

## Audit method

Files inspected (all rule-bearing files in scope):

| File | Lines | Rule sections |
|---|---|---|
| `framework/boundaries.md` | 55 | § Always do (14) / § Ask first (5) / § Never do (9) / § Escalation protocol |
| `framework/spec-workflows/spec-lifecycle.md` | 149 | § Rules (13 numbered) + § Status transitions + § Visualize / § Split sub-step |
| `framework/prompts/create-spec.prompt.md` | 27 | § Hard rules (3) |
| `framework/prompts/bug-triage.prompt.md` | 21 | § Hard rules (3) |
| `framework/prompts/plan-spec.prompt.md` | 23 | § Hard rules (4) |
| `framework/prompts/visualize-spec.prompt.md` | 19 | § Hard rules (4) |
| `framework/skills/writing-specs/SKILL.md` | 30 | (References only; no rule restatements) |
| `framework/skills/writing-specs/references/bounded-autonomy-rules.md` | 52 | § Decision matrix + § Ambiguity score (canonical; not duplicated) |
| `framework/skills/writing-specs/references/splitting-rules.md` | 64 | §1-§4 (canonical; cited heavily but not restated) |

## Per-rule audit detail (restatement counts, linking sites, notes)

| Rule | Restatements | Linking sites replaced in D3 | Notes |
|---|---|---|---|
| R1 — Never skip Specify | 3 | `spec-lifecycle.md § Rules #1`; `create-spec.prompt.md § Hard rules` | Prompt used different framing: "Never skip the question round" |
| R2 — No `## Tasks` at `specify` | 5 | `boundaries.md § Never do #3`; `create-spec.prompt.md`; `visualize-spec.prompt.md`; `plan-spec.prompt.md` | — |
| R3 — Never flip without gate | 4 | `boundaries.md § Never do #4` | spec-lifecycle canonical: the three sub-rules (→plan, →in-progress, →done) are lifecycle-specific |
| R4 — `*Last updated*` stamp | 3 | `spec-lifecycle.md § Rules #6`; `docs/writing-docs.md § Core rules #1` *(discovered & fixed during D4)* | Prompt mentions are operational steps, not restatements — excluded |
| R5 — Task row status in-place | 2 | `spec-lifecycle.md § Rules #7` | — |
| R6 — Split check mandatory | 5 | `spec-lifecycle.md § Rules #11, #12` (self-consolidation); `create-spec.prompt.md`; `bug-triage.prompt.md`; `plan-spec.prompt.md § Steps #3` | `splitting-rules.md` trigger/exception tables (T1-T6, P1-P3, E1-E5) NOT duplicated — only the mandate was |
| R7 — `depends-on:` blocks `plan` | 2 | `plan-spec.prompt.md § Hard rules` | — |
| R8 — Visualize is not a status | 2 | `visualize-spec.prompt.md § Hard rules` | — |
| R9 — "Continue" = one task | 1 in framework/ | none — anchor created for future linking only | docs/ mentions are descriptive prose, not normative restatements; D3 did not act |
| R10 — Visualize triggers | 2 | `visualize-spec.prompt.md § Preconditions`; `create-spec.prompt.md § Steps #5` | See side-finding below |

**R10 action item carried into D2 — RESOLVED 2026-05-14:**
`spec-workflows/README.md` does NOT restate Visualize triggers; it only
references `spec-lifecycle.md` as the canonical source. No additional linking
sites for R10. **Side-finding:** `create-spec.prompt.md § Steps #5` and
`visualize-spec.prompt.md § Preconditions` both linked to
`spec-workflows/README.md#visualize-sub-step-when-mandatory`, but that anchor
never existed (the triggers live in `spec-lifecycle.md`). D3 redirected both
prompts to the `spec-lifecycle.md#visualize-triggers` anchor. *(The same
failure class was later found in `docs/writing-specs.md` and mechanically
closed by `scripts/validate-anchors.py` — IMP-20260610 T2.)*

## Rules NOT duplicated (canonical-only — no D3 action)

| Rule | Canonical location |
|---|---|
| The Bottom Line — canonical format | `docs/agent-protocol.md` (referenced by `boundaries.md § Always do #9`) |
| Front-matter schema | `spec-lifecycle.md § Front-matter schema` |
| Status transitions table | `spec-lifecycle.md § Status transitions` |
| File naming pattern | `spec-lifecycle.md § File naming` |
| File location active/archived | `spec-lifecycle.md § File location` |
| Split triggers / exceptions (T1-T6, P1-P3, E1-E5) | `splitting-rules.md` |
| Bounded autonomy decision matrix | `bounded-autonomy-rules.md` |
| Ambiguity scoring | `bounded-autonomy-rules.md § Ambiguity score` |
| Escalation protocol | `boundaries.md § Escalation protocol` |
| Tests-with-features mandate | `boundaries.md § Always do #6` (not restated elsewhere) |
| BUG Task 1 = reproduce + failing test | `bug-triage.prompt.md § Hard rules` (BUG-type-specific; not restated) |
| Preflight proof format | `boundaries.md § Always do #4` (referenced via prose in agent-protocol) |
| Two-scope skill / boundary lookup | `boundaries.md § Always do #1, #5` + `docs/agent-protocol.md` |

## D1 summary

- **10 distinct rules** had ≥2 restatements across in-scope files (R1-R10),
  with R9 having no in-framework duplicates (anchor created for future
  linking only).
- **9 rules** required D3 action (R1-R8, R10). R9 was anchor-only.
- **~13 verbatim restatement sites** replaced in D3 across `boundaries.md`
  (1), `spec-lifecycle.md § Rules #11, #12` (2 self-consolidations),
  `create-spec.prompt.md` (2), `bug-triage.prompt.md` (1),
  `plan-spec.prompt.md` (3), `visualize-spec.prompt.md` (4).
- **2 canonical files** own all 10 anchors: `boundaries.md` (R1, R4, R5, R9)
  and `spec-lifecycle.md` (R2, R3, R6, R7, R8, R10).
- **0 rules** found semantically distinct under similar wording — no false
  positives among dedup candidates.

## D2-D6 action queue (all completed 2026-05-14)

| Step | Action | Files touched |
|---|---|---|
| D2 | Add 10 anchors to canonical locations (R1-R10) | `boundaries.md`; `spec-lifecycle.md` |
| D3 | Replace ~13 verbatim restatement sites with anchor links | `boundaries.md`; `spec-lifecycle.md`; four prompt files |
| D4 | `make lint-rules` enforces the canonical map | `scripts/lint-rules.py` (new); `Makefile` |
| D5 | Canonical-template generator | `framework/templates/system/_canonical.md` (new); `scripts/generate-system-templates.sh` (new) |
| D6 | Closure verification pass | verify-only |
