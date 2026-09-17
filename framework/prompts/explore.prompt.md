---
description: "Explore — think an idea through before any spec exists; writes nothing, hands off to create-spec"
---
#skill:writing-specs

Pre-Specify thinking mode. Read, ask, compare — and write nothing. It ends in a hand-off block that
[`create-spec.prompt.md`](create-spec.prompt.md) takes as already-answered questions, so the settled context is not
lost between the conversation and the spec. For a claim that needs **running code** to settle, recommend
[`research-spec.prompt.md`](research-spec.prompt.md) (RES) instead; for a defect, [`bug-triage.prompt.md`](bug-triage.prompt.md).

## Preconditions

- The user has an idea, a problem or several options, and no spec for it yet.

## Steps

1. **Load context** — your agent's instructions file (`CLAUDE.md`, `AGENTS.md`, or `.github/copilot-instructions.md`
   — pick the one for your agent) and project `docs/architecture/module-map.md` if it exists. Read further code and
   docs only as the questions below need them.
2. **Understand** — restate the idea in one sentence and ask what is unclear. Ask in rounds of ≤5; stop asking when
   scope and separability are clear enough to state.
3. **Compare** — when more than one approach fits, lay out two or three with what each costs, what it rules out and
   what it depends on, citing the code or docs read. Recommend one; the user decides.
4. **Settle the create-spec inputs** — work toward the answers the spec's question round needs first: scope (in and
   out), separability (what could ship and be verified alone), candidate type, candidate risk, candidate splits.
5. **Hand off** — when the user is ready, post the block below verbatim-shaped, then offer `create-spec` (or
   `research-spec` / `bug-triage` when that is the candidate type). Stop there.

## Hand-off block

```markdown
## Explore hand-off
- **Idea:** <one sentence>
- **Q1 Scope:** in — <modules, files, workflows>; out — <what is explicitly not touched>
- **Q2 Separability:** <clusters that ship and verify alone, or "one cluster — <why>">
- **Candidate type:** <CR | IMP | BUG | RES> — <why>
- **Candidate risk:** <trivial | low | medium | high> — <why>
- **Candidate splits:** <kebab slugs with one-line scope each, or "none">
- **Settled:** <each decision taken, with the option rejected and why>
- **Open:** <questions still for the question round, or "none">
```

A line the exploration did not settle reads `unsettled` — create-spec asks it as usual.

## Hard rules

- **Write nothing.** No file, spec, scratch note, code, commit or branch — not even under `research/`. Read-only
  commands only (`grep`, `git log`, `ls`, reading files); no build, test run, install or generator that writes output.
- No spec ID, front-matter or `## Tasks` — the spec is born in `create-spec`
  ([`boundaries.md § Never do #2`](../boundaries.md#never-skip-specify) still applies there).
- Do not answer a question for the user in the hand-off: a line the user did not confirm is `unsettled`.
- A question that only running code can answer ends exploration with a RES recommendation, not a guess.
