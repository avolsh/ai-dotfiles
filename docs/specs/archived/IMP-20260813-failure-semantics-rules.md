---
id: IMP-20260813-failure-semantics-rules
type: IMP
date: 2026-08-13
status: done
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/skills/handling-external-failures/SKILL.md
  - framework/skills/designing-durable-state/SKILL.md
  - framework/skills/reviewing-changes/SKILL.md
  - framework/skills/README.md
  - framework/boundaries.md
  - docs/rule-canonical-map.md
  - docs/ai-agent-framework.md
affected-code: []
skills:
  - writing-specs
  - writing-docs
model-suggestion: default
siblings:
  - IMP-20260813-config-and-duplication-rules
---
# IMP-20260813-failure-semantics-rules
*Last updated: 2026-08-13*
## Summary
- **Goal:** Give the framework stated rules for how failure is represented and how shared state is claimed, so a technical error cannot be recorded as a settled business outcome.
- **Scope:** Two new system-scope skills (`handling-external-failures`, `designing-durable-state`); one new `boundaries.md § Always do` rule with its `rule-canonical-map.md` registration; a failure-semantics checklist in `reviewing-changes` dimension 4; catalog rows in `framework/skills/README.md` and `docs/ai-agent-framework.md`.
- **Out of scope:** Applying any of these rules to product code — the `tobevisit-content` BUG and IMP specs from the 2026-08-13 audit carry that work.
## Current State
The framework states nothing about failure representation, retry classification, or claiming shared work. `reviewing-changes` judges Bugs as "logic errors, unhandled edge cases, broken invariants" — true and too general to catch the class that actually recurs. A 2026-08-13 audit of `tobevisit-content` found that class in four subsystems at once, and named it as the single most dangerous pattern present: a technical failure is written as a valid terminal state, after which the backlog query that would retry it no longer selects the record. A Google network error resolves to an empty result and the rectangle is checkpointed as processed with zero places; a Wikimedia or R2 failure writes `{gallery: [], enrichedAt}` and the place is permanently "has no photos"; an S3 per-key delete error is not read, so the catalog document is removed while objects survive; an empty batch result stands for six distinct states — provider still working, terminal success with zero results, provider failure, empty output file, parser rejected everything, or a network error coerced to empty. The same audit found uniqueness enforced only by application queries with no index behind it, `find`-then-`insert` and `hasRunning`-then-`create` races, Mongo writes whose outcome is never read, and long-running operations that re-derive their settings at completion time from a configuration that may have changed since they started. Every one of these is project-agnostic, and none of them is a rule anywhere in `framework/`.
## Proposed Improvement
State the two halves as rules with a canonical home. `handling-external-failures` covers the boundary: retryable, permanent and valid-empty are three outcomes and not one, a checkpoint is written only after a validated success, and a sentinel value carries at most one meaning. `designing-durable-state` covers the store: uniqueness is the store's job, shared work is claimed atomically before it is acted on, a write's outcome is read, and a long operation carries an immutable snapshot of what it started under. `boundaries.md` carries the always-on half of the first — a failure must never be recorded as a settled outcome — because the decision is made while a `catch` block is being written, before any skill would load. **Measurable benefit:** framework coverage of the seven failure-representation and durable-state classes named in `## Current State` goes from 0/7 to 7/7, each with a named canonical location — grep-verifiable against `rule-canonical-map.md` and the two skills' `## References`; `make check` stays green.
## Requirements
- FR-1: `framework/skills/handling-external-failures/SKILL.md` MUST state that a boundary result is classified as retryable, permanent, or valid-empty before it is stored; that progress is checkpointed only after a validated success; that a sentinel value — an empty collection, a missing field, a zero count — MUST NOT stand for more than one state; and that every external call declares a timeout, a size or page bound, and a response-shape check.
- FR-2: `framework/skills/designing-durable-state/SKILL.md` MUST state that business uniqueness is enforced by a store constraint rather than by a read-then-write query; that shared work is claimed by an atomic transition before it is acted on; that a write's reported outcome is read and a no-op on an update-by-identity is an error; and that a long-running operation persists an immutable snapshot of the settings it started under rather than re-deriving them at completion.
- FR-3: `framework/boundaries.md § Always do` MUST carry exactly one new rule, with an HTML anchor: a caught failure MUST NOT be recorded as a settled outcome — classify it, or let it propagate. The rule MUST link the skills carrying its depth, so the always-on statement is the entry point to the on-demand material rather than a dead end.
- FR-4: `docs/rule-canonical-map.md` MUST register the FR-3 rule with its canonical location and tracked phrase, so `make lint-rules` fails on any future verbatim restatement.
- FR-5: `reviewing-changes` dimension 4 (Bugs) MUST enumerate the failure-semantics and durable-state checks a reviewer applies, and link both new skills from `## References`.
- FR-6: `framework/skills/README.md § System-scope skills` and the `docs/ai-agent-framework.md` skills catalog MUST both list the two new skills.
- FR-7: `make check` MUST pass at HEAD, covering `links-check`, `validate-specs`, `lint-rules`, `validate-anchors`, and the self-test suites.
## Acceptance Criteria
### AC-1: Both skills exist in canonical shape (FR-1, FR-2)
Given `framework/skills/{handling-external-failures,designing-durable-state}/SKILL.md` at HEAD
When inspected against `docs/writing-skills.md § Canonical shape`
Then each carries `name` + trigger-bearing `description` frontmatter, `## When to use`, `## References`, and a `*Last updated:*` stamp
And every rule named in FR-1 and FR-2 appears in the corresponding skill body
### AC-2: The boundary rule is stated once and protected (FR-3, FR-4)
Given `framework/boundaries.md` and `docs/rule-canonical-map.md` at HEAD
When `make lint-rules` runs
Then exit code is zero
And `boundaries.md § Always do` contains exactly one new anchored rule
And `rule-canonical-map.md` names that anchor as its canonical location with at least one tracked phrase
And the rule links the skills that carry its depth
### AC-3: Review checklist reaches the new rules (FR-5)
Given `framework/skills/reviewing-changes/SKILL.md` at HEAD
When `make validate-anchors` runs and the file is read
Then exit code is zero
And dimension 4 enumerates the failure-semantics and durable-state checks
And `## References` resolves to both new skills
### AC-4: Both skills are discoverable from the catalogs (FR-6)
Given `framework/skills/README.md` and `docs/ai-agent-framework.md` at HEAD
When each skills catalog is read
Then both new skills appear with a one-line "what it teaches" entry
### AC-5: The two always-on rules stay distinct (FR-3)
Given `boundaries.md § Always do` after both this spec and its sibling have landed
When the section is read
Then it carries exactly two new rules — the sibling's repeat-fix rule and this spec's failure-classification rule — with no overlap in tracked phrase
### AC-6: Framework checks stay green (FR-7)
Given HEAD after all preceding ACs are met
When `make check` runs
Then exit code is zero, with any pre-existing unrelated failure named in Closure Evidence
## Design
Skipped — rule authoring in the documentation corpus; no bounded context, data flow, schema, or UI surface. `risk: medium` reflects that `boundaries.md` governs all future work, not structural change, so no Visualize trigger fires (precedent: IMP-20260610-reduce-self-referential-overhead, IMP-20260617-rename-architecture-section-to-design).
## Out of Scope
- OS-1: Applying the rules to `tobevisit-content` — the audit's BUG and IMP specs carry that work; this spec ships zero product-code change.
- OS-2: Prescribing a concrete retry schedule, backoff curve, lease duration, or state-machine vocabulary — the rules state what must be decided, not the value to decide on, which is per-system.
- OS-3: Mechanical enforcement beyond `make lint-rules` on the FR-3 phrase — no linter for sentinel overloading or unread write outcomes; detection stays gated self-review.
- OS-4: Database-specific or provider-specific guidance (Mongo index syntax, S3 response shapes) — the skills stay store-agnostic; product baselines hold the specifics.
- OS-5: Revisiting the sibling's repeat-fix rule or the configuration rules it owns.
## Split Decision
`split-recommended` evaluated, **kept as one** — dominant exception **E5** (documentation corpus). T1 fires: the two skills are independently testable against `docs/writing-skills.md`, and FR-6's catalog rows could ship alone. E5 applies in full: every FR ships a documentation file under the two shared catalogs of FR-6, all ACs close on one conformance pass (`make check`, AC-6), and the spec ships zero behavioural code change. T3 clear (single repo); T2/T4 not applicable (no bounded contexts or data entities); T5 clear. Splitting the two skills apart would also split the one `boundaries.md` rule that both stand behind, leaving an always-on rule whose depth lives in only half its material. Sequencing — skills before the boundary rule and the review hook that link to them — is a Plan-stage ordering constraint, not a split.
## Tasks

> **Before starting Task T1, set `status: in-progress` in the front-matter above.**

Plan-stage safety net (`splitting-rules.md § 3`): P1 clear (6 tasks ≤ 12); P2 clear (documentation corpus, no bounded contexts); P3 clear (linear chain T1→T6, no zero-dependency group — T5 consumes the T1/T2 skill descriptions, T6 closes every AC). Table stands.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | `handling-external-failures` skill (FR-1, AC-1): a boundary result is classified retryable / permanent / valid-empty before it is stored; progress is checkpointed only after a validated success; a sentinel — empty collection, missing field, zero count — carries at most one meaning; every external call declares a timeout, a size-or-page bound, and a response-shape check. Store- and provider-agnostic per OS-2/OS-4. Canonical shape per `docs/writing-skills.md`. | `framework/skills/handling-external-failures/SKILL.md` *(new)* | `docs/writing-skills.md`; `framework/skills/avoiding-duplication/SKILL.md` *(shape precedent)*; this spec | — | writing-docs | deep | ☑ done |
| T2 | `designing-durable-state` skill (FR-2, closes AC-1): business uniqueness is enforced by a store constraint, not a read-then-write query; shared work is claimed by an atomic transition before it is acted on; a write's reported outcome is read and a no-op update-by-identity is an error; a long-running operation persists an immutable snapshot of the settings it started under. Shape mirrors T1. | `framework/skills/designing-durable-state/SKILL.md` *(new)* | `docs/writing-skills.md`; T1 skill *(shape)*; this spec | T1 | writing-docs | deep | ☑ done |
| T3 | Boundary rule + registration (FR-3, FR-4, AC-2, AC-5), landing together per the map's parser contract: one anchored rule in `boundaries.md § Always do` — **#17**, anchor `classify-caught-failures` — a caught failure is never recorded as a settled outcome; classify it, or let it propagate — linking both T1/T2 skills for depth; matching `### R12` section in the rule map with canonical location + tracked phrases. #16/`R11` are taken by the sibling (landed, `status: done`), so #17/`R12` are the next free IDs. Tracked phrases MUST NOT overlap R11's (AC-5). `make lint-rules` green. | `framework/boundaries.md`; `docs/rule-canonical-map.md` | T1/T2 skills *(link targets)*; `scripts/lint-rules.py` *(parser contract)*; `docs/rule-canonical-map.md § R11` *(phrase-overlap check)* | T1; T2 | writing-docs | deep | ☑ done |
| T4 | Review hook (FR-5, AC-3): `reviewing-changes` **dimension 4 (Bugs)** enumerates the failure-semantics and durable-state checks a reviewer applies — failure written as a terminal state, checkpoint before validated success, overloaded sentinel, unbounded external call, uniqueness without a store constraint, find-then-insert race, unread write outcome, settings re-derived at completion; `## References` links both new skills. Edit targets the post-sibling file (dimension 5 already carries the duplication/config checks — do not disturb). `make validate-anchors` green. | `framework/skills/reviewing-changes/SKILL.md` | T1/T2 skills; `framework/boundaries.md` *(post-T3)* | T3 | writing-docs | default | ☑ done |
| T5 | Catalog rows (FR-6, AC-4): both new skills listed with a one-line "what it teaches" entry in `framework/skills/README.md § System-scope skills`. **Known deviation, sibling precedent:** `docs/ai-agent-framework.md` has no skills catalog — it delegates to the README as "the single source of truth" — so name the two skills in its `§ Skills` prose instead of adding a duplicate table, which would be the exact drift defect this spec ships rules against. Record it in Closure Evidence AC-4. | `framework/skills/README.md`; `docs/ai-agent-framework.md` | T1/T2 skill `description` frontmatter; `docs/specs/archived/IMP-20260813-config-and-duplication-rules.md` *(deviation precedent)* | T4 | writing-docs | fast | ☑ done |
| T6 | Closure (FR-7, AC-6): run `make check` — `links-check`, `install-check`, `validate-specs`, `lint-rules`, `validate-anchors`, `tests` — naming any pre-existing unrelated failure in Closure Evidence; bump `*Last updated:*` stamps on every modified doc; log to `docs/improvements-log.md` that the audit's central pattern (technical failure recorded as a settled business outcome) had no framework rule until this spec. | `docs/improvements-log.md`; this spec; all previously edited files *(stamp verify)* | HEAD after T5 | T5 | writing-specs | default | ☑ done |
## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.
## Docs updates required
- `docs/rule-canonical-map.md` — new `### R<N>` section for the FR-3 rule (canonical location row + tracked phrases), per the file's parser contract; must not collide with the sibling's new section.
- `docs/ai-agent-framework.md` — two rows in the skills catalog (FR-6).
- `framework/skills/README.md § System-scope skills` — two rows (FR-6).
- `docs/improvements-log.md` — entry recording that the audit's central pattern had no framework rule until this spec.
## Rollout / migration notes
- Both skills land before `boundaries.md` and `reviewing-changes`, which link to them; landing either first leaves a dangling anchor and fails `make validate-anchors`.
- `boundaries.md` and `rule-canonical-map.md` land in the same task: the map's parser contract requires the tracked phrase to match the canonical file at the same commit, and `make lint-rules` fails otherwise.
- Coordinate with `IMP-20260813-config-and-duplication-rules`: both add a `§ Always do` rule and a `rule-canonical-map.md` section, and both touch `reviewing-changes` and the two skills catalogs. Owner decision 2026-08-13: the siblings land **sequentially, that spec first** — it takes #16 / `R11` (R9 and R10 are anchor-only IDs already allocated by IMP-20260514), so this one takes `§ Always do` #17 and `### R12`, and its `reviewing-changes` edit targets dimension 4 against the post-sibling file. AC-5 is the check that the two rules stayed distinct.
- Rollback: revert the whole change atomically. A partial revert leaving the boundary rule without its skills leaves an always-on rule pointing at nothing.
## Closure Evidence
| AC | Evidence | Verdict |
|---|---|---|
| AC-1 | `framework/skills/handling-external-failures/SKILL.md` and `framework/skills/designing-durable-state/SKILL.md` created in canonical shape per `docs/writing-skills.md § Canonical shape` — trigger-bearing `name`/`description`, `## When to use`, `## References`, `*Last updated: 2026-08-13*`. Every FR-1 clause has its own section (three outcomes, not one; checkpoint only a validated success; one sentinel, one meaning; bound every external call), as does every FR-2 clause (uniqueness is the store's job; claim shared work atomically; read the outcome of every write; freeze what a long operation started under). Both skills were surfaced by the harness on creation. | met |
| AC-2 | `boundaries.md § Always do #17` carries exactly one new anchored rule (`<a id="classify-caught-failures">`), linking both new skills for depth; `docs/rule-canonical-map.md § R12` registers it with the canonical location `framework/boundaries.md § Always do #17` and three tracked phrases. `make lint-rules` → `OK (10 canonical rule(s) + 1 agent(s); 31 phrase(s) tracked)`. | met |
| AC-3 | `reviewing-changes` dimension 4 now enumerates eight checks — failure stored as a finished state (linking the #17 anchor), failure and empty answer landing on one value, overloaded sentinel, unbounded external call, uniqueness without a store constraint, read-then-mark instead of an atomic claim, unread write outcome, settings re-derived at completion. `## References` resolves to both new skills. `make validate-anchors` → `OK (68 fragment link(s) across 133 file(s))`. | met |
| AC-4 | `framework/skills/README.md § System-scope skills` carries both rows with one-line "what it teaches" entries. **Deviation, sibling precedent (AC-4 there):** FR-6's "`docs/ai-agent-framework.md` skills catalog" does not exist — that file names the README as the single source of truth and carries prose, not a table. Both skills are named with a what-it-teaches clause in its § Skills prose; a second catalog would be the unchecked restatement this spec's sibling forbids. | met with deviation |
| AC-5 | `boundaries.md § Always do` carries exactly two new rules after both siblings: #16 `named-shared-cause` (R11) and #17 `classify-caught-failures` (R12). No tracked phrase overlaps — R11's three phrases are about naming a shared cause before a third copy, R12's about classifying a caught failure; `make lint-rules` green with both registered. All three R12 phrases were additionally verified to occur on a **single physical line** of `boundaries.md` (lines 41, 42, 43), avoiding the inert-phrase defect logged for R1 on 2026-08-13. | met |
| AC-6 | `make check` → exit 0, all targets: `links-check` (134 files), `ai-install --check`, `validate-specs` (23 specs), `lint-rules`, `validate-anchors`, and the seven self-test suites (`check-md-links`, `hooks`, `ai-doctor`, `pre-commit`, `spec-metrics`, `profile-links`, `ai-switch` STRICT=1). No pre-existing unrelated failures to name. | met |

Reviewer sub-step (`spec-lifecycle.md § Reviewer sub-step`) not run — recommended and non-blocking for `risk: medium`, and this session's harness is configured not to spawn sub-agents unbidden. Available on request before the closure gate.
