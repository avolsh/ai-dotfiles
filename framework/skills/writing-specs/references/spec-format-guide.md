# Spec Format Guide

*Last updated: 2026-04-20*

Quick reference for spec sections. For templates, see
[`<root>/.github/copilot/spec-workflows/templates/`](../../../spec-workflows/templates/).

---

## Document structure

A spec has these sections. If a section does not apply, write
"N/A — [reason]" so reviewers know it was considered, not skipped.

1. Title and YAML front-matter
2. Problem Statement (Context)
3. Requirements (FR-N, NFR-N)
4. Acceptance Criteria (Given/When/Then)
5. Architecture (Mermaid diagrams, if Visualize triggered)
6. Out of Scope
7. Tasks (filled during Plan stage)

---

## Problem Statement

Answer: **Why does this feature exist?**

Include: the problem (with evidence), current state, business justification,
constraints. Exclude: implementation details, solution proposals, lengthy
background (2–4 paragraphs max).

---

## Functional Requirements — RFC 2119

Each requirement MUST be:

1. **Atomic** — one behavior per requirement.
2. **Testable** — you can write a test that proves it works or not.
3. **Numbered** — sequential `FR-N` format for traceability.
4. **Specific** — no ambiguous adjectives ("fast", "secure", "user-friendly").

```markdown
- FR-1: The system MUST accept login via email and password.
- FR-2: The system MUST reject passwords shorter than 8 characters.
- FR-3: The system MUST NOT include the password hash in any API response.
- FR-4: The system SHOULD support "remember me" with a 30-day refresh token.
- FR-5: The system MAY display last login time on the dashboard.
```

## Non-Functional Requirements

Every NFR needs a **measurable threshold**.

| Category | Example |
|---|---|
| Performance | `NFR-P1: API MUST respond in < 500ms (p95) under 1,000 concurrent users.` |
| Security | `NFR-S1: Failed logins MUST be rate-limited to 5/min per IP.` |
| Accessibility | `NFR-A1: Color contrast MUST meet 4.5:1 ratio (WCAG 1.4.3).` |
| Reliability | `NFR-R1: Service MUST maintain 99.9% uptime.` |

Bad: "The system should be fast." (Not measurable.)

---

## Acceptance Criteria — Given/When/Then

```
Given [precondition — the world is in this state]
When  [action — the user or system does this]
Then  [outcome — this observable result occurs]
```

Rules:

1. Every AC MUST reference at least one FR or NFR. Orphaned criteria = missing requirement.
2. Every AC MUST be testable by a machine.
3. No subjective language.
4. One scenario per AC.

```markdown
### AC-1: Successful login (FR-1, FR-3)
Given a registered user with valid credentials
When they POST /api/auth/login
Then they receive a 200 response with a valid JWT token

### AC-2: Invalid password (FR-1)
Given a registered user
When they POST /api/auth/login with an incorrect password
Then they receive a 401 response with error "INVALID_CREDENTIALS"
```

---

## Edge Cases and Error Scenarios

For every external dependency, specify at least one failure scenario:

- Database: connection lost, timeout, constraint violation
- API: 4xx, 5xx, timeout, invalid response
- User input: empty, too long, wrong type

Format: `EC-N: <trigger> → <expected behavior>.`

---

## API Contracts

Use the project's primary type notation. For each endpoint define:

1. HTTP method and path
2. Request body (fields, types, constraints, defaults)
3. Success response (status code, body shape)
4. Error responses (each error code with status and body)

---

## Data Models

Table format with field, type, and constraints. Rules:

1. Every entity in requirements MUST have a data model.
2. Constraints MUST match requirements.
3. Include indexes for performance-critical queries.

---

## Out of Scope

Format: `OS-N: <item> — <reason>.`

Rules:

1. Every feature discussed and rejected MUST be listed.
2. Include the reason — "not now" is not a reason.
3. Link to future specs when the exclusion is a deferral.

---

## Review checklist

- [ ] Every section filled (or marked N/A with reason)
- [ ] All requirements use FR-N / NFR-N numbering
- [ ] RFC 2119 keywords are UPPERCASE
- [ ] Every AC references at least one requirement
- [ ] Every AC uses Given/When/Then
- [ ] Edge cases cover each external dependency failure
- [ ] Out of Scope lists items discussed and rejected
- [ ] No placeholder text remains
