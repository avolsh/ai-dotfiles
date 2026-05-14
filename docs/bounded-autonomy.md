# Bounded Autonomy

*Last updated: 2026-05-14*

Rationale for the autonomy-vs-stop decision framework, plus the rules that don't reduce to a lookup table: scope-creep detection, breaking-change protocol, security escalation, and escalation message format. Machine-lookup tables (decision matrix, ambiguity score, quick reference) live in [`framework/skills/writing-specs/references/bounded-autonomy-rules.md`](../framework/skills/writing-specs/references/bounded-autonomy-rules.md).

---

## Core principle

**Autonomy is earned by clarity.** Clear spec = low risk = continue.
Ambiguous spec = high risk = stop and ask.

The decision matrix and ambiguity score in the rules file operationalize
this principle. The procedures below cover the cases that don't reduce
to a single row.

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
