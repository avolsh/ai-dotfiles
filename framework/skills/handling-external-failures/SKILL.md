---
name: "handling-external-failures"
description: "How a boundary result becomes a stored fact — classifying retryable vs permanent vs valid-empty, checkpointing only a validated success, keeping one meaning per sentinel, and bounding every external call. Triggers: API call failed, retry, catch block, empty result, timeout, third-party integration, marked processed but empty, pagination, error swallowed."
---

# Handling External Failures

*Last updated: 2026-08-13*

Every call that leaves the process can fail in a way the type system
cannot see: a timeout returns the same `[]` a genuinely empty query
returns. The defect these rules prevent is not the failure itself — it is
the failure being written down as a settled business fact, after which the
query that would have retried it no longer selects the record and no
alarm ever fires.

## When to use

- Writing or reviewing a `catch` around an HTTP call, SDK client, queue
  consumer, file fetch, or any other process boundary.
- Persisting the result of an external call — a checkpoint, a cursor, an
  `enrichedAt`, a `status: processed`.
- Deciding what an empty array, a missing field, or a zero count means in
  a stored document.
- Adding a retry, a backoff, or a backlog query that re-selects unfinished
  work.
- Reviewing code that "succeeds" with nothing to show for it.

## Three outcomes, not one

Classify every boundary result **before** it is stored, into exactly one
of three:

- **Retryable** — the call did not produce an answer, and the same call
  later may. Timeouts, connection resets, 5xx, 429, quota exhaustion,
  a malformed response body. Nothing about the subject is known.
- **Permanent** — the call produced an answer that will not change by
  repeating it. 404 on a stable identifier, a 4xx from a malformed
  request, a provider that has no record of the subject. The subject is
  known and the answer is negative.
- **Valid-empty** — the call succeeded and the correct answer is *none*.
  The provider was reachable, the response was well-formed, and it
  contained zero items.

Only the third is a business outcome. The first must remain selectable by
whatever query drives retries; the second is a terminal state that carries
its reason. Collapsing any two of the three is the defect — most often
retryable and valid-empty, because both surface as an empty collection.

Store the classification, not just its consequence: a record whose state
is `failed-permanent (provider-404)` can be reasoned about later; a record
that is merely `processed` with no results cannot be told apart from
success.

Whether a retryable outcome is retried immediately, deferred, or
escalated after N attempts is a per-system decision. The rule is that the
outcome is *classified* and stays *visible*, not which schedule it gets.

## Checkpoint only a validated success

A checkpoint — a cursor, a high-water mark, a `processed` flag, a
completion timestamp — is a claim that the work behind it is done. Write
it only after the result has been validated, never in a `finally` block, a
shared cleanup path, or a `catch` that "wants to move on".

Validation means the response was well-formed, matched its expected
shape, and was classified per the section above. An exception that reaches
the checkpoint site MUST leave the checkpoint unwritten.

The same holds for derived markers: a timestamp that means "we looked"
and a field that means "we found nothing" are two different facts, and a
failure may set neither of them to the value success would set.

## One sentinel, one meaning

A sentinel — an empty collection, a missing field, `null`, a zero count,
an empty output file — MUST carry at most one meaning in a given field.
When a single value would answer "still running", "finished with
nothing", "the provider failed", and "the parser rejected everything"
identically, no reader can recover which happened, and every consumer
downstream guesses.

Give the states separate representations: an explicit status field, a
discriminated result type, a reason code beside the value, or separate
fields for "attempted" and "found". The cost is one column; the
alternative is a class of data whose meaning cannot be reconstructed
afterwards, because the information was never written.

Corollary: never coerce an error into a value at the boundary. A `catch`
that returns `[]`, `0`, or `{}` has erased the distinction one line
before the code that needed it.

## Bound every external call

Every call across a process boundary declares, at the call site or in the
client it is made through:

- a **timeout** — no call waits indefinitely, including the retry;
- a **size or page bound** — a maximum response size, page count, or
  iteration cap, so a paginating provider cannot loop or exhaust memory;
- a **response-shape check** — the payload is validated against the
  expected shape before any field is read, so a 200 carrying an error
  document or an HTML login page is a classified failure and not a
  silently empty parse.

An unbounded call is a retryable failure that never resolves into one.

## References

- [`framework/boundaries.md § Always do #17`](../../boundaries.md#classify-caught-failures)
  — the always-on form of the classification rule these sections deepen.
- [`framework/skills/designing-durable-state/SKILL.md`](../designing-durable-state/SKILL.md)
  — the store-side counterpart: atomic claims, read write outcomes,
  immutable run snapshots.
- [`framework/skills/reviewing-changes/SKILL.md`](../reviewing-changes/SKILL.md)
  — dimension 4 applies these checks to a diff.
- [`docs/writing-skills.md`](../../../docs/writing-skills.md) — skill
  authoring conventions.
