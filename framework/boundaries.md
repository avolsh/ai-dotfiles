# Boundaries

*Last updated: 2026-05-11*

> **System-scope** boundaries for all AI agents working in this workspace.
> Each project MAY extend these with project-specific rules in
> `<project>/.github/copilot/instructions/general.md` (or equivalent).
> Project rules take precedence when there is a conflict.

Three tiers, severity increasing from top to bottom.

## Always do

1. **Read the project's `.github/copilot-instructions.md` (or AGENTS.md)
   first** — it is the project-scope authority.
2. **Ensure `CLAUDE.md` and `AGENTS.md` exist** at every project root and
   at the workspace root. For projects they describe project rules, tech
   stack, and build commands. For workspace roots they describe the
   workspace project list and cross-project conventions. If either file is
   missing, create it before starting any other work (follow the scaffold
   manifest).
3. **Follow the spec workflow.** No coding until the spec is in
   `in-progress`. See
   [`spec-workflows/spec-lifecycle.md`](spec-workflows/spec-lifecycle.md).
4. **Post task-start preflight proof** — `Task #`, precedent files read,
   loaded skill paths (with scope) — before the first edit in each task.
5. **Load all task skills** before coding. Resolve project-first, then
   workspace (two-scope lookup).
6. **Include tests in the same task** as feature or fix logic. Never defer
   tests to a follow-up task or spec.
7. **Run build and test** per the project's `AGENTS.md` § Build and Run
   before posting "The Bottom Line".
8. **Write all file output in English.** Chat discussion may use any
   language, but all content written to the filesystem (specs, docs,
   code comments, commit messages, `.github/` files) MUST be in English.
9. **Post "The Bottom Line"** using the canonical format in
   [`skills/agent-protocol/SKILL.md`](skills/agent-protocol/SKILL.md#the-bottom-line--canonical-format)
   and wait for explicit human approval before starting the next task.
10. **Update `*Last updated: YYYY-MM-DD*`** on every modified doc.
11. **Update task row status in-place** as each task completes.
12. **Update the project's `module-map.md`** if the task added, removed,
    or renamed bounded contexts, key files, or workflow steps.
13. **Log process improvements immediately** to the project's
    `docs/improvements-log.md` — do not defer.
14. **Verify pipeline output** if the task touches a workflow step.

## Ask first

1. **Adding a new bounded context** or moving code between contexts.
2. **Changing AI prompts** — they affect data quality at scale.
3. **Changing spec templates, workflow definitions, or boundaries** —
   these govern all future work.
4. **Changing shared framework files** in `<system>/` — they
   affect every project in the workspace.
5. **Changing cross-repo schemas or output formats** — must be coordinated
   via a single spec with all repos listed in `affected-repos`.

## Never do

1. **Never** commit `.env`, `.env.local`, `.dev.vars`, or hardcoded
   secrets of any kind.
2. **Never** skip the Specify stage — even a trivial bug needs confirmed
   understanding via the question round.
3. **Never** write a `## Tasks` table while `status` is `specify`.
4. **Never** flip a spec's status without the preceding human gate (see
   [`spec-workflows/spec-lifecycle.md § Rules`](spec-workflows/spec-lifecycle.md#rules)).
5. **Never** mix refactoring and feature work in the same task. Extract
   into a separate task (or IMP spec) if scope is large.
6. **Never** treat "continue" as approval for multiple tasks. "Continue"
   means the **next single task only**.
7. **Never** rerun build/tests without code changes — analyze the
   existing output first. Flaky-test retries don't count as progress.
8. **Never** amend or force-push published commits unless the user
   explicitly asks.
9. **Never** gold-plate beyond the spec. "While I was in there, I also
   added…" is untested, unreviewed code.

## Escalation protocol

When you must stop, post:

- **Blocked on:** requirement or task ID
- **Question:** specific, answerable question
- **Options considered:** A and B with pros/cons
- **My recommendation:** with reasoning
- **Impact of waiting:** what is blocked

See
[`skills/writing-specs/references/bounded-autonomy-rules.md`](skills/writing-specs/references/bounded-autonomy-rules.md)
for the full decision matrix and ambiguity scoring.
