# Model Selection

*Last updated: 2026-07-21*

Recommendations for choosing AI models by **capability tier**, not by model name. Model names change frequently; the decision logic stays stable. Covers the model-freshness gate, capability tiers, decision flowchart, IDE setup, and the current model mapping appendix.

---

## Model freshness gate

The model mapping appendix below includes a `*Model mapping verified*` date.
On the first session of any engagement, agents MUST:

1. Check current model availability against the mapping appendix.
2. If any model is renamed, deprecated, or superseded, flag it to the human
   before proceeding.
3. Update the `Model mapping verified` date after human confirms the mapping
   is current.

---

## Capability tiers

### Fast

- **Use for:** Quick edits, typo fixes, single-line changes, boilerplate,
  inline autocomplete.
- **Characteristics:** Lowest latency, lowest cost. Weaker at multi-file
  reasoning; may not follow complex conventions without explicit context.

### Default

- **Use for:** Most daily coding — implementation following existing patterns,
  debugging, refactoring, structured/template-driven work.
- **Characteristics:** Excellent code generation quality, fast, cost-effective,
  follows patterns reliably.
- **Limitation:** May miss subtle cross-cutting concerns; less creative in
  open-ended design tasks.

### Deep

- **Use for:** Architecture decisions, DDD boundaries, prompt design,
  cross-module bugs requiring pattern tracing, multi-step planning,
  catching edge cases, spec-conformance review (the `reviewer` sub-agent).
- **Characteristics:** Deep reasoning, long-context comprehension, nuanced
  decision-making. Slowest, highest cost.
- **Sweet spot:** Tasks where *getting it right the first time* saves hours
  of debugging.

---

## Decision flowchart

```
Start a task
    |
    +- Is it a quick edit, typo, or single-line fix?
    |   -> YES: Fast tier
    |
    +- Does it involve architecture, DDD boundaries, or prompt design?
    |   -> YES: Deep tier
    |
    +- Is it a cross-module bug requiring pattern tracing?
    |   -> YES: Deep tier (unlimited budget) / Default tier (limited budget)
    |
    +- Is it implementation following existing patterns?
    |   -> YES: Default tier
    |
    -> Fallback: Default tier
```

> **Rule of thumb:** Start every task at Default tier. Escalate to Deep only
> when Default output needs significant rework or the task is inherently
> high-stakes. Drop to Fast for anything that feels like "typing faster."

---

## IDE setup

| Tool | Tier | Role |
|------|------|------|
| **Inline autocomplete** | Fast | Real-time suggestions while typing |
| **Chat / agent mode** (primary) | Default | Implementation, debugging, refactoring |
| **Chat / agent mode** (escalation) | Deep | Architecture, complex planning, review |

---

## Appendix: Current model mapping

*Verified: 2026-07-21*

| Tier | Model | Notes |
|------|-------|-------|
| Fast | Claude Haiku 4.5 | Fastest latency, lowest cost |
| Default | Claude Sonnet 5 | Workhorse for 70-80% of tasks |
| Deep | Claude Opus 4.8 | Slowest, use for high-stakes decisions |

> Update only this table when model names change. The tiers and flowchart
> above remain stable.
