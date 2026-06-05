# Bounded Autonomy Rules

*Last updated: 2026-05-14*

Machine-lookup tables for the autonomy-vs-stop decision during spec-driven work. Rationale, scope-creep detection, breaking-change protocol, security escalation list, and escalation format live in [`docs/bounded-autonomy.md`](../../../../docs/bounded-autonomy.md).

## Decision matrix

| Signal | Action |
|---|---|
| Spec approved, requirement clear, tests exist | **Continue** |
| Requirement clear, no test yet | **Continue** (write test first) |
| SHOULD / MAY keywords | **Continue** with best judgment; document choice |
| Ambiguity > 30% of the task | **STOP** — ask for clarification |
| Breaking change to API / schema | **STOP** always |
| Security-related change (auth, crypto, PII) | **STOP** always |
| Bug found unrelated to spec | **STOP** — file separate issue |
| Spec says N/A but you disagree | **STOP** — ask the author |

## Ambiguity score

For each requirement, sum the weights for each "Yes":

1. Can I write a test right now? (No = +20%)
2. Multiple valid interpretations? (Yes = +20%)
3. Spec contradicts itself? (Yes = +30%)
4. Am I assuming user behavior? (Yes = +15%)
5. Undocumented external dependency? (Yes = +15%)

| Score | Action |
|---|---|
| 0–15% | Continue. Document your interpretation. |
| 16–30% | Continue with caution. Flag in PR. |
| 31–50% | STOP. Ask one specific question. |
| 51%+ | STOP. Spec is incomplete — request revision. |

## Quick reference

```
CONTINUE if:
  ✓ Spec approved, requirement unambiguous
  ✓ Tests can be written from the AC
  ✓ Changes are additive and non-breaking
  ✓ Refactoring internals only (no behavior change)

STOP if:
  ✗ Ambiguity > 30%
  ✗ Any breaking change
  ✗ Any security-related change
  ✗ Building something not in the spec
  ✗ Cannot write a test for the requirement
```
