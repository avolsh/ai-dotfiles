# Rule Canonical Map

*Last updated: 2026-08-13*

> **Machine-read by `scripts/lint-rules.py` — not human-maintained prose.**
> Parser contract: a rule section starts with `### R<N> —`; it must contain a
> `**Canonical location**` table row with a backticked `path § …` value, and
> one or more tracked phrases formatted `*"…"*`. Sections missing either are
> ignored by the linter. Any verbatim appearance of a tracked phrase outside
> its canonical file fails `make lint-rules`.
>
> When a canonical rule's wording changes, update its phrase entry here in the
> same commit. The audit narrative that produced this inventory is archived at
> [`docs/specs/archived/artifacts/IMP-20260514-rule-map-narrative.md`](specs/archived/artifacts/IMP-20260514-rule-map-narrative.md).

## Rule inventory

### R1 — Never skip the Specify stage

| | |
|---|---|
| **Canonical location** | `framework/boundaries.md § Never do #2` |

Verbatim phrases observed:
- boundaries (post-IMP-20260514-trivial-lane T3): *"Never skip the Specify stage — even a trivial bug needs confirmed understanding via the question round. The Trivial lane"*
- boundaries (pre-IMP-20260514-trivial-lane T3 — kept tracked to catch reverts): *"Never skip the Specify stage — even a trivial bug needs confirmed understanding via the question round."*
- spec-lifecycle (pre-D3): *"Never skip the Specify stage — even for a one-line bug. Confirm understanding with the ≤10 questions from the relevant question list."*
- create-spec.prompt (pre-D3): *"Never skip the question round — even trivial CRs get one."*

### R2 — Never write `## Tasks` table while status is `specify`

| | |
|---|---|
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #2` |

Verbatim phrases observed:
- boundaries / spec-lifecycle: *"Never write a `## Tasks` table while `status` is `specify`."*
- create-spec.prompt: *"Never write `## Tasks` here — that belongs to Plan."*
- visualize-spec.prompt: *"Never write `## Tasks` here."*

### R3 — Never flip status without explicit human approval

| | |
|---|---|
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #3, #4, #5` |

Verbatim phrases observed:
- boundaries: *"Never flip a spec's status without the preceding human gate."*
- spec-lifecycle #3: *"Never flip to `plan` without explicit human approval of requirements."*
- spec-lifecycle #4: *"Never flip to `in-progress` without explicit human approval of the plan."*
- spec-lifecycle #5: *"Never flip to `done` while any acceptance criterion lacks documented evidence."*

### R4 — Always update `*Last updated: YYYY-MM-DD*` stamp

| | |
|---|---|
| **Canonical location** | `framework/boundaries.md § Always do #10` |

Verbatim phrases observed:
- boundaries: *"Update `*Last updated: YYYY-MM-DD*` on every modified doc."*
- spec-lifecycle: *"Always update `*Last updated: YYYY-MM-DD*` when changing the file."*

### R5 — Always update task row status in-place

| | |
|---|---|
| **Canonical location** | `framework/boundaries.md § Always do #11` |

Verbatim phrases observed:
- boundaries: *"Update task row status in-place as each task completes."*
- spec-lifecycle: *"Always update the task row status in-place as tasks progress."*

### R6 — Split check is mandatory in Specify, before Visualize, before the gate

| | |
|---|---|
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #9` |

Verbatim phrases observed:
- spec-lifecycle #9: *"The Split check is a mandatory sub-step of Specify — complete it before Visualize..."*
- spec-lifecycle #11: *"Never request the requirements gate without completing the Split check; record the outcome under `## Split Decision` first."*
- spec-lifecycle #12: *"Never bundle independently-testable features into one spec — split per splitting-rules.md § 2."*
- create-spec.prompt: *"Never request the gate without `## Split Decision` filled in every spec (this + siblings)."*
- bug-triage.prompt: *"Never request the gate without `## Split Decision` filled in every spec."*

### R7 — Spec with unmet `depends-on:` MUST stay at `specify`

| | |
|---|---|
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #10` |

Verbatim phrases observed:
- spec-lifecycle: *"A spec with unmet `depends-on:` MUST stay at `specify` (never flip to `plan`) until all listed siblings reach `done`."*
- plan-spec.prompt: *"Never advance to `plan` while `depends-on:` siblings are unmet."*

### R8 — Visualize stays at `status: specify`

| | |
|---|---|
| **Canonical location** | `framework/spec-workflows/spec-lifecycle.md § Rules #8` |

Verbatim phrases observed:
- spec-lifecycle #8: *"Visualize is a sub-step of Specify (not a status). When triggered, complete it before asking for the requirements gate."*
- visualize-spec.prompt: *"Status stays at `specify` — Visualize is not a separate status."*

### R11 — Name the shared cause before the third copy

| | |
|---|---|
| **Canonical location** | `framework/boundaries.md § Always do #16` |

Verbatim phrases observed:
- boundaries #16 (heading clause): *"Name the shared cause before the third copy."*
- boundaries #16 (rule statement): *"in more than two places, stop and name the shared cause before applying it"*
- boundaries #16 (outcome clause): *"The outcome may be a shared fix or an accepted duplication"*

### R12 — Classify a caught failure, never settle it

| | |
|---|---|
| **Canonical location** | `framework/boundaries.md § Always do #17` |

Verbatim phrases observed:
- boundaries #17 (heading clause): *"Classify a caught failure — never settle it."*
- boundaries #17 (rule statement): *"is recorded as retryable, permanent, or valid-empty, or it propagates"*
- boundaries #17 (outcome clause): *"completed state, a checkpoint, or an empty result, each of which removes the record"*
