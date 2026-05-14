---
name: "agent-protocol"
description: "Operating procedures for AI agents. Context loading, checklists, output conventions, determinism. Use for spec-driven or non-trivial tasks."
---

# Agent Protocol

*Last updated: 2026-05-14*

## When to use

- Starting any spec-driven task (CR / IMP / BUG).
- You need the context-loading order before reading anything.
- Before any file edit (pre-flight + task-start hard gate).
- After any task (post-task checklist + canonical "Bottom Line").
- Working in a multi-project workspace (two-scope skill / boundary lookup).
- Resolving deep relative paths (use the `<system>/`, `<project>/`, `<workspace>/` prefixes).
- On-demand scenarios: AI batch determinism, schema-code sync, doc freshness, skills audit.

## References

- [`docs/agent-protocol.md`](../../../docs/agent-protocol.md) — path prefixes, two-scope model, context loading order + budget, pre-flight / task-start / post-task checklists, Bottom Line format, doc-update matrix, output conventions, controlled refactoring, on-demand reference (determinism, schema sync, doc freshness, skills audit).
- [`framework/boundaries.md`](../../boundaries.md) — system-scope hard rules.
- [`framework/spec-workflows/spec-lifecycle.md`](../../spec-workflows/spec-lifecycle.md) — status lifecycle and gates.
