## Personal identity rules

These rules apply in any repository when the `personal` profile is active.
They are cross-cutting personal preferences, not workspace- or project-specific rules.

- When generating spec IDs, use the `YYYY-MM-DD` format matching today's actual date.
- Preferred commit message style: `[agent] <type>: <description>` (per agent-protocol conventions).
- When multiple approaches are equally valid, prefer the one with fewer moving parts.
- Never add unrequested comments, logging, or error handling for scenarios that cannot occur.
- Default model for new AI features: `claude-sonnet-4-6` unless the task explicitly requires a different tier.

## Personal preferences

<!-- Identity-level preferences appended to every rendered instruction file
     by ai-profile-init.sh. No top-level title or YAML front-matter. -->

- Respond in English.
- Prefer terse, direct answers. Avoid filler phrases and unnecessary repetition.
- When referencing code, include file paths and line numbers where relevant.
- Use GitHub-flavored markdown formatting in responses.
- Default output language for generated code comments: English.
