# Writing Skills

*Last updated: 2026-05-14*

Authoring conventions for skills under `framework/skills/` (system scope) and `<project>/.github/copilot/skills/` (project scope). Covers the canonical slimmed-skill shape, optional advanced sections, and anti-patterns.

---

## Canonical shape

Every skill is a single `SKILL.md` file with three parts:

1. **YAML frontmatter** — `name` and `description`. The `description` is what the harness shows to decide when to load the skill, so include trigger keywords users might say.
2. **`## When to use`** — bullets listing trigger conditions in plain user language.
3. **`## References`** — link list pointing at the deeper material the skill front-loads (specs, runbooks, schemas, upstream docs).

The starter at `framework/templates/system/_skill-template/SKILL.md` carries this shape; new skills inherit it by copy.

### Frontmatter example

```yaml
---
name: "writing-specs"
description: "Spec lifecycle — creating CRs, BUGs, IMPs, planning, closure. Trigger phrases: 'create spec', 'plan', 'close spec'."
---
```

---

## Optional advanced sections

Add these only when the skill genuinely needs them. Skip otherwise — keep skill bodies short so the agent loads them cheaply.

| Section | When to add |
|---|---|
| `## Before Starting` | The skill must verify environment, read prior context, or check for in-flight state before acting. |
| `## Procedure` | The skill is a multi-step runbook with order-dependent steps. Numbered list. |
| `## Proactive Triggers` | The skill should surface advice without being asked (e.g. "when you see X in the code, suggest Y"). Format: **Condition** → action. |
| `## Output Artifacts` | The skill produces named deliverables and authors want to pin user-phrase → artifact mapping. Use a table. |
| `## Anti-Patterns` | The skill has been historically misused in ways the description alone can't prevent. Use ❌ bullets. |
| `## Communication` | The skill changes how the agent reports findings (confidence tags, bottom-line-first, etc.). |
| `## Related Skills` | The skill is easily confused with a sibling. Format: **skill-name** — when to use; **NOT** for X. |

---

## Anti-patterns

- ❌ Inlining a runbook the harness will never load. If the content is long, link from `## References` and let the agent fetch on demand.
- ❌ Restating boundaries. `framework/boundaries.md` is the source of truth; skills should reference, not duplicate.
- ❌ Procedural skills with no triggers. If `## When to use` is empty or vague, the harness won't surface the skill — write specific user phrases.
- ❌ Skipping the date stamp. Every skill carries `*Last updated: YYYY-MM-DD*` under the H1.

---

## Authoring checklist

1. Copy `framework/templates/system/_skill-template/SKILL.md`.
2. Fill in `name` and `description`; include 2–4 user-phrase triggers in the description.
3. Write `## When to use` with concrete trigger bullets.
4. Populate `## References` with the existing canonical docs the skill should load.
5. Add optional sections only if the table above justifies them.
6. Update `*Last updated:*`.

---

## Related

- [Writing Docs](writing-docs.md) — general doc conventions (freshness, markdown rules, link hygiene).
- [`framework/templates/system/_skill-template/SKILL.md`](../framework/templates/system/_skill-template/SKILL.md) — the starter.
- [`framework/skills/`](../framework/skills/) — production skills to read as examples.
