---
name: bootstrapping-project
description: >
  Scaffolds a new project — or retrofits an existing one — so it complies
  with the AI Agent Framework. Use when onboarding a repo into
  the workspace root files (when configured) or when framework structure
  needs to be added or refreshed.
---

# Bootstrapping a Project

*Last updated: 2026-05-14*

## When to use

- A new project is being added to the workspace root files (or stood up on a host with no workspace map).
- An existing project has outdated or missing framework artifacts (no `.github/copilot-instructions.md`, no `docs/specs/`, stale instructions).
- The framework in `<system>` has been upgraded and projects need to catch up.
- Standing up a new workspace root (`ai-workspace`).

## References

- [`docs/bootstrapping-project.md`](../../../docs/bootstrapping-project.md) — operating modes, workflow, verification, hard rules, file naming, content boundary, update walkthrough, anti-patterns.
- [`references/scaffold-manifest.md`](references/scaffold-manifest.md) — manifest data: required project artifacts (10), workspace root artifacts (6), recommended artifacts.
- [`framework/boundaries.md`](../../boundaries.md) — system-scope hard rules.
