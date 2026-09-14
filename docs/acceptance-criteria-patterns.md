# Acceptance Criteria Patterns

*Last updated: 2026-08-27*

Patterns for writing Given/When/Then acceptance criteria — structure, core patterns, common mistakes, and a coverage checklist. Adapt to your domain; these are starting points, not prescriptions.

---

## Pattern structure

```
### AC-N: [Descriptive name] (FR-N, NFR-N)
Given [precondition — the system/user is in this state]
When  [trigger — the user or system performs this action]
Then  [outcome — this observable, testable result occurs]
And   [additional outcome]
```

**Rules:**

1. One scenario per AC. Multiple Given/When/Then blocks = split into multiple ACs.
2. Every AC references at least one FR or NFR.
3. Outcomes must be observable and testable — no subjective language.
4. Preconditions must be achievable in a test setup.

---

## Core patterns

### Happy path

```markdown
### AC-1: Successful operation (FR-1)
Given a valid precondition
When the user performs the primary action
Then the expected success result occurs
And any side effects are observable
```

### Invalid input

```markdown
### AC-2: Rejected input (FR-2)
Given a user submitting the form
When they provide input that violates a constraint
Then the system returns an error with a specific code
And the operation is not performed
```

### Authorization

```markdown
### AC-3: Unauthorized access (FR-3)
Given a user without the required role
When they attempt the restricted action
Then the system returns 403 Forbidden
And no state change occurs
```

### State conflict

```markdown
### AC-4: Duplicate creation (FR-4)
Given a resource with the same identifier already exists
When the user attempts to create another
Then the system returns 409 Conflict
And the existing resource is unchanged
```

### External dependency failure

```markdown
### AC-5: Upstream service down (FR-5, NFR-R1)
Given the external service is unavailable
When the system attempts to call it
Then the system returns a graceful degradation response
And the failure is logged with correlation ID
```

### Boundary value

```markdown
### AC-6: Maximum length input (FR-6)
Given a user submitting a field at exactly the max allowed length
When they submit the form
Then the system accepts the input
```

### Concurrency

```markdown
### AC-7: Simultaneous conflicting operations (FR-7)
Given two users editing the same resource concurrently
When both submit changes
Then the first succeeds and the second receives a conflict error
```

### On-screen observation

A `When` naming a person at a surface makes the criterion a claim about what
that person sees. Mark it with the evidence kind that can fail for it — the
rule is at [`spec-lifecycle.md § Rules #5`](../framework/spec-workflows/spec-lifecycle.md#observation-shaped-evidence).

```markdown
### AC-8: The gallery attributes every photo (FR-8)
Given a place whose record carries three provider photos
When the operator opens the Media tab
Then each thumbnail renders, and each carries its photographer and a working source link
Evidence: manual (observation, surface, observer, date)
```

Closed on manual evidence, the Closure Evidence row reads:

```markdown
| AC-8 | Manual — opened `#/places/vln-01/media` on staging, 2026-08-24, avolsh.
  All three thumbnails rendered; photographer shown on each; source links
  resolved to Wikimedia file pages. |
```

Undated, or with no named observer, that row is not evidence.

---

## Common mistakes

| Mistake | Example | Fix |
|---|---|---|
| Vague outcome | "Then the system works correctly" | "Then the response status is 200 and body contains {field}" |
| Missing precondition | "When user logs in, then token is issued" | Add "Given a registered user with valid credentials" |
| Multiple scenarios in one AC | AC with 3 different When clauses | Split into 3 ACs |
| No FR reference | "AC-5: User sees dashboard" | "AC-5: User sees dashboard (FR-7)" |
| Untestable outcome | "Then the UI looks good" | "Then the component renders within the design-system grid" |
| Numerical floor as proof | "Then the validator reports ≥5 findings" | Require the *artifact* instead: "Then the backtest capture exists at tests/backtest-baseline.md (non-empty)". Use ≥N only when N has a real reason (perf SLA, throughput target) — a clean corpus can legitimately yield 0 findings |

---

## Coverage checklist

For each requirement, ensure at least:

- [ ] One happy-path AC
- [ ] One invalid-input AC (if the requirement involves user input)
- [ ] One error/edge-case AC (if the requirement depends on external state)
- [ ] AC references trace back to every FR and NFR (no orphans in either direction)
