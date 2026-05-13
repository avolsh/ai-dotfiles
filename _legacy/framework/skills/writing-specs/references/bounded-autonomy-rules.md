# Bounded Autonomy Rules

*Last updated: 2026-04-20*

Decision framework for when an agent should stop and ask vs. continue
autonomously during spec-driven work.

---

## Core principle

**Autonomy is earned by clarity.** Clear spec = low risk = continue.
Ambiguous spec = high risk = stop and ask.

---

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

---

## Ambiguity scoring

For each requirement, ask these five questions:

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

---

## Scope creep detection

Scope creep = implementing functionality not in the spec. Includes:

- Adding features the spec doesn't mention
- Handling edge cases the spec explicitly excluded
- Refactoring unrelated code "while you're in there"
- Building infrastructure for future features

**Response:** stop, check Out of Scope, file a note if not mentioned,
update spec FIRST if approved, then implement.

---

## Breaking changes

Always STOP for: endpoint removed, required field added to request,
field removed from response, status/error code changed, non-nullable
column added, enum value removed, behavior change for existing input.

Protocol: identify → escalate → propose migration path → document.

---

## Security escalation

Always escalate changes touching: authentication, authorization,
encryption/hashing, PII handling, input validation, rate limiting,
CORS/CSP, file uploads, query construction, deserialization, redirect
URLs, secrets.

---

## Escalation format

When you must stop, post:

- **Blocked on:** requirement ID
- **Question:** specific, answerable question
- **Options considered:** A and B with pros/cons
- **My recommendation:** with reasoning
- **Impact of waiting:** what is blocked

---

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
