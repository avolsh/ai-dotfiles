# Asking Questions During Specify

*Last updated: 2026-05-14*

How to ask effective clarifying questions during the Specify step of a spec.

## Principles

- **Max 10 questions** per Specify step — respect the human's time.
- **Start with scope** — the most important question is always about
  what's in and out of scope.
- **Reference existing context** — before asking, check if the answer
  is already in `docs/architecture/`, `docs/reference/`, or the module map.
- **Be specific** — "Which database table/collection?" not "Tell me about the data."
- **Offer options** — when possible, present choices rather than open-ended
  questions: "Should we add a new entity or extend the existing one?"
- **Group related questions** — combine closely related questions to stay
  within the 10-question budget.

## Question categories

| Category | When to ask | Example |
|---|---|---|
| Scope & boundaries | Always | "Is this confined to place-catalog or does it cross into geography?" |
| Data model | Schema changes | "What new fields are needed on PlaceDocument?" |
| Integration | Pipeline changes | "Does this add a new step or modify an existing one?" |
| Risk | Medium/high risk | "What happens if the AI provider returns malformed JSON?" |
| Testing | Complex logic | "What are the key edge cases to test?" |
| Dependencies | Multi-context | "Does this depend on CR-20260306 being complete?" |
