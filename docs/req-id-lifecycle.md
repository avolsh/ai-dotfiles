# REQ-ID Lifecycle

*Last updated: 2026-05-27*

Lifecycle rules for stable numeric IDs (`REQ-<feature-prefix>-NNN`) inside per-feature requirements baselines: numbering, deletion, supersession, cross-baseline citation, and citation safety.

Stable numeric IDs are optional in requirements baselines. When a baseline
uses them, follow this lifecycle so future CR / IMP / BUG specs can cite
requirements without ambiguity.

## Numbering

- New FR / Invariant IDs MUST use `max(existing) + 1`.
- Authors MUST NOT fill gaps left by deleted, tombstoned, or superseded IDs.
- IDs MUST be unique within the baseline file.
- IDs MUST NOT be reused after deletion or supersession.

## Deletion

When deleting an ID, leave a one-line tombstone in the same section:

```markdown
- ~~REQ-PCE-005~~ deleted — Why: replaced by source-of-truth copy in `REQ-PCE-012`.
```

The tombstone preserves citation history. Do not point new work at a
deleted ID; cite the replacement ID or a section anchor instead.

## Supersession

When one ID replaces another, keep the old ID inline and name the
replacement:

```markdown
- ~~REQ-PCE-005~~ superseded by REQ-PCE-012 — Why: breadcrumb ownership moved to catalog enrichment.
```

The replacement ID MUST carry the current requirement text. The old ID
MUST stay tombstoned and MUST NOT be reused.

## Cross-Baseline Citations

Cross-baseline citations are allowed when a requirement in one baseline
depends on a requirement from another baseline.

To cite another baseline:

1. Name the foreign baseline in the header `Depends on baselines` row.
2. Name the foreign REQ-ID in the FR / Invariant text.
3. Keep the local requirement independently readable.

Example:

```markdown
| Depends on baselines | shared-primitives.md |

- REQ-PAIC-004 MUST persist AI batch metadata using the lifecycle defined by `REQ-SP-001`.
```

Use a path-anchor citation when the foreign baseline has no numeric ID.

## Citation Safety

- Specs MAY cite numeric IDs or path anchors in `domain-refs:`.
- Specs MUST NOT cite deleted IDs except when explaining supersession or
  migration history.
- Specs SHOULD cite the replacement ID after supersession.
- Baseline authors SHOULD add numeric IDs when the feature is expected to
  be cited by future specs.
