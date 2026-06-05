# Writing Glossary Entries

*Last updated: 2026-05-14*

Template and rules for adding domain terms to a project's `docs/glossary/` directory: file naming, entry structure, index maintenance, and an example.

---

## Entry template

```markdown
# <Term>

*Last updated: YYYY-MM-DD*

**Definition:** One-sentence definition. Avoid jargon; if jargon is
unavoidable, link each jargon term to its own glossary entry.

**Context:** Which bounded context owns this concept.

**Related terms:** [other-term](other-term.md), [related-term](related-term.md).

**Code location:** Path to the primary type definition (if applicable).

**Details:** *(optional)* Short bulleted notes — defaults, edge cases,
links to deeper architecture docs. Keep entries short and source-referenced.
```

---

## Rules

- File name: `<kebab-case-term>.md` (e.g., `viewport.md`).
- One term per file.
- Update `*Last updated: YYYY-MM-DD*` on every modification.
- Link to (don't duplicate) authoritative definitions elsewhere in the docs.
- After creating the file, add an entry to the project's
  `docs/glossary/README.md` index.
- When adding a new domain entity to code, create a matching glossary entry
  in the same change.
- Keep the `Related terms:` line empty until sibling entries exist, so the
  link checker does not flag placeholder targets.

---

## Example

> *Adapted from tobevisit-content. Paths are relative to the project's
> `docs/glossary/`.*

```markdown
# Viewport

*Last updated: 2026-02-28*

**Definition:** A rectangular geographic bounding box (defined by `low`
and `high` latitude/longitude pairs) used to segment a country into
grid cells for place discovery via Google Places API.

**Context:** Geo Reference (supporting subdomain).

**Related terms:** [place](place.md), [region](region.md), [locality](locality.md).

**Code location:** `src/contexts/geo-reference/domain/country-rectangle.ts`

**Details:**
- Default resolution: ~20 km × 20 km.
- Urban areas (major cities): ~2 km × 2 km.
- See `docs/architecture/geospatial-viewports.md` for generation logic.
```
