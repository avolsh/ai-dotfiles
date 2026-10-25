---
name: writing-docs
description: >
  Covers documentation conventions for glossary entries, reference schemas,
  how-to runbooks, and document freshness rules. Use when creating or
  updating documentation files in the docs/ directory.
---

# Writing Docs

*Last updated: 2026-10-25*

## When to use

- Creating a new glossary term, reference schema, or how-to runbook.
- Updating existing documentation after code changes.
- Reviewing doc freshness and cross-references.
- Adding or updating `*Last updated:*` dates.

## References

- [`docs/writing-docs.md`](../../../docs/writing-docs.md) — core rules, markdown formatting, doc-type playbook (glossary / requirements / reference / how-to / architecture / ADR), freshness rules, anti-patterns.
- [`docs/writing-glossary.md`](../../../docs/writing-glossary.md) — glossary entry template, naming rules, example.
- [`docs/baseline-citations.md`](../../../docs/baseline-citations.md), [`docs/req-id-lifecycle.md`](../../../docs/req-id-lifecycle.md), [`docs/agent-protocol.md`](../../../docs/agent-protocol.md) — requirements baselines, doc-update trigger matrix, schema-code sync.

## Links across repositories

- Cite a framework file as `<system>/…` and a file in another repository by that repository's name and its path inside it, never by a relative link out of the repo: such a link resolves under one checkout layout only, and `make links-check` reports it.
