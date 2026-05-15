# Boundaries

*Last updated: 2026-05-14*

<!-- Canonical home for behavioural rules. Anchors below match `docs/rule-canonical-map.md` (R1, R4, R5, R9). Other framework files link to these anchors rather than restate the rules. -->

> **System-scope** rules for all AI agents. Projects MAY extend via their `.github/copilot-instructions.md` § Boundaries; project rules win on conflict. Three tiers, severity increases top to bottom.

## Always do

1. **Read the project's `.github/copilot-instructions.md` (or AGENTS.md) first** — project-scope authority.
2. **Ensure `CLAUDE.md` and `AGENTS.md` exist** at every project root and the workspace root; if missing, create them via the scaffold manifest before any other work.
3. **Follow the spec workflow** — no coding until `in-progress`. See [`spec-workflows/spec-lifecycle.md`](spec-workflows/spec-lifecycle.md).
4. **Post task-start preflight proof** — `Task #`, precedent files read, loaded skill paths (with scope) — before the first edit in each task.
5. **Load all task skills before coding** — resolve project-first, then workspace (two-scope lookup).
6. **Include tests in the same task** as feature or fix logic; never defer to a follow-up task or spec.
7. **Run build and test** per the project's `AGENTS.md` § Build and Run before posting "The Bottom Line".
8. **Write all file output in English.** Chat may use any language, but filesystem content (specs, docs, code comments, commit messages, `.github/` files) MUST be English.
9. **Post "The Bottom Line"** in the canonical format ([`skills/agent-protocol/SKILL.md`](skills/agent-protocol/SKILL.md#the-bottom-line--canonical-format)) and wait for explicit human approval before the next task.
10. <a id="last-updated-stamp"></a>**Update `*Last updated: YYYY-MM-DD*`** on every modified doc.
11. <a id="task-row-status-in-place"></a>**Update task row status in-place** as each task completes.
12. **Update the project's `module-map.md`** if the task added, removed, or renamed bounded contexts, key files, or workflow steps.
13. **Log process improvements immediately** to the project's `docs/improvements-log.md` — do not defer.
14. **Verify pipeline output** when the task touches a workflow step.

## Ask first

1. **Adding a new bounded context** or moving code between contexts.
2. **Changing AI prompts** — they affect data quality at scale.
3. **Changing spec templates, workflow definitions, or boundaries** — they govern all future work.
4. **Changing shared framework files** in `<system>/` — they affect every project in the workspace.
5. **Changing cross-repo schemas or output formats** — coordinate via a single spec listing all repos in `affected-repos`.

## Never do

1. **Never** commit `.env`, `.env.local`, `.dev.vars`, or hardcoded secrets of any kind.
2. <a id="never-skip-specify"></a>**Never** skip the Specify stage — even a trivial bug needs confirmed understanding via the question round. The Trivial lane ([`spec-lifecycle.md § Trivial lane`](spec-workflows/spec-lifecycle.md#trivial-lane)) is NOT a skip: Specify still runs, just combined with Plan into a single gate (≤3 questions instead of ≤10).
3. **Never** populate `## Tasks` before Plan — canonical rule at [`spec-lifecycle.md § Rules #2`](spec-workflows/spec-lifecycle.md#never-tasks-table-at-specify).
4. **Never** flip a spec's status without the preceding human gate — three specific cases at [`spec-lifecycle.md § Rules #3-#5`](spec-workflows/spec-lifecycle.md#never-flip-without-gate).
5. **Never** mix refactoring and feature work in the same task — extract into a separate task (or IMP spec) if scope is large.
6. <a id="continue-single-task-only"></a>**Never** treat "continue" as approval for multiple tasks; it means the **next single task only**.
7. **Never** rerun build/tests without code changes — analyze the existing output first. Flaky-test retries don't count as progress.
8. **Never** amend or force-push published commits unless the user explicitly asks.
9. **Never** gold-plate beyond the spec. "While I was in there, I also added…" is untested, unreviewed code.

## Escalation protocol

When you must stop, post:

- **Blocked on:** requirement or task ID
- **Question:** specific, answerable question
- **Options considered:** A and B with pros/cons
- **My recommendation:** with reasoning
- **Impact of waiting:** what is blocked

See [`skills/writing-specs/references/bounded-autonomy-rules.md`](skills/writing-specs/references/bounded-autonomy-rules.md) for the full decision matrix and ambiguity scoring.
