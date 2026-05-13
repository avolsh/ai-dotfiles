# CR Standard Questions

*Last updated: 2026-04-20*

During the Specify stage, the agent asks up to **10 questions** from this
list plus any spec-specific ones. The human answers before requirements
are written.

## How to use

1. Pick the questions that are relevant to this CR — not all 10 always fire.
2. **Q1 (Scope) and Q2 (Separability) are mandatory on every round — never drop them.** They drive the Split check in [`splitting-rules.md § 2`](../../skills/writing-specs/references/splitting-rules.md).
3. Reorder the remaining questions freely so the most blocking come first.
4. If an answer makes subsequent questions obsolete, drop them.
5. If fewer than 3 questions are needed, the CR is probably trivial —
   go ahead, but still confirm understanding in a single round.

## Standard questions (ask ≤10 per round)

1. **Scope:** Which modules or bounded contexts are affected? Is this
   confined to one context or does it cross boundaries?
2. **Separability:** Can any part of this work ship and be verified on
   its own, ahead of the rest? Which FRs are independent versus
   must-ship-together? Are any blocked by external dependencies
   (other team, vendor, upstream spec)?
3. **Data model:** What new entities, types, or fields are needed? Do any
   existing schemas change?
4. **Pipeline integration:** Does this add or modify a processing step?
   Which existing steps are affected?
5. **AI involvement:** Does this require AI processing (prompts, batches)?
   Which provider(s)?
6. **Persistence:** What data stores are affected? New collections/tables
   or changes to existing ones?
7. **Dependencies:** Are there prerequisite changes or specs that must be
   completed first?
8. **Breaking changes:** Will this change the output format consumed by
   downstream systems or other projects?
9. **Testing:** What are the key test scenarios? Are there edge cases to
   consider?
10. **Documentation:** Which docs need updating (architecture, how-to,
    glossary, reference schemas)?
11. **Risk:** What could go wrong? Data loss, performance regression,
    breaking existing output?

## Situational questions (optional, use as needed)

- **Existing requirements:** Which baseline REQ-IDs (if any) under
  `docs/requirements/` does this CR/IMP touch, change, or supersede?
  If none exist for the affected feature, will this spec seed a new
  baseline file at closure?
- **Migration:** Is there existing data that needs migration or backfill?
- **Configuration:** Are new environment variables or config entries needed?
- **Visualization:** Would architecture diagrams help clarify the design?
  If yes, the Visualize sub-step is required before requirements approval.
- **Localization:** Does this affect `en`, `uk`, `ru`, or other locales?
- **Accessibility:** Are there a11y implications (contrast, keyboard,
  screen-reader labels)?
- **Performance:** Are there latency, memory, or cost budgets to respect?
- **Rollback:** How do we revert if this goes wrong in production?

## Frontend-specific (use when touching tobevisit-web UI)

- **Atomic Design scope:** Is this an atom, molecule, organism, or page?
- **Server vs client component:** Can this render as a Server Component,
  or does it need `"use client"`?
- **SEO:** Does the change affect metadata, sitemap, or structured data?

## Pipeline-specific (use when touching tobevisit-content)

- **Batch vs streaming:** Does the step process single items or batches?
- **Idempotency:** Can the step re-run safely on already-processed items?
- **Progress timer:** Is a progress timer needed for long-running loops?

## Anti-patterns

- **Do not** ask questions you can answer by reading the code.
- **Do not** ask questions whose answers are in the user's original prompt.
- **Do not** bundle two questions into one bullet (e.g., "What is X and
  how does Y work?"). Split them.
- **Do not** use the question round as a design-review — the human
  decides the design, you confirm understanding.
