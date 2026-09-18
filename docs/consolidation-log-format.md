# Consolidation Log — Format

*Last updated: 2026-09-16*

Format of a project's `docs/consolidation-log.md`: the per-context record of
consolidation checkpoints — each time `consolidation-due` found a bounded context
due a refactor-only IMP, and what the human decided. The process that writes it
is [`spec-lifecycle.md § Consolidation sub-step`](../framework/spec-workflows/spec-lifecycle.md#consolidation-substep);
the reader is `scripts/consolidation-due.py` (`make consolidation-due`).

---

## Front-matter

```markdown
---
threshold: 5        # optional — closures per context before it is due; default 5
since: 2026-09-14   # optional — counting starts after this date for a context with no entry yet
---
# Consolidation Log — <project>
```

- **`threshold`** — change it for a project whose contexts close specs much faster
  or slower than the default suits. A positive integer; anything else reads as 5.
- **`since`** — set once, when the log is created, so the first run counts from
  adoption rather than from the project's whole history. Without it counting starts
  at the tool's own adoption date, 2026-09-16.

A project without the file runs on both defaults and has no checkpoints yet.

## Entry template

Append at the **bottom**, one entry per context per decision. Never edit a past
entry — a changed mind is a new entry.

```markdown
### YYYY-MM-DD — <Context>

- **Outcome:** accepted — IMP-YYYYMMDD-<slug>
- **Trigger:** count 5/5
- **After:** <triggering spec id>
```

```markdown
### YYYY-MM-DD — <Context>

- **Outcome:** declined — <one-line reason>
- **Trigger:** large <spec id> (risk: high)
- **After:** <triggering spec id>
```

| Field | Rule |
|---|---|
| Heading | The decision date, then the context name exactly as `docs/architecture/module-map.md`'s `Context` column spells it (bold dropped). A name the map does not carry resets nothing. |
| **Outcome** | `accepted — <IMP id>` or `declined — <reason>`. A declined entry without a reason is not a decision. |
| **Trigger** | Copied from the `TRIGGER` column of `make consolidation-due`. |
| **After** | The spec whose closure produced the recommendation. |

## What an entry does

- **Resets the context's counter.** Closures dated **after** the entry's date count
  toward the next checkpoint; a closure on the same day does not.
- **An accepted IMP never counts.** The spec named in an `accepted` Outcome is left
  out of every context's count and never fires the large-spec trigger, so the
  refactor does not bring its own next checkpoint closer.

The script only reads this file; the agent appends the entry after the human
answers.

## Recording accepted duplication

A duplication accepted under [`boundaries.md` § Always do #16](../framework/boundaries.md#named-shared-cause)
is recorded in the spec's `## Closure Evidence` as

```markdown
- **Accepted duplication:** <what stands where> — <why it is kept>.
```

— as well as in the Bottom Line. `consolidation-due --recommend` collects these
bullets for the context the spec maps to; a decision left only in chat is not
seen at the next checkpoint.
