---
name: writing-docs
description: >
  Covers documentation conventions for glossary entries, reference schemas,
  how-to runbooks, and document freshness rules. Use when creating or
  updating documentation files in the docs/ directory.
---

# Writing Docs

*Last updated: 2026-04-29*

## When to use

- Creating a new glossary term, reference schema, or how-to runbook.
- Updating existing documentation after code changes.
- Reviewing doc freshness and cross-references.
- Adding or updating `*Last updated:*` dates.

## Core rules

1. **Update `*Last updated: YYYY-MM-DD*` on every modified doc.**
2. **Link, don't duplicate** -- reference existing docs instead of copying.
3. **Tables over narrative** where structure is clear.
4. **Diagrams over long descriptions** -- use Mermaid (`flowchart`,
   `sequenceDiagram`, `erDiagram`), keep under 30 nodes.
5. **Conciseness test:** for every paragraph, ask "Does the agent really
   need this? Can I assume it already knows this?"

## Documentation standards (adapted from upstream)

### Markdown formatting

- One H1 per file (document title).
- Do not skip heading levels (H1 -> H2 -> H3, not H1 -> H3).
- All code blocks use appropriate syntax highlighting.
- All links use descriptive text (not "click here").
- Tables have headers.

### Living documentation

- Update docs in the same PR/task as code changes.
- Outdated information removed promptly.
- README, CLAUDE.md, AGENTS.md updated with every structural change.

### Quality checklist

- [ ] All headings follow hierarchy (no skipped levels)
- [ ] All code blocks have syntax highlighting
- [ ] All links resolve (no 404s)
- [ ] All images have alt text
- [ ] No trailing whitespace
- [ ] Single blank line between sections

## Doc types

### Glossary (`docs/glossary/`)

- One file per term: `<kebab-case-term>.md`.
- Follow the template in [glossary template](glossary-template.md).
- When adding a new domain entity, create a matching glossary file.
- Update `docs/glossary/README.md` index.

### Requirements (`docs/requirements/`)

- Canonical guide:
  [baseline citations](../writing-specs/references/baseline-citations.md).
- One file per logical small feature; narrower than a bounded context,
  broader than a single implementation detail.
- Baselines describe current post-closure state for functional
  requirements, invariants, non-functional requirements, and out of
  scope items. When a closing spec changes baseline behaviour, update
  the file and bump its `Last src verified` row.

### Reference schemas (`docs/reference/`)

- One file per schema or taxonomy.
- Must stay in sync with source-code type definitions -- see
  [protocol-reference.md Schema-code sync](../agent-protocol/references/protocol-reference.md#schema-code-sync).

### How-to runbooks (`docs/how-to/`)

- Operational procedures for pipelines and infrastructure.
- Each runbook covers one workflow step or operation.
- Include prerequisites, commands, expected output, and troubleshooting.

### Architecture docs (`docs/architecture/`)

- System design, code conventions, module map.
- Mermaid diagrams recommended for context maps and data flows.

### ADRs (`docs/adr/`)

- Architecture Decision Records.
- Follow conventions in
  [spec-workflows/adr-conventions.md](../../spec-workflows/adr-conventions.md).

## Doc update triggers

See the full trigger matrix in
[agent-protocol.md Doc update trigger matrix](../agent-protocol/SKILL.md#doc-update-trigger-matrix).

## Freshness rules

- Every doc should include `*Last updated: YYYY-MM-DD*` after the title.
- Agents must update the date on every modified doc.
- Flag docs that reference non-existent files or code paths.
- Docs not updated for 6+ months should be reviewed for staleness.

## Anti-patterns

- **Copy-paste docs** -- duplicating content instead of linking leads to staleness.
- **Narrative walls** -- long paragraphs where a table or diagram would be clearer.
- **Missing freshness dates** -- docs without `Last updated` silently go stale.
- **Orphaned docs** -- files not reachable from any index within 2 links.

## Reference files

- [Glossary template](glossary-template.md) -- standard format for new terms.
