# Framework Sub-agents

*Last updated: 2026-06-05*

System-scope sub-agent definitions. Each agent is a single markdown file
with YAML front-matter (the contract) and a system-prompt body (the
agent's instructions). Sub-agents are the **exception**, not the default:
the main agent does the work in its own context, and the carrier of
context is the **artifact** (spec, plan), not an agent role.

For the broader framework context see `docs/ai-agent-framework.md`. The
lifecycle gates and status rules that constrain agent behavior live at
[`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md).

---

## When a sub-agent is justified

A sub-agent earns its existence **only** by a mechanical need:

- **Context isolation** — a fresh context that must not inherit the main
  thread's reasoning (e.g. a reviewer that judges a diff cold).
- **Parallelism** — independent work that can run concurrently.
- **Read-only privilege** — a worker that should diagnose but never write.

If none of these applies, do the work inline. Two things are explicitly
**not** justifications:

- **Role decomposition** (author / architect / developer as separate
  agents). It serializes coupled decisions and isolates context that
  belongs together. Authoring, the Split check, and task decomposition
  run inline in the main context — see
  [`writing-specs/references/authoring-steps.md`](../skills/writing-specs/references/authoring-steps.md).
- **A search a generic read-only pass already covers.** Precedent search
  is the main agent's own `Grep`/`Glob`, or the built-in read-only
  explore sub-agent returning a summary — not a bespoke agent.

---

## Front-matter schema

```yaml
---
name: <kebab-case-id>              # required; matches filename without .md
description: <short prose>         # required; what the agent does, in one sentence
model-suggestion: fast|default|deep # required; default tier per docs/model-selection.md
tools-allowed:                     # required list; tools the agent may invoke
  - Read
inputs:                            # optional; named inputs the prompt passes in
  - <name>: <one-line semantics>
outputs:                           # optional; what the agent returns
  - <name>: <one-line semantics>
preconditions:                     # optional; what must be true before invocation
  - <one-line check>
error-modes:                       # optional; documented failure modes
  - <one-line description>
---
```

- **`name`** — kebab-case; MUST equal the filename basename without `.md`.
- **`description`** — one sentence, ≤120 chars; harnesses use it to pick the agent.
- **`model-suggestion`** — `fast | default | deep` per [`docs/model-selection.md`](../../docs/model-selection.md).
- **`tools-allowed`** — explicit allowlist; agents inherit no tools by default. A read-only agent lists no `Write`/`Edit`.
- **`inputs` / `outputs` / `preconditions` / `error-modes`** — documentation aids for the human and the orchestrating prompt; not structurally enforced.

## Body structure

H2 sections in order: `## Purpose`, `## Inputs`, `## Steps`,
`## Output contract`, `## Failure modes`. The body is the system prompt,
written in the imperative. It MUST NOT restate rules canonicalized in
[`boundaries.md`](../boundaries.md) or
[`spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md) — link instead
(see [`docs/rule-canonical-map.md`](../../docs/rule-canonical-map.md));
`make lint-rules` flags inline restatements.

## Delegation contract (Claude Code path)

The orchestrating prompt delegates via the `Agent` tool:

```
Agent({
  subagent_type: "<name>",            # matches the agent's `name:` field
  description: "<short task summary>",
  prompt: "<self-contained brief>"     # everything the agent needs to act cold
})
```

The prompt block MUST be **self-contained** (agents start cold — include
paths, context, expected output format), produce a **single deliverable**,
and never nest delegation (keep the call graph one level deep).

## Fallback for harnesses without sub-agents

GitHub Copilot CLI and OpenAI Codex CLI have no `Agent` mechanism. The
principle is harness-independent: run the agent as a **separate
empty-context session** whose only inputs are the brief the contract
names. For the reviewer that is the spec + `git diff` + the
`reviewing-changes` skill.

## Validator + lint integration

- **`scripts/validate-specs.py`** enforces this schema on every
  `framework/agents/*.md`: `name`, `description`, `model-suggestion`,
  `tools-allowed` present; `name` equals the filename stem;
  `model-suggestion` in the `fast|default|deep` enum.
- **`scripts/lint-rules.py`** flags inline restatements of an agent's
  contract outside `framework/agents/`.

Run via `make sync-agents-check`.

---

## Currently-defined agents

| Agent | Stage | Model | Tools | Purpose |
|---|---|---|---|---|
| `reviewer` | in-progress (recommended sub-step) | deep | read-only | Reviews a change cold against its spec; returns `PASS` or `file:line → violated clause`. |

`reviewer` is the sole bespoke sub-agent: it earns isolation (fresh
context) and read-only privilege. Precedent search and all spec authoring
run inline in the main context.
