# Boundaries

*Last updated: 2026-05-26*

<!-- Canonical home for behavioural rules. Anchors below match `docs/rule-canonical-map.md` (R1, R4, R5, R9). Other framework files link to these anchors rather than restate the rules. -->

> **System-scope** rules for all AI agents. Projects MAY extend via their `.github/copilot-instructions.md` §
> Boundaries; project rules win on conflict. Three tiers, severity increases top to bottom.

## Always do

1. **Read the project's `.github/copilot-instructions.md` first** — project-scope authority. `AGENTS.md` is a generated copy (via `make sync-agents`); never edit it directly. Harnesses that read only `AGENTS.md` (e.g. Codex) get byte-identical content.
2. **Ensure `CLAUDE.md` and `AGENTS.md` exist** at every project root and the workspace root; if missing, create them
   via the scaffold manifest before any other work.
3. **Follow the spec workflow** — no coding until `in-progress`. See [
   `spec-workflows/spec-lifecycle.md`](spec-workflows/spec-lifecycle.md).
4. **Post task-start preflight proof** — `Task #`, precedent files read, loaded skill paths (with scope) — before the
   first edit in each task.
5. **Load all task skills before coding** — resolve project-first, then workspace (two-scope lookup).
6. **Include tests in the same task** as feature or fix logic; never defer to a follow-up task or spec.
7. **Run build and test** per the project's `.github/copilot-instructions.md` § Build and Run before posting "The Bottom Line".
8. **Write all file output in English.** Chat may use any language, but filesystem content (specs, docs, code comments,
   commit messages, `.github/` files) MUST be English.
9. **Post "The Bottom Line"** in the canonical format ([
   `docs/agent-protocol.md § Bottom Line`](../docs/agent-protocol.md#the-bottom-line--canonical-format)) and wait for
   explicit human approval before the next task.
10. <a id="last-updated-stamp"></a>**Update `*Last updated: YYYY-MM-DD*`** on every modified doc.
11. <a id="task-row-status-in-place"></a>**Update task row status in-place** as each task completes.
12. **Update the project's `module-map.md`** if the task added, removed, or renamed bounded contexts, key files, or
    workflow steps.
13. **Log process improvements immediately** to the project's `docs/improvements-log.md` — do not defer.
14. **Verify pipeline output** when the task touches a workflow step.

## Ask first

1. **Adding a new bounded context** or moving code between contexts.
2. **Changing AI prompts** — they affect data quality at scale.
3. **Changing spec templates, workflow definitions, or boundaries** — they govern all future work.
4. **Changing shared framework files** in `<system>/` — they affect every project in the workspace.
5. **Changing cross-repo schemas or output formats** — coordinate via a single spec listing all repos in
   `affected-repos`.

## Never do

1. **Never** commit `.env`, `.env.local`, `.dev.vars`, or hardcoded secrets of any kind.
2. <a id="never-skip-specify"></a>**Never** skip the Specify stage — even a trivial bug needs confirmed understanding
   via the question round. The Trivial lane ([
   `spec-lifecycle.md § Trivial lane`](spec-workflows/spec-lifecycle.md#trivial-lane)) is NOT a skip: Specify still
   runs, just combined with Plan into a single gate (≤3 questions instead of ≤10).
3. **Never** populate `## Tasks` before Plan — canonical rule at [
   `spec-lifecycle.md § Rules #2`](spec-workflows/spec-lifecycle.md#never-tasks-table-at-specify).
4. **Never** flip a spec's status without the preceding human gate — three specific cases at [
   `spec-lifecycle.md § Rules #3-#5`](spec-workflows/spec-lifecycle.md#never-flip-without-gate).
5. **Never** mix refactoring and feature work in the same task — extract into a separate task (or IMP spec) if scope is
   large.
6. <a id="continue-single-task-only"></a>**Never** treat a one-word affirmation as approval for multiple tasks or
   gates. "continue", "next", "go", "ok", "yes", "proceed", "👍", or any equivalent single-word/emoji acknowledgment
   approves the **immediately preceding task or gate only** — never a sequence. If a human wants multiple tasks
   approved at once, require an explicit list.
7. **Never** rerun build/tests without code changes — analyze the existing output first. Flaky-test retries don't count
   as progress.
8. **Never** rewrite, amend, squash, reorder, or force-push *any* commit unless the user explicitly asks for that
   commit (or range) by ID. Applies to local and remote commits alike — detecting "published" reliably requires an
   upstream branch and a recent fetch, both of which may be absent. When in doubt, ask first; the cost of asking is
   tiny next to the cost of overwriting work.
9. **Never** gold-plate beyond the spec. "While I was in there, I also added…" is untested, unreviewed code.

## When to consult `docs/agent-protocol.md`

The full operating protocol — path prefixes, two-scope model, context-loading order with token budgets, preflight /
task-start / post-task checklists, Bottom Line format, doc-update matrix, output conventions, controlled refactoring,
and on-demand references (determinism, schema sync, doc freshness, skills audit) — lives at
[`docs/agent-protocol.md`](../docs/agent-protocol.md). Load it when:

- Starting any spec-driven task (CR / BUG / IMP / RES).
- You need the context-loading order before reading anything else.
- Before any file edit (preflight + task-start hard gate).
- After any task (post-task checklist + canonical Bottom Line).
- Working in a multi-project workspace (two-scope skill / boundary lookup).
- Resolving deep relative paths (use the `<system>/`, `<project>/`, `<workspace>/` prefixes).
- On-demand: AI batch determinism, schema-code sync, doc freshness audit, skills audit.

## Escalation protocol

When you must stop, post:

- **Blocked on:** requirement or task ID
- **Question:** specific, answerable question
- **Options considered:** A and B with pros/cons
- **My recommendation:** with reasoning
- **Impact of waiting:** what is blocked

See [
`skills/writing-specs/references/bounded-autonomy-rules.md`](skills/writing-specs/references/bounded-autonomy-rules.md)
for the full decision matrix and ambiguity scoring.
