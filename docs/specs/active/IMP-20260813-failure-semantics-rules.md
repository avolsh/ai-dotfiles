---
id: IMP-20260813-failure-semantics-rules
type: IMP
date: 2026-08-13
status: specify
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
Pending — Plan stage only.
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
- Coordinate with `IMP-20260813-config-and-duplication-rules`: both add a `§ Always do` rule and a `rule-canonical-map.md` section. Whichever lands second renumbers around the first; AC-5 is the check that they stayed distinct.
- Rollback: revert the whole change atomically. A partial revert leaving the boundary rule without its skills leaves an always-on rule pointing at nothing.
