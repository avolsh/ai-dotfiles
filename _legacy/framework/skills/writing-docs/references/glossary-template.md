# Glossary Template

*Last updated: 2026-03-23*

Use this template when adding a new domain term to `docs/glossary/`.

## Template

```markdown
# <Term>

**Definition:** One-sentence definition.

**Context:** Which bounded context owns this concept.

**Related terms:** Links to related glossary files.

**Code location:** Path to the primary type definition (if applicable).
```

## Rules

- File name: `<kebab-case-term>.md` (e.g., `viewport.md`).
- One term per file.
- After creating the file, add an entry to `docs/glossary/README.md` index.
- When adding a new domain entity to code, create a matching glossary entry.

## Example

> *Adapted from tobevisit-content for illustration. Paths are relative to
> the project's `docs/glossary/`.*

```markdown
# Place

**Definition:** A physical location relevant to tourists, ingested from
external providers and classified by AI filtering.

**Context:** Place Catalog (core).

**Related terms:** [Place Details](place-details.md), [Place Category](place-category.md).

**Code location:** `src/contexts/place-catalog/domain/place.ts`
```

