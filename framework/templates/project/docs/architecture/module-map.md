# Module Map

*Last updated: YYYY-MM-DD*

Quick-reference map of all bounded contexts, their purpose, key files,
and dependencies. Use this to understand module boundaries before making
changes.

---

## Bounded Contexts

| Context | Directory | Purpose | Key files | Depends on |
|---|---|---|---|---|
| **<context-name>** | `src/<path>/` | <one-line purpose> | `<key/files.ts>` | <other contexts or "—"> |
<!-- Add one row per bounded context. -->

## Cross-Cutting Files

| File | Purpose | Touched by |
|---|---|---|
| `<path>` | <purpose> | <which contexts modify it> |
<!-- Add cross-cutting files (DI roots, configuration, shared resources). -->

## Workflow → Context Mapping

| Workflow step | Primary context | Secondary contexts |
|---|---|---|
| `<step-name>` | <primary> | <secondary or "—"> |
<!-- Map each workflow step or entry point to its primary bounded context. -->
