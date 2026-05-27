# Writing Specs

*Last updated: 2026-05-27*

Consolidated guidance for spec-driven work: lifecycle pointer, stage walk-throughs (Specify, Plan), writing-style rules, RFC 2119 keywords, the self-review additions, template usage, and anti-patterns. Topic-specific deep dives live in the linked docs.

---

## Lifecycle at a glance

```
specify → plan → in-progress → done → archived/
```

Full status rules, front-matter schema, and transitions:
[`spec-lifecycle.md`](../framework/spec-workflows/spec-lifecycle.md).
Per-stage context: [`spec-types.md`](../framework/spec-workflows/spec-types.md).
Process diagram and gate rules:
[`spec-workflows/README.md`](../framework/spec-workflows/README.md).

## Stages

| # | Stage | Status | Prompt | Produces |
|---|---|---|---|---|
| 1 | Specify (+ Visualize sub-step) | `specify` | [`create-spec.prompt.md`](../framework/prompts/create-spec.prompt.md) / [`bug-triage.prompt.md`](../framework/prompts/bug-triage.prompt.md) | Requirements, ACs, Architecture (if triggered) |
| 2 | Plan | `plan` | [`plan-spec.prompt.md`](../framework/prompts/plan-spec.prompt.md) | Vertical-slice tasks table |
| 3 | Task execution | `in-progress` | — (per-task preflight + Bottom Line) | Code + tests per task |
| 4 | Closure | `done` → `archived/` | — | Evidence, file moved |

Each stage is a **separate chat turn** with fresh preflight. The spec
file is one living document updated at every stage. Hard gates between
every stage — see
[`spec-workflows/README.md § Anti-skip rules`](../framework/spec-workflows/README.md#anti-skip-rules).

---

## Writing style rules

Apply to all spec text during Specify and Plan.

### Format

- Markdown only: headers, tables, numbered lists, code blocks.
- Tables for all inputs / outputs / errors / mappings.
- Steps: imperative verb, max 8 words each, max 10 steps.
- Constraints / rules: bullet list, one rule per line.

### Forbidden

- Preamble, closing remarks, or filler transitions.
- Passive voice ("should be treated as", "is recommended").
- "Ensure", "consider", "it is recommended", "please note".
- Restating the goal inside processing steps.
- Sentences that don't directly specify behavior.

### Compression pass (apply before finalizing any section)

1. Delete any line removable without changing meaning.
2. Merge steps that share a subject.
3. Replace phrases with shortest unambiguous term.
4. If a type definition and a field table describe the same thing,
   keep only one (prefer the table for mapping specs, the type definition
   for schema specs).
5. "Future" sections: max 3 lines with a forward pointer. No speculation.

### Deduplication

- Do not explain in prose what a schema already shows.
- Do not repeat a rule stated in a table as a bullet below the table.
- If a JSON example and a type definition cover the same shape,
  keep one. State which is canonical.

---

## RFC 2119 keywords

| Keyword | Meaning |
|---------|---------|
| **MUST** | Absolute requirement. Non-conformant without it. |
| **MUST NOT** | Absolute prohibition. |
| **SHOULD** | Recommended. Omit only with documented justification. |
| **MAY** | Optional. Implementer's discretion. |

---

## Specify stage (detail)

1. Load context per [`spec-types.md`](../framework/spec-workflows/spec-types.md)
   for the spec type.
2. Ask ≤10 questions from the relevant question list plus spec-specific
   ones. See [`spec-asking-questions.md`](spec-asking-questions.md).
3. Human answers.
4. Write `## Problem Statement`, `## Requirements` (FRs with RFC 2119),
   `## Acceptance Criteria` (Given/When/Then, traced to FRs), `## Out
   of Scope`. See
   [`spec-format.md`](spec-format.md) and
   [`acceptance-criteria-patterns.md`](acceptance-criteria-patterns.md).
5. **Split check** — apply [`splitting-rules.md § 2`](../framework/skills/writing-specs/references/splitting-rules.md)
   against the FR clusters + Separability answer. If any trigger fires,
   propose a split, pause for the human decision, and create sibling
   spec files before continuing. Record the outcome under `## Split
   Decision` in every affected spec (kept-as-one + § 4 exception cited,
   or split into sibling IDs). Procedure and examples:
   [`splitting-specs.md`](splitting-specs.md).
6. Run **Visualize sub-step** if any trigger applies — per spec, after
   the split is resolved
   (see [`spec-workflows/README.md § Visualize sub-step`](../framework/spec-workflows/README.md#visualize-sub-step-when-mandatory)).
7. **Gate:** human approves requirements (and architecture, if populated).

## Plan stage (detail)

1. Decompose requirements into **tasks** (vertical slices).
2. Each task: description, max 5 files, dependencies, model suggestion,
   required skills.
3. Use [`model-selection/SKILL.md`](../framework/skills/model-selection/SKILL.md)
   for model tier.
4. Fill the `## Tasks` table in the spec.
5. Flip front-matter `status: plan`. Update `*Last updated:*`.
6. **Gate:** human approves plan.

---

## Bounded autonomy

When to stop vs. continue and the full escalation format:
[`bounded-autonomy.md`](bounded-autonomy.md) (prose) +
[`bounded-autonomy-rules.md`](../framework/skills/writing-specs/references/bounded-autonomy-rules.md)
(decision matrix, ambiguity score).

Key rule: if ambiguity exceeds 30% of a task, or the change is breaking
or security-related — **STOP and escalate**.

---

## Self-review checklist

Use the unified post-task checklist in
[`agent-protocol.md § Post-task checklist`](agent-protocol.md#post-task-checklist).

Additional spec-specific checks:

- [ ] No scope creep — implementation does not include features not in the spec.
- [ ] API contracts match implementation (field names, types, status codes).
- [ ] Non-functional requirements verified with evidence.
- [ ] Out-of-scope items not built.

---

## Template usage

- **CR:** [`CR-TEMPLATE.md`](../framework/spec-workflows/templates/CR-TEMPLATE.md)
- **BUG:** [`BUG-TEMPLATE.md`](../framework/spec-workflows/templates/BUG-TEMPLATE.md)
- **IMP:** [`IMP-TEMPLATE.md`](../framework/spec-workflows/templates/IMP-TEMPLATE.md)

Copy to `<project>/docs/specs/active/`, fill front-matter and title.

---

## Anti-patterns

1. **Coding before spec approval** — the review will surface changes.
2. **Vague acceptance criteria** — every criterion must be machine-verifiable.
3. **Missing edge cases** — for every external dependency, specify at least one failure.
4. **Spec as post-hoc documentation** — writing spec after code is documentation, not specification.
5. **Gold-plating beyond spec** — untested, unreviewed code.
6. **Orphaned ACs** — criteria without FR traceability mean a requirement is missing.
7. **Prose restating schemas** — the type definition already says it.
8. **Hedging** — replace "may potentially consider" with a 1-line forward pointer or delete.
9. **Passive rules** — write "Keep provider-neutral." not "should be kept."
10. **Skipping Visualize** — if any trigger applies, the sub-step is mandatory.
11. **Writing tasks during Specify** — `## Tasks` belongs to Plan.

---

## Topic index

- [`spec-asking-questions.md`](spec-asking-questions.md) — Specify-stage question technique.
- [`spec-format.md`](spec-format.md) — section format, FR / NFR style, review checklist.
- [`acceptance-criteria-patterns.md`](acceptance-criteria-patterns.md) — G/W/T patterns + coverage checklist.
- [`splitting-specs.md`](splitting-specs.md) — split procedure and worked examples.
- [`bounded-autonomy.md`](bounded-autonomy.md) — autonomy rationale, scope creep, breaking changes, security.
- [`baseline-citations.md`](baseline-citations.md) — per-feature domain baselines (structure, `domain-refs:`).
- [`req-id-lifecycle.md`](req-id-lifecycle.md) — REQ-ID numbering, deletion, supersession, cross-baseline citation.
- [`agent-protocol.md`](agent-protocol.md) — context loading, checklists, output conventions.
