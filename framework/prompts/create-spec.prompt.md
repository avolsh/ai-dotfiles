---
description: "Specify stage — create a CR or IMP spec with requirements"
---
#skill:writing-specs
#skill:agent-protocol

You are running the **Specify stage** of the spec workflow. This is the
first of three hard-gated stages; do not proceed past the gate at the end.

Full process: [`<system>/spec-workflows/README.md`](../spec-workflows/README.md).

## Preconditions

- User wants to create a new CR (feature / change) or IMP (non-functional
  improvement). For bug reports, use `bug-triage.prompt.md` instead.
- The target project is identified. If unclear, ask which project in
  the workspace is affected.

## Step 1 — Load context

Before asking questions, load:

1. Target project's `.github/copilot-instructions.md` (or `AGENTS.md`).
2. `<system>/spec-workflows/spec-types.md`.
3. The relevant question list:
   - CR: `<system>/spec-workflows/questions/cr-questions.md`.
   - IMP: `<system>/spec-workflows/questions/imp-questions.md`.
4. Target project's `docs/architecture/module-map.md` (if it exists).
5. Target project's `docs/requirements/README.md` and any
   `docs/requirements/<feature>.md` baselines for the affected
   feature(s). These hold the existing functional requirements,
   invariants, and out-of-scope items that the new spec may cite,
   change, or supersede via `cites-reqs:`. If `docs/requirements/`
   does not yet exist in the target project, skip — the spec is
   net-new for that project.

## Step 2 — Ask questions

Ask **≤10 questions** chosen from the relevant question list plus any
spec-specific ones. Do not repeat questions already answered in the
user's original prompt. Stop and wait for answers before writing any
spec content.

**Mandatory every round:** ask the selected list's mandatory questions.
For CRs, ask Q1 (Scope) and Q2 (Separability). For IMPs, ask Q1
(Retrofit scope) and Q2 (Partial-application risk). Never drop them —
Q2 feeds the Split check in Step 4.

## Step 3 — Create the spec file

After answers are received:

1. Copy [`<system>/spec-workflows/templates/CR-TEMPLATE.md`](../spec-workflows/templates/CR-TEMPLATE.md)
   (or `IMP-TEMPLATE.md` for improvements) to `<project>/docs/specs/active/`.
2. File name: `CR-YYYYMMDD-<kebab-case-title>.md` (use today's date).
3. Fill front-matter: `id`, `date`, `status: specify`, `owner`, `risk`,
   `affected-repos`, `affected-docs`, `affected-code`, `skills`,
   `model-suggestion`.
4. Write `## Summary` directly after the `*Last updated:*` line with
   exactly three bullets: `Goal`, `Scope`, and `Out of scope`.
5. Fill `## Cost Estimate` directly after `## Summary`. Include:
   token-range estimate, human-attention estimate (gate count + minutes
   per gate), and a re-Specify tripwire.
6. Write `## Problem Statement`, `## Requirements` (FR-N, RFC 2119),
   `## Acceptance Criteria` (Given/When/Then, traced to FRs), `## Out
   of Scope`.
7. **Leave `## Tasks` empty.** Writing tasks here violates the workflow.

## Step 4 — Split check (mandatory, before Visualize)

Load [`<system>/skills/writing-specs/references/splitting-rules.md`](../skills/writing-specs/references/splitting-rules.md).
Evaluate every trigger in § 2 against the FR clusters plus the
Separability answer from Step 2.

If **any** trigger fires and no § 4 exception applies:

1. Propose a split plan: sibling spec IDs, FR → spec mapping, dependency
   order, and which sibling (if any) has no `depends-on:`.
2. **Pause.** Wait for the human to approve, reject, or refine the split.
3. On approval: create one spec file per sibling in
   `<project>/docs/specs/active/` using the template, cross-linked via
   `siblings:` / `depends-on:` front-matter fields.
4. In every resulting spec (including this one if it survives), fill
   `## Split Decision`:
   - Split: *"Split into: `<sibling-ids>`. This spec owns FRs `<N, M>`."*
   - Kept as one: *"Kept as one spec — `<E1|E2|E3|E4>` <reason>."*

If no trigger fires: fill `## Split Decision` with
*"Kept as one spec — no § 2 trigger matched."* and continue to Step 5.

## Step 5 — Visualize sub-step (conditional)

Run per spec (this one and every sibling created in Step 4). Check the
Visualize triggers in
[`spec-workflows/README.md § Visualize sub-step: when mandatory`](../spec-workflows/README.md#visualize-sub-step-when-mandatory).

If **any** trigger fires, switch to
[`visualize-spec.prompt.md`](visualize-spec.prompt.md) and complete that
sub-step before the gate. Otherwise, write `Skipped — <one-line reason>`
under the `## Architecture` section.

## Step 6 — Gate (hard stop)

Post one summary per spec (this one + any siblings):

- Spec ID and path
- Count of FRs and ACs
- Split Decision (kept-as-one + exception, or split into sibling IDs)
- `siblings:` / `depends-on:` front-matter
- Visualize: done / skipped (+ reason)
- `## Summary` present and aligned with the approved requirements.
- Cited REQ-IDs (front-matter `cites-reqs:` list) — or `none —
  justified in Problem Statement / Current State / Bug Description`
- Open questions (if any)

**Wait for explicit human approval of the requirements.** Do not flip
status. Do not write tasks. Do not touch code.

Only after the human approves, hand off to
[`plan-spec.prompt.md`](plan-spec.prompt.md). When multiple specs exist,
Plan advances the first spec with no unmet `depends-on:` first.

## Hard rules

- `status` is `specify` from birth and stays there until the human
  approves requirements.
- Never write the `## Tasks` table in this prompt.
- Never skip the question round. Even trivial CRs get one round.
- Never merge independently-testable features into one spec — run the
  Step 4 Split check before every requirements gate.
- Never request the requirements gate without a filled `## Split
  Decision` section in every spec (this one + siblings).
