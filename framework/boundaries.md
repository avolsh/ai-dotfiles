# Boundaries

*Last updated: 2026-08-13*

<!-- Canonical home for behavioural rules. Anchors below match `docs/rule-canonical-map.md` (R1, R4, R5, R11; R9 anchor-only — see docs/specs/archived/artifacts/IMP-20260514-rule-map-narrative.md). Other framework files link to these anchors rather than restate the rules. -->

> **System-scope** rules for all AI agents. Projects MAY extend via their `_canonical.md` § Boundaries
> (rendered into all three agent files by `make sync-agents`); project rules win on conflict. Three tiers,
> severity increases top to bottom.

## Always do

1. **Read your agent's project instructions file first** — `CLAUDE.md` (Claude Code), `AGENTS.md` (Codex), or `.github/copilot-instructions.md` (Copilot). All three are byte-identical copies rendered from `_canonical.md` (via `make sync-agents`) — the project-scope authority. Never edit a rendered copy directly; edit `_canonical.md` and re-render.
2. **Ensure `CLAUDE.md` and `AGENTS.md` exist** at every project root and the workspace root; if missing, create them
   via the scaffold manifest before any other work.
3. **Follow the spec workflow** — no coding until `in-progress`. See [
   `spec-workflows/spec-lifecycle.md`](spec-workflows/spec-lifecycle.md). Sole exception: owner-approved changes
   within the Direct lane ([`spec-lifecycle.md § Direct lane`](spec-workflows/spec-lifecycle.md#direct-lane)).
   This rule is also enforced mechanically by the `spec-status-guard` hook ([`hooks/README.md`](hooks/README.md)).
4. **Post task-start preflight proof** — `Task #`, precedent files read, loaded skill paths (with scope) — before the
   first edit in each task.
5. **Load all task skills before coding** — resolve project-first, then workspace (two-scope lookup).
6. **Include tests in the same task** as feature or fix logic; never defer to a follow-up task or spec.
7. **Run build and test** per the project's agent-instructions file § Build and Run before posting "The Bottom Line".
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
15. **Challenge before complying.** Do not treat the author as always correct. When an instruction, assumption, or proposed approach appears factually wrong, suboptimal, or has a materially better alternative: (1) verify any checkable claim against the codebase or framework docs first; (2) surface the doubt with evidence; (3) propose the alternative(s). Use the § Escalation protocol format when stopping; a brief inline note suffices when proceeding with a caveat.
16. <a id="named-shared-cause"></a>**Name the shared cause before the third copy.** When the same fix must be applied
    in more than two places, stop and name the shared cause before applying it, recording the decision in the Bottom
    Line. The outcome may be a shared fix or an accepted duplication — it may not be a third silent copy. Depth: [
    `skills/avoiding-duplication`](skills/avoiding-duplication/SKILL.md).

## Ask first

1. **Adding a new bounded context** or moving code between contexts.
2. **Changing AI prompts** — they affect data quality at scale.
3. **Changing spec templates, workflow definitions, or boundaries** — they govern all future work.
4. **Changing shared framework files** in `<system>/` — they affect every project in the workspace.
5. **Changing cross-repo schemas or output formats** — coordinate via a single spec listing all repos in
   `affected-repos`.
6. <a id="stability-window"></a>**Framework stability window (until 2026-07-12):** after
   IMP-20260610-stabilize-profile-switching closed, framework-scope changes (`<system>/`, this file, spec
   workflows, hooks, profile scripts) are limited to Direct-lane fixes ([
   `spec-lifecycle.md § Direct lane`](spec-workflows/spec-lifecycle.md#direct-lane)) or an explicit owner waiver.
   At the window end, review `make spec-metrics` — the framework-vs-product share decides whether the freeze
   extends. Product-repo work is unaffected.

## Never do

1. **Never** commit `.env`, `.env.local`, `.dev.vars`, or hardcoded secrets of any kind.
2. <a id="never-skip-specify"></a>**Never** skip the Specify stage — even a trivial bug needs confirmed understanding
   via the question round. The Trivial lane ([
   `spec-lifecycle.md § Trivial lane`](spec-workflows/spec-lifecycle.md#trivial-lane)) is NOT a skip: Specify still
   runs, just combined with Plan into a single gate (≤3 questions instead of ≤10). The only spec-less path is the
   Direct lane ([`spec-lifecycle.md § Direct lane`](spec-workflows/spec-lifecycle.md#direct-lane)) — ≤2 files,
   ≤30 lines, owner-approved in advance, Bottom Line + improvements-log entry mandatory.
3. **Never** populate `## Tasks` before Plan — canonical rule at [
   `spec-lifecycle.md § Rules #2`](spec-workflows/spec-lifecycle.md#never-tasks-table-at-specify).
4. **Never** flip a spec's status without the preceding human gate — three specific cases at [
   `spec-lifecycle.md § Rules #3-#5`](spec-workflows/spec-lifecycle.md#never-flip-without-gate). The closure gate
   for `low`/`trivial` risk may run asynchronously per [
   `spec-lifecycle.md § Review-after closure`](spec-workflows/spec-lifecycle.md#review-after-closure); requirements
   and plan gates are blocking in every lane.
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
