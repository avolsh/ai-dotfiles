---
name: "designing-durable-state"
description: "Making persisted state trustworthy under concurrency — enforcing uniqueness in the store instead of a read-then-write query, claiming shared work with an atomic transition, reading the outcome of every write, and freezing the settings a long run started under. Triggers: duplicate records, unique index, race condition, find then insert, job queue, worker picks up job, update matched nothing, config changed mid-run, upsert."
---

# Designing Durable State

*Last updated: 2026-08-13*

Application code cannot make a rule true — it can only observe that the
rule held a moment ago. Every guarantee expressed as "check, then act" is
an assumption about the gap between the two, and under two workers, two
requests, or one retry, the gap is where duplicates, double-processing,
and lost writes appear.

## When to use

- Adding or reviewing a uniqueness rule ("one active run per source",
  "one place per external id").
- Writing a worker, scheduler, cron, or queue consumer that picks up work
  other processes can also pick up.
- Writing an insert, update, or delete whose result the code does not
  currently inspect.
- Building a long-running job, batch, or pipeline step that reads
  configuration.
- Diagnosing duplicate rows, work processed twice, or a record that
  "disappeared" without an error.

## Uniqueness is the store's job

A business uniqueness rule MUST be enforced by a store constraint — a
unique index, a primary key, an exclusion constraint — and not by a query
that reads first and writes second. A `find`-then-`insert`, a
`countDocuments() === 0`-then-`create`, or a `hasRunning()`-then-`start`
is correct only while exactly one process runs it at a time, and nothing
in the code says that.

The application query stays — it produces the friendly error. The
constraint is what makes the rule true; the query is what makes the
failure readable. When they disagree, the constraint wins, so the write
path MUST handle the constraint violation as an expected outcome rather
than letting it surface as an unhandled error.

A rule the store cannot express (uniqueness over a computed condition, a
cross-collection invariant) is a design signal: model the invariant so a
constraint *can* hold it, or make the operation single-writer by
construction.

## Claim shared work atomically

Work visible to more than one process is **claimed** before it is acted
on, by a single atomic transition that both selects and marks the record —
a conditional update, a compare-and-set on a status field, a
`findOneAndUpdate` guarded by the previous state. The winner is the
process whose transition reported a match; every other process is told it
lost and moves on.

Reading a queue and then updating what was read is not a claim: two
workers read the same row. Acting first and marking afterwards is not a
claim either — a crash between the two leaves work that is neither done
nor reclaimable.

A claim implies a release path. Decide, per system, how a claim held by a
dead process returns to the pool — an expiry on the claim, a heartbeat, a
sweep of stale claims. The rule is that the claim exists and can be
released, not which mechanism releases it.

## Read the outcome of every write

Every write reports what it did — rows affected, matched count, modified
count, deleted keys, per-item errors in a batch. That report is part of
the result, not diagnostics, and code that ignores it has assumed an
outcome it never observed.

Two cases are errors, not noise:

- An **update or delete by identity that matched nothing**. The record
  the code believed in is gone, renamed, or was never there. Silently
  continuing turns a broken assumption into a lost write.
- A **partial batch failure**. A bulk or per-key operation that reports
  failures for some items has not completed; treating the call as
  successful because it did not throw leaves the failed items behind —
  and when the caller then deletes the parent record, the orphans are
  unreachable.

Where a write and its cleanup span two systems, order them so a failure
leaves recoverable garbage rather than an unrecoverable gap: verify the
dependent deletions succeeded before removing the record that points to
them.

## Freeze what a long operation started under

A long-running operation persists an **immutable snapshot** of the
settings, thresholds, model choices, prompt versions, and feature flags
it started under, and reads its own snapshot for the rest of the run.

Re-deriving settings at completion time — reading the config again to
decide how to interpret, price, or classify a result — attributes the
outcome to a configuration that may not be the one that produced it.
Runs then become impossible to reproduce or audit, and a mid-run change
silently splits a batch into two incompatible halves.

The snapshot is written when the run is created, alongside its identity,
and is never updated by the run. A change to the live configuration
applies to the next run.

## References

- [`framework/boundaries.md § Always do #17`](../../boundaries.md#classify-caught-failures)
  — the always-on form of the classification rule these sections deepen.
- [`framework/skills/handling-external-failures/SKILL.md`](../handling-external-failures/SKILL.md)
  — the boundary-side counterpart: outcome classification, checkpoints,
  sentinels, call bounds.
- [`framework/skills/configuring-applications/SKILL.md`](../configuring-applications/SKILL.md)
  — where the settings a snapshot freezes come from.
- [`framework/skills/reviewing-changes/SKILL.md`](../reviewing-changes/SKILL.md)
  — dimension 4 applies these checks to a diff.
- [`docs/writing-skills.md`](../../../docs/writing-skills.md) — skill
  authoring conventions.
