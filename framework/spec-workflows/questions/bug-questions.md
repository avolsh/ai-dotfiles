# BUG Standard Questions

*Last updated: 2026-04-20*

During the Specify stage, the agent asks up to **10 questions** from this
list plus any bug-specific ones. The human answers before requirements
are written.

## How to use

1. Pick the questions that are relevant to this bug — not all 10 always fire.
2. Reproduction (Q1) is almost always first — you cannot fix what you
   cannot reproduce.
3. **Q2 (Multi-defect) is mandatory on every round.** It drives the
   Split check in [`splitting-rules.md § 2`](../../skills/writing-specs/references/splitting-rules.md) —
   independent defects become separate BUG specs.
4. If the user has already provided reproduction steps, confirm them
   rather than re-asking.

## Standard questions (ask ≤10 per round)

1. **Reproduction:** What are the exact steps to reproduce the bug?
   Command, input, expected vs actual output.
2. **Multi-defect:** Are there multiple independent defects in this
   report, or one defect with multiple symptoms? Independent defects
   MUST become separate BUG specs.
3. **Environment:** Which environment does this occur in? (local, CI,
   production). Any specific config (provider settings, batch sizes,
   feature flags)?
4. **Frequency:** Does this always happen or is it intermittent? If
   intermittent, what percentage of runs?
5. **First occurrence:** When did this start? Was it introduced by a
   specific spec, PR, or code change?
6. **Scope:** Is this limited to one entity/collection/page, or does it
   affect multiple?
7. **Error output:** What error messages, stack traces, or incorrect
   data are observed? Paste verbatim.
8. **Copied patterns:** Could the same bug exist in other similar code
   paths (e.g., duplicated processing logic, sibling components)?
9. **Impact:** What is the data or user impact? Is existing data
   corrupted? How many users / items affected?
10. **Workaround:** Is there a temporary workaround? If yes, is it in
    use right now?
11. **Related code:** Which files or bounded context does the bug
    likely live in?

## Situational questions (optional, use as needed)

- **Data state:** Can you share a sample document / record / request that
  shows the problem?
- **Processing step:** Which step produces the incorrect output?
- **Regression:** Was this working before? If so, what changed?
- **Log excerpt:** Can you share the relevant log lines (with timestamps)?
- **Data repair:** Does existing data need to be re-processed after the
  fix, or does the bug only affect future runs?

## Anti-patterns

- **Do not** skip the reproduction question, even if the bug seems
  obvious from the description.
- **Do not** start writing a fix before the reproduction is confirmed
  (Task 1 is always "Reproduce & write failing test").
- **Do not** propose root causes in the question round — ask questions
  that help you find the cause, don't assume it.
