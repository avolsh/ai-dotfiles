---
id: IMP-20260813-config-and-duplication-rules
type: IMP
date: 2026-08-13
status: done
owner: avolsh
risk: medium
affected-repos:
  - ai-dotfiles
affected-docs:
  - framework/skills/configuring-applications/SKILL.md
  - framework/skills/avoiding-duplication/SKILL.md
  - framework/skills/reviewing-changes/SKILL.md
  - framework/skills/writing-specs/references/authoring-steps.md
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
  - IMP-20260813-failure-semantics-rules
---
# IMP-20260813-config-and-duplication-rules
*Last updated: 2026-08-13*
## Summary
- **Goal:** Give the framework stated rules for configuration design, code duplication, and the drift defects duplication causes, so agents apply them without a per-project restatement.
- **Scope:** Two new system-scope skills (`configuring-applications`, `avoiding-duplication`); one new `boundaries.md § Always do` rule with its `rule-canonical-map.md` registration; a duplication/config checklist in `reviewing-changes` dimension 5; catalog rows in `framework/skills/README.md`, with the two skills named in `docs/ai-agent-framework.md § Skills` prose rather than a duplicate catalog (that file delegates the catalog to the README); a skill-selection instruction in `writing-specs/references/authoring-steps.md § A`. The boundary rule landed as `§ Always do #16` / `R11` — not the `R9` the plan reserved, R9 and R10 being anchor-only IDs already allocated by IMP-20260514.
- **Out of scope:** Applying any of these rules to product code — `tobevisit-content` remediation is separate sibling specs.
## Current State
No framework surface states a configuration rule of any kind, and duplication is covered by one clause — `reviewing-changes` dimension 5, *"no unnecessary complexity, duplication, or dead code"* — which names the symptom without a test for it. The gap is evidenced by a 2026-08-13 review of `tobevisit-content`: one BUG-20260812 fix copied verbatim into 4 adapter files (8 adapters share the shape); a 14-value vocabulary restated in 9 sites of which 0 are compiler-checked for completeness; 4 configuration keys with zero readers, one of them an editable admin screen that enforces nothing; 30 unchecked `as` casts on one config document; and a debug branch that prints two live API keys to stdout while the committed env template ships the flag that enables it — no rule anywhere said a configuration value carrying a secret must never reach a log. `docs/improvements-log.md` records the same failure class arriving repeatedly as separate bugs (2026-08-12 entries: a write-site fix that missed its read path; a document mapper silently dropping fields). Each was diagnosed and fixed locally; none produced a rule, so the next instance costs the same investigation.
## Proposed Improvement
State the five recurring failure classes as rules with a canonical home: layered configuration precedence, dead configuration keys, secrets reaching logs, vocabulary drift, and the repeat-fix signal. Skills carry the depth (loaded on demand); `boundaries.md` carries the single always-on behavioural rule that a fix applied in more than two places must stop for a named shared cause; `reviewing-changes` carries the checks that make the rules catchable at review, which is where they cost least. **Measurable benefit:** framework coverage of the five classes goes from 0/5 to 5/5, each with a named canonical location — grep-verifiable against `rule-canonical-map.md` and the two skills' `## References`; `make check` stays green.
## Requirements
- FR-1: `framework/skills/configuring-applications/SKILL.md` MUST state the layered precedence model (defaults → env → runtime store, merged in one declared place), the bootstrap-vs-operational split that keeps secrets and store-reaching settings out of the store, the single validated typed accessor, the rule that a key with zero readers is a defect rather than a provision for later, and the rule that a value read from a secret-bearing configuration field is never written to a log — redaction being the logger's responsibility, not each call site's.
- FR-2: `framework/skills/avoiding-duplication/SKILL.md` MUST state the axis-of-variation test, the single-source rule for vocabularies with a compiler-checkable derivation, the round-trip requirement for field-enumerating mappers that cross a persistence boundary, and the conditions under which duplication is accepted rather than removed.
- FR-3: `framework/boundaries.md § Always do` MUST carry exactly one new rule, with an HTML anchor: when the same fix must be applied in more than two places, stop and name the shared cause before applying it, recording the decision in the Bottom Line. The rule MUST link the skill carrying its depth, so the always-on statement is the entry point to the on-demand material rather than a dead end.
- FR-4: `docs/rule-canonical-map.md` MUST register the FR-3 rule with its canonical location and tracked phrase, so `make lint-rules` fails on any future verbatim restatement.
- FR-5: `reviewing-changes` dimension 5 MUST enumerate the duplication and configuration checks a reviewer applies, and link both new skills from `## References`.
- FR-6: `framework/skills/README.md § System-scope skills` and the `docs/ai-agent-framework.md` skills catalog MUST both list the two new skills.
- FR-7: `writing-specs/references/authoring-steps.md § A` MUST instruct the author to select the spec's `skills:` from both scopes' catalogs against what the change touches, rather than leaving the field to habit — the front-matter `skills:` list is the only mechanism that loads a skill at every stage and task, and a task's `Skills` column can only ever be a subset of it.
- FR-8: `make check` MUST pass at HEAD, covering `links-check`, `validate-specs`, `lint-rules`, `validate-anchors`, and the self-test suites.
## Acceptance Criteria
### AC-1: Both skills exist in canonical shape (FR-1, FR-2)
Given `framework/skills/{configuring-applications,avoiding-duplication}/SKILL.md` at HEAD
When inspected against `docs/writing-skills.md § Canonical shape`
Then each carries `name` + trigger-bearing `description` frontmatter, `## When to use`, `## References`, and a `*Last updated:*` stamp
And every rule named in FR-1 and FR-2 appears in the corresponding skill body
### AC-2: The boundary rule is stated once and protected (FR-3, FR-4)
Given `framework/boundaries.md` and `docs/rule-canonical-map.md` at HEAD
When `make lint-rules` runs
Then exit code is zero
And `boundaries.md § Always do` contains exactly one new anchored rule
And `rule-canonical-map.md` names that anchor as its canonical location with at least one tracked phrase
And the rule links the skill that carries its depth
### AC-3: Review checklist reaches the new rules (FR-5)
Given `framework/skills/reviewing-changes/SKILL.md` at HEAD
When `make validate-anchors` runs and the file is read
Then exit code is zero
And dimension 5 enumerates the duplication and configuration checks
And `## References` resolves to both new skills
### AC-4: Both skills are discoverable from the catalogs (FR-6)
Given `framework/skills/README.md` and `docs/ai-agent-framework.md` at HEAD
When each skills catalog is read
Then both new skills appear with a one-line "what it teaches" entry
### AC-5: A future spec is steered to the new skills (FR-7)
Given `authoring-steps.md § A` at HEAD
When a spec author follows it to build front-matter
Then the step names both scopes' catalogs as the source for `skills:`, and states that the task-level list is a subset of it
### AC-6: Framework checks stay green (FR-8)
Given HEAD after all preceding ACs are met
When `make check` runs
Then exit code is zero, with any pre-existing unrelated failure named in Closure Evidence
## Design
Skipped — rule authoring in the documentation corpus; no bounded context, data flow, schema, or UI surface. `risk: medium` reflects that `boundaries.md` governs all future work, not structural change, so no Visualize trigger fires (precedent: IMP-20260610-reduce-self-referential-overhead, IMP-20260617-rename-architecture-section-to-design).
## Out of Scope
- OS-1: Applying the rules to `tobevisit-content` — sibling specs from the 2026-08-13 review carry that work; this spec ships zero product-code change.
- OS-2: Mechanical enforcement beyond `make lint-rules` on the FR-3 phrase — no new linter for dead config keys or vocabulary drift; detection stays gated self-review.
- OS-3: `framework/templates/project/_canonical.md` and the project bootstrap path — new projects pick the skills up through the system-scope catalog, not a per-project restatement.
- OS-4: Vendored `framework/upstream/` skills that overlap these topics — snapshots stay frozen per `framework/upstream/README.md`.
- OS-5: Any `boundaries.md` rule beyond FR-3's — configuration and secret-logging depth lives in its skill; the sibling `IMP-20260813-failure-semantics-rules` owns the one other always-on rule this round adds.
## Split Decision
`split-recommended` evaluated, **kept as one** — dominant exception **E5** (documentation corpus). T6 fires: the Q2 separability answer identifies the two skills as shippable and verifiable before the hooks. No other trigger fires — single repo (T3 clear), no bounded contexts or data entities involved (T2, T4 unknown/clear), no external blocker (T5 clear). E5 applies in full: every FR ships a documentation file under the two shared catalogs of FR-6, all ACs close on one conformance pass (`make check`, AC-6), and the spec ships zero behavioural code change. The T6 sequencing is a Plan-stage ordering constraint — skills before the boundary rule and the review hook that link to them, or `make validate-anchors` breaks — not a split.
## Tasks

> **Before starting Task T1, set `status: in-progress` in the front-matter above.**

Plan-stage safety net (`splitting-rules.md § 3`): P1 clear (7 tasks ≤ 12); P2 clear (documentation corpus, no bounded contexts); P3 clear (near-linear chain T1→T7, no zero-dependency group — T6 consumes the T5 catalogs, T7 closes every AC). Table stands.

| # | Description | Files | Source files (read-only) | Depends on | Skills | Model | Status |
|---|---|---|---|---|---|---|---|
| T1 | `configuring-applications` skill (FR-1, AC-1): layered precedence (defaults → env → runtime store, merged in one declared place); bootstrap-vs-operational split keeping secrets and store-reaching settings out of the store; single validated typed accessor; zero-reader key is a defect; a secret-bearing configuration value never reaches a log, redaction owned by the logger. Canonical shape per `docs/writing-skills.md`. | `framework/skills/configuring-applications/SKILL.md` *(new)* | `docs/writing-skills.md`; `framework/skills/reviewing-changes/SKILL.md` *(shape precedent)*; this spec | — | writing-docs | deep | ☑ done |
| T2 | `avoiding-duplication` skill (FR-2, closes AC-1): axis-of-variation test; single-source rule for vocabularies with a compiler-checkable derivation; round-trip requirement for field-enumerating mappers crossing a persistence boundary; the conditions under which duplication is accepted rather than removed. Shape mirrors T1. | `framework/skills/avoiding-duplication/SKILL.md` *(new)* | `docs/writing-skills.md`; T1 skill *(shape)*; this spec | T1 | writing-docs | deep | ☑ done |
| T3 | Boundary rule + registration (FR-3, FR-4, AC-2), landing together per the map's parser contract: one anchored rule in `boundaries.md § Always do` (#16, `named-shared-cause`) — a fix needed in >2 places stops for a named shared cause, recorded in the Bottom Line — linking the T2 skill for depth; matching `### R11` section in the rule map with canonical location + tracked phrases. **R9/R10 were already taken** (anchor-only IDs from IMP-20260514, absent from the inventory), so the next free ID is R11, not R9. `make lint-rules` green. | `framework/boundaries.md`; `docs/rule-canonical-map.md` | T1/T2 skills *(link targets)*; `scripts/lint-rules.py` *(parser contract)* | T1; T2 | writing-docs | deep | ☑ done |
| T4 | Review hook (FR-5, AC-3): `reviewing-changes` dimension 5 enumerates the duplication and configuration checks a reviewer applies; `## References` links both new skills. `make validate-anchors` green. | `framework/skills/reviewing-changes/SKILL.md` | T1/T2 skills; `framework/boundaries.md` *(post-T3)* | T3 | writing-docs | default | ☑ done |
| T5 | Catalog rows (FR-6, AC-4): both new skills listed with a one-line "what it teaches" entry in `framework/skills/README.md § System-scope skills`. **Deviation:** `docs/ai-agent-framework.md` has no skills catalog — it delegates to the README as "the single source of truth", so the two skills are named in its § Skills prose instead of a duplicate table, which would be the exact drift defect this spec ships rules against. See Closure Evidence AC-4. | `framework/skills/README.md`; `docs/ai-agent-framework.md` | T1/T2 skill `description` frontmatter | T4 | writing-docs | fast | ☑ done |
| T6 | Skill-selection instruction (FR-7, AC-5): `authoring-steps.md § A` step 4 instructs the author to pick `skills:` from both scopes' catalogs against what the change touches, and states the task-level `Skills` column is a subset of it. Lands after T5 so the catalogs it steers toward already list the new skills. | `framework/skills/writing-specs/references/authoring-steps.md` | `framework/skills/README.md` *(post-T5)*; `framework/spec-workflows/spec-lifecycle.md § Front-matter schema` | T5 | writing-specs | default | ☑ done |
| T7 | Closure (FR-8, AC-6): run `make check` — `links-check`, `validate-specs`, `lint-rules`, `validate-anchors`, self-tests — naming any pre-existing unrelated failure in Closure Evidence; bump `*Last updated:*` stamps on every modified doc; log the five uncovered failure classes to `docs/improvements-log.md`. | `docs/improvements-log.md`; this spec; all previously edited files *(stamp verify)* | HEAD after T6 | T6 | writing-specs | default | ☑ done |
## Agent instructions
Per `<system>/boundaries.md` and `<system>/docs/agent-protocol.md`.
## Docs updates required
- `docs/rule-canonical-map.md` — new `### R<N>` section for the FR-3 rule (canonical location row + tracked phrases), per the file's parser contract.
- `docs/ai-agent-framework.md` — two rows in the skills catalog (FR-6).
- `framework/skills/writing-specs/references/authoring-steps.md` — § A step 4 gains the skill-selection instruction (FR-7).
- `framework/skills/README.md § System-scope skills` — two rows (FR-6).
- `docs/improvements-log.md` — entry recording that five recurring failure classes had no framework rule until this spec.
## Rollout / migration notes
- Implementation order is fixed by T6: both skills first, then `boundaries.md` + `rule-canonical-map.md` together, then `reviewing-changes`, then the two catalogs. The boundary rule and the review hook link to the skills, so landing either first leaves a dangling anchor and fails `make validate-anchors`.
- `authoring-steps.md` (FR-7) carries no anchor into the new skills — it points at the two catalogs — so it lands after FR-6, once those catalogs already list the skills the instruction steers an author toward.
- `boundaries.md` and `rule-canonical-map.md` land in the same task: the map's parser contract requires the tracked phrase to match the canonical file at the same commit, and `make lint-rules` fails otherwise.
- Sequencing against `IMP-20260813-failure-semantics-rules` (owner decision, 2026-08-13): the two siblings land **sequentially, this spec first**. It takes `§ Always do` #16 and `### R11` (R9/R10 are anchor-only IDs already allocated by IMP-20260514); the sibling takes #17 and `R12` once this one is `done`. Recorded as an ordering note rather than `depends-on:`, so the sibling stays free to reach `plan` on its own schedule.
- Rollback: revert the whole change atomically. Partial revert of the skills while the boundary rule survives leaves an always-on rule pointing at nothing.
- The framework stability window (`boundaries.md § Ask first #6`) expired 2026-07-12; no waiver needed.
## Closure Evidence
| AC | Evidence | Verdict |
|---|---|---|
| AC-1 | `framework/skills/configuring-applications/SKILL.md` and `framework/skills/avoiding-duplication/SKILL.md` created in canonical shape per `docs/writing-skills.md § Canonical shape` — trigger-bearing `name`/`description`, `## When to use`, `## References`, `*Last updated: 2026-08-13*`. Every FR-1 clause has its own section (layered model; bootstrap vs operational; one validated accessor; a key with no readers is a defect; secrets never reach a log), as does every FR-2 clause (axis-of-variation test; single-source a vocabulary; round-trip a field-enumerating mapper; when duplication is accepted). Both skills were surfaced by the harness on creation. | met |
| AC-2 | `boundaries.md § Always do #16` carries exactly one new anchored rule (`<a id="named-shared-cause">`), linking `skills/avoiding-duplication/SKILL.md` for depth; `docs/rule-canonical-map.md § R11` registers it with the canonical location `framework/boundaries.md § Always do #16` and three tracked phrases. `make lint-rules` → `OK (9 canonical rule(s) + 1 agent(s); 28 phrase(s) tracked)`. **ID correction:** the plan reserved R9; R9/R10 were already allocated anchor-only by IMP-20260514 and absent from the inventory, so R11 was used and the sibling's reservation moved to #17/R12. | met |
| AC-3 | `reviewing-changes` dimension 5 now enumerates six checks — repeat fix without a named shared cause (linking the #16 anchor), unchecked vocabulary restatement, mapper without a round-trip test, zero-reader config key, config merged/cast outside the single accessor, secret-bearing value reaching a log — and closes on accepted duplication being a decision, not a finding. `## References` resolves to both new skills. `make validate-anchors` → `OK (65 fragment link(s) across 131 file(s))`. | met |
| AC-4 | `framework/skills/README.md § System-scope skills` carries both rows with one-line "what it teaches" entries. **Deviation, owner decision needed:** FR-6 also named a "`docs/ai-agent-framework.md` skills catalog" that does not exist — that file states the README is "the single source of truth" and carries prose, not a table. Both skills are named with a what-it-teaches clause in its § Skills prose. Building a second catalog there would have created the unchecked restatement this spec's own rules forbid, so it was not done. | met with deviation |
| AC-5 | `authoring-steps.md § A` step 4 instructs the author to select `skills:` by walking both scopes' catalogs against what the change touches rather than by habit, and states that a task row's `Skills` column is only ever a subset — so a skill missing from front-matter is unreachable downstream. | met |
| AC-6 | `make check` → exit 0, all targets: `links-check` (132 files), `ai-install --check`, `validate-specs` (23 specs), `lint-rules`, `validate-anchors`, and six self-test suites (`check-md-links`, `hooks`, `ai-doctor`, `pre-commit`, `spec-metrics`, `profile-links`, `ai-switch` STRICT=1). No pre-existing unrelated failures to name. | met |

Reviewer sub-step (`spec-lifecycle.md § Reviewer sub-step`) not run — recommended and non-blocking for `risk: medium`, and this session's harness is configured not to spawn sub-agents unbidden. Available on request before the closure gate.
