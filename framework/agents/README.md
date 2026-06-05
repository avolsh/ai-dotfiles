# Framework Sub-agents

*Last updated: 2026-05-14*

System-scope sub-agent definitions. Each agent is a single markdown file
with YAML front-matter (the contract) and a system-prompt body (the
agent's instructions). Workflow prompts under `framework/prompts/`
delegate stage-specific work to these agents, moving context off the
main thread.

For the broader framework context see `docs/ai-agent-framework.md` and
`docs/agent-protocol.md § delegation contract`. The lifecycle gates and
status rules that constrain agent behavior live at
[`framework/spec-workflows/spec-lifecycle.md`](../spec-workflows/spec-lifecycle.md).

---

## Why sub-agents

A workflow prompt (e.g. `create-spec.prompt.md`) currently runs every
Specify-stage step in the main context — questions, draft, Split check,
gate summary. That pulls 10-12 KiB of framework docs into main before
the first spec character is written.

Delegating each step to a sub-agent gives the agent its own context
budget; the main thread keeps only the orchestration pointer + the
agent's output. Measured per IMP-20260514-framework-subagents FR-5:
target ≥30% main-context reduction.

## When NOT to use a sub-agent

- Trivial one-step work that fits in a sentence (just do it inline).
- Anything that needs the orchestrating conversation's state (sub-agents
  start cold; pass everything needed via the prompt).
- Closure / gate decisions that need human approval — gates stay in
  the main thread.

---

## File layout

```
framework/agents/
├── README.md                  ← this file (contract + conventions)
├── spec-author.md             ← Specify-stage: drafts spec body
├── splitter.md                ← Specify-stage: runs Split check
├── task-planner.md            ← Plan-stage: decomposes to vertical-slice tasks
└── precedent-finder.md        ← Task-start: locates nearest precedent files
```

One file per agent. Filename matches the `name:` field. Kebab-case.
`.md` extension.

---

## Front-matter schema

```yaml
---
name: <kebab-case-id>              # required; matches filename without .md
description: <short prose>         # required; what the agent does, in one sentence
model-suggestion: fast|default|deep # required; default tier per docs/model-selection.md
tools-allowed:                     # required list; tools the agent may invoke
  - Read
  - Write
  - Bash
  - Grep
  - Edit
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

### Field details

- **`name`** — kebab-case identifier; the workflow prompt references this when delegating. MUST equal the filename basename without `.md`.
- **`description`** — one sentence, ≤120 chars, used by harnesses to pick the agent. Describe the action, not the implementation.
- **`model-suggestion`** — one of `fast | default | deep` per [`docs/model-selection.md`](../../docs/model-selection.md). Most Specify-stage agents are `deep` (design-heavy); precedent-finder is `default` (mechanical).
- **`tools-allowed`** — explicit allowlist. Sub-agents inherit no tools by default; list every tool the agent may invoke. Typical Specify-stage agent: `Read, Write`. Task-execution agent may need `Bash, Grep, Edit`.
- **`inputs` / `outputs` / `preconditions` / `error-modes`** — documentation aids. The harness doesn't enforce these structurally; they describe the contract for human readers and for the orchestrating prompt.

### Naming convention

- `<name>.md` filename, with `name` in kebab-case.
- One H1 in the body: `# <Title Case Name>` (e.g. `# Spec Author`).
- The body is the system prompt the agent runs under — written in the
  imperative ("You are…", "When invoked, do X"), not descriptive.

---

## Body structure

Each agent body MUST contain these H2 sections in order:

```markdown
## Purpose
<one paragraph: what this agent does and when it fires>

## Inputs
<bulleted list of inputs passed in; mirror front-matter `inputs:`>

## Steps
<numbered list of imperative steps the agent runs>

## Output contract
<exact shape of what the agent returns — block formats, sections, structure>

## Failure modes
<list of expected failure conditions and the corresponding stop signal>
```

The body MUST NOT restate rules already canonicalized in
`framework/boundaries.md` or `framework/spec-workflows/spec-lifecycle.md`.
Link to those anchors instead — see [`docs/rule-canonical-map.md`](../../docs/rule-canonical-map.md)
for the catalog. `make lint-rules` flags inline restatements.

---

## Delegation contract (Claude Code path)

In a Claude Code harness, the orchestrating prompt delegates to a
sub-agent via the `Agent` tool:

```
Agent({
  subagent_type: "<name>",            # matches the agent's `name:` field
  description: "<short task summary>",  # one-line context for the picker
  prompt: "<self-contained brief>"      # everything the agent needs to act cold
})
```

Three rules for the prompt block:

1. **Self-contained.** The sub-agent starts cold — no shared chat history. Include file paths, task-specific context, expected output format.
2. **Single deliverable.** Each invocation produces one deliverable. Don't bundle "draft the spec AND run the split check" into one agent — that's what splitter and spec-author exist for separately.
3. **No nested delegation.** Sub-agents MUST NOT invoke their own sub-agents. Keep the call graph one level deep to avoid context-tree confusion.

---

## Fallback for tools without sub-agent support

GitHub Copilot Chat and OpenAI Codex CLI do not implement an `Agent`-style
sub-call mechanism today. Workflow prompts that delegate MUST include
a fallback paragraph for these harnesses:

```markdown
> **Delegation:** if your harness supports the `Agent` tool (Claude Code),
> delegate this step to `<system>/agents/<name>.md`. Otherwise, inline the
> agent's body and follow its Steps in the main context.
```

When the fallback fires, the main thread DOES pay the full context cost
for that step — that's the trade-off. The FR-5 ≥30% reduction target
applies to Claude Code; non-Claude harnesses see ≤5% improvement (just
from the slimmer prompt itself). This is documented as a known scope
boundary at OS-1 of IMP-20260514-framework-subagents.

---

## Inline example

A complete minimal agent definition. Not one of the real agents (those
land in S3/S4); included here as the canonical shape.

```markdown
---
name: example-echo
description: Returns its input verbatim, prefixed with the current date. Reference-only example.
model-suggestion: fast
tools-allowed:
  - Read
inputs:
  - text: arbitrary string to echo back
outputs:
  - response: the input string, prefixed with YYYY-MM-DD
preconditions:
  - the input string is non-empty
error-modes:
  - empty input → return "ERROR: empty input"
---

# Example Echo

## Purpose
Reference-only sub-agent demonstrating the minimal contract.
Returns its input verbatim, prefixed with today's date.

## Inputs
- `text`: the string to echo

## Steps
1. Verify `text` is non-empty; if empty, return "ERROR: empty input" and stop.
2. Format today's date as YYYY-MM-DD.
3. Return `<date>: <text>`.

## Output contract
A single line: `<date>: <text>`. No additional formatting.

## Failure modes
- Empty `text` → fail-fast with `"ERROR: empty input"`.
```

---

## Validator + lint integration

S6 of IMP-20260514-framework-subagents extends the existing checks:

- **`scripts/validate-specs.py`** gains a check class enforcing this
  schema: every `framework/agents/*.md` MUST have `name`, `description`,
  `model-suggestion`, `tools-allowed`; `name` MUST equal the filename
  stem; `model-suggestion` MUST be in the `fast|default|deep` enum.
- **`scripts/lint-rules.py`** flags inline restatements of an agent's
  contract outside `framework/agents/` (e.g. a workflow prompt copying
  the agent's Steps verbatim instead of delegating).

Run via `make sync-agents-check` (the CI alias).

---

## Currently-defined agents

| Agent | Stage | Model | Purpose |
|---|---|---|---|
| `spec-author` | Specify | deep | Drafts spec body from question answers |
| `splitter` | Specify | deep | Runs Split check, produces `## Split Decision` block |
| `task-planner` | Plan | deep | Decomposes approved spec into vertical-slice tasks |
| `precedent-finder` | Task-start | default | Locates nearest precedent files for a task's Files column |

Land in S3 (`spec-author`, `splitter`) and S4 (`task-planner`, `precedent-finder`).
