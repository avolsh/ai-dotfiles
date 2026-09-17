# IMP-20260914-explore-mode-and-lane-review — worked example (AC-1)

*Last updated: 2026-09-17*

One idea taken through `explore.prompt.md` and then `create-spec.prompt.md` step 0 and step 2, run on 2026-09-17 in
the ai-dotfiles working tree. The agent played the explore session and hand-off lines stand in for user confirmations; the example shows the mechanics — nothing written while exploring, and a question round that does not
re-ask what the hand-off settled — not a user study.

## Idea

"The traceability scope — which types and from which date FR/AC traceability is judged — is declared twice."

## Explore — read-only

File-tree fingerprint (SHA-1 over `shasum` of every tracked, modified and untracked file) taken before and after:

| When | Fingerprint |
|---|---|
| before | `89ceac7983b3e8716d030798762a45fb6e59bb0e` |
| after | `89ceac7983b3e8716d030798762a45fb6e59bb0e` |

Identical: exploring wrote nothing. Commands run, all read-only:

```bash
grep -n "traceability_cutoff\|traceability_types" framework/spec-workflows/lifecycle.yaml
grep -n "_TRACEABILITY_CUTOFF\|_TRACEABILITY_TYPES\|_traceability_judged" scripts/validate-specs.py
grep -n "traceability_judged" framework/spec-workflows/lifecycle.yaml
grep -n "def check_ac_closure_coverage" -A12 scripts/validate-specs.py
```

Findings: `lifecycle.yaml` declares `traceability_types: [CR, IMP, BUG]` and `traceability_cutoff: '2026-09-15'` and
the `traceability_judged` macro used by two declarative rules; `validate-specs.py` repeats both as
`_TRACEABILITY_TYPES` / `_TRACEABILITY_CUTOFF` for the `check_ac_closure_coverage` plug-in. Options compared: (a) the
engine passes the schema's constants to plug-ins; (b) the plug-in reads the two values from the loaded schema; (c)
leave it, cross-referenced by a comment. Recommended (b) — no engine API change, one source.

## Hand-off block

```markdown
## Explore hand-off
- **Idea:** Declare the traceability scope once — `lifecycle.yaml` — and have the AC→closure plug-in read it.
- **Q1 Scope:** in — `scripts/validate-specs.py` (`check_ac_closure_coverage` and its two constants), a self-test; out — `lifecycle.yaml` values, the declarative traceability rules, any other plug-in constant.
- **Q2 Separability:** one cluster — a single plug-in reading two values; nothing ships alone.
- **Candidate type:** IMP — refactor with no behaviour change.
- **Candidate risk:** low — one file, validator parity provable by the existing fixtures.
- **Candidate splits:** none
- **Settled:** the plug-in reads the loaded schema (rejected: a new engine parameter — widens the plug-in signature for two values; a comment — leaves two sources).
- **Open:** unsettled — how parity is shown (self-tests only, or the old-vs-new recorder).
```

## create-spec — step 0 and step 2

Step 0 scaffolded `IMP-20260917-traceability-scope-single-source` (type and `risk: low` from the hand-off) in a
throwaway project, so no real spec was created, and ran `spec-next`:

```text
IMP-20260917-traceability-scope-single-source — IMP · standard lane · status specify
Next step: Question round, then write the spec body
Procedure: framework/skills/writing-specs/references/authoring-steps.md#a-spec-authoring-cr--imp — A. Spec authoring (CR / IMP) — Run after the Specify question round (mandatory Q1+Q2 answered).
Missing sections: Summary, Current State, Proposed Improvement, Requirements, Acceptance Criteria, Out of Scope
Questions (≤10 — framework/spec-workflows/questions/imp-questions.md):
  Q1 Retrofit-vs-rewrite scope (mandatory)
  Q2 Partial-application risk (mandatory)
  Q3 Measurable benefit
  Q4 Baseline citation impact
  Q5 Rollback / revert
  Q6 Success / failure metric
  Q7 Scope-creep guardrail
  Q8 Dependencies / sequencing
  Q9 Benefit validator
  Q10 Reversion threshold
Gate: Requirements gate — Post the per-spec summary and wait for explicit approval of the requirements
```

`spec-next` lists Q1 and Q2 as mandatory. Step 2's hand-off rule answers them from the block, and `Settled` covers
Q7 (scope-creep guardrail: other plug-in constants are out). The round step 2 yields — the example stops before
posting it, so no answers are recorded:

| Question | Source |
|---|---|
| Q1 Retrofit-vs-rewrite scope | **not asked** — hand-off `Q1 Scope` |
| Q2 Partial-application risk | **not asked** — hand-off `Q2 Separability` |
| Q7 Scope-creep guardrail | **not asked** — hand-off `Q1 Scope` out-list and `Settled` |
| Q3 Measurable benefit | asked |
| Q6 Success / failure metric | asked, together with the `unsettled` parity line |
| Q10 Reversion threshold | asked |

Q4 (no baselines in ai-dotfiles), Q5, Q8 and Q9 were dropped as already answered by the repository, as
`imp-questions.md § How to use` allows.
