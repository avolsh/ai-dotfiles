---
name: "avoiding-duplication"
description: "When repeated code is a defect and when it is fine — the axis-of-variation test, single-sourcing a vocabulary so the compiler catches a missed site, round-tripping mappers that enumerate fields, and the conditions for accepting a copy. Triggers: duplication, DRY, copy-paste, repeated fix, extract shared helper, same change in several files, status values repeated, mapper drops fields."
---

# Avoiding Duplication

*Last updated: 2026-08-13*

Duplication is not wrong because it is repetitive — it is wrong when one
copy can change and the others cannot notice. These rules separate the
duplication that produces drift defects from the duplication that is
cheaper than the abstraction replacing it.

## When to use

- Applying the same fix, guard, or branch in a second or third place.
- Extracting a shared helper, base class, or generic — or deciding not to.
- Adding a member to a status set, category list, error-code set, or any
  other closed vocabulary.
- Writing or changing a mapper between a domain object and its stored
  form (`toDocument`/`fromDocument`, DTO ↔ entity, serializer).
- Reviewing a diff that touches several files with near-identical hunks.

## The axis-of-variation test

Before unifying two similar sites, ask what varies between them and along
how many axes:

- **One axis** — the sites differ in a single dimension (a provider name,
  a field, a threshold). That axis is a parameter; everything else is
  genuinely shared. Extract.
- **Several unrelated axes** — the sites differ in ways that have no
  reason to move together. The shape is *coincidental*. Extracting it
  couples code that will diverge, and the abstraction then grows a flag
  per divergence until it is harder to read than the copies were.

The test runs in both directions: it is as much a licence to leave two
similar functions alone as it is an instruction to merge them.

## Single-source a vocabulary

A closed vocabulary — statuses, categories, locales, error codes, step
names — is declared **once**, and every other use *derives* from that
declaration so that adding a member breaks the build at each site that
must handle it.

Derivation is what makes the rule enforceable; restating the members is
not derivation:

- A union type plus `Record<Member, T>`, or a `switch` over the union with
  no `default`, is checked — a new member is a compile error.
- A hand-written array of the same strings, a second literal union, a
  validation regex listing the values, a UI dropdown, a database enum
  written by hand — none of these are checked. Each is a site that will
  quietly fall behind, and nothing reports it.

If a vocabulary must cross a boundary that cannot import the declaration
(a database enum, a JSON schema, another service's contract), generate
that artifact from the declaration or add a test that asserts the two
agree. An unchecked restatement is drift with a delay fuse, not a copy.

## Round-trip a field-enumerating mapper

A mapper that *lists* fields — `toDocument`, `fromDocument`, a DTO
assembler, a hand-written serializer — silently drops whatever it forgets.
Nothing fails: the write succeeds, the read returns an object of the right
type, and the missing field is indistinguishable from a field that was
never set.

Any mapper that enumerates fields **and crosses a persistence boundary**
MUST have a round-trip test: build a fully-populated instance, map it out
and back, assert deep equality. The test is what turns "someone forgot to
add the field to the mapper" from a data-loss bug into a build failure.

Prefer derivation over enumeration where the language allows it — a
mapper that spreads a validated object needs no list to fall behind.

## When duplication is accepted

Removing duplication is not automatic. Keep the copies, and say why, when:

- The sites live in **different bounded contexts or deployables**, and
  sharing would couple their release cycles. Contexts drift on purpose.
- The similarity is **coincidental** by the axis-of-variation test.
- The abstraction needs **more configuration than the duplication has
  lines** — three flags to unify six lines is a net loss.
- The copy is a **frozen snapshot**: vendored code, generated output, an
  archived document. It is not maintained, so it cannot drift.
- The sites are **test fixtures or assertions**, where explicitness is
  worth more than reuse and a shared factory hides what a case tests.

Accepted duplication is a decision, so record it — a one-line comment or
a note in the Bottom Line. Undocumented, it is indistinguishable from an
oversight, and the next reader either "fixes" it or copies the pattern.

## References

- [`framework/boundaries.md`](../../boundaries.md) — § Always do: name the
  shared cause before applying the same fix a third time.
- [`framework/skills/configuring-applications/SKILL.md`](../configuring-applications/SKILL.md)
  — the configuration counterpart, including dead keys and secret handling.
- [`framework/skills/reviewing-changes/SKILL.md`](../reviewing-changes/SKILL.md)
  — dimension 5 applies these checks to a diff.
- [`docs/writing-skills.md`](../../../docs/writing-skills.md) — skill
  authoring conventions.
