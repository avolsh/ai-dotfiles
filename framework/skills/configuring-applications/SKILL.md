---
name: "configuring-applications"
description: "How application configuration is layered, typed, and kept safe — precedence between defaults, env vars and a runtime settings store; which settings may live in the store and which may not; dead config keys; and keeping secret-bearing values out of logs. Triggers: config, configuration, settings, env vars, feature flag, admin settings screen, secrets in logs."
---

# Configuring Applications

*Last updated: 2026-08-13*

Configuration is where a system's behaviour is decided without changing
its code — which is exactly why an unstated configuration model produces
settings nobody reads, screens that enforce nothing, and credentials in
stdout. These are the rules that keep a config surface honest.

## When to use

- Adding a configuration key, environment variable, or feature flag.
- Building or changing an admin/settings screen backed by a runtime store.
- Deciding where a setting belongs: code default, env var, or database.
- Reviewing config-shaped code — casts on a settings document, a value
  read straight into a log line, a key you cannot find a reader for.
- Handling credentials, API keys, or tokens that arrive as configuration.

## The layered model

Configuration resolves through exactly three layers, in this precedence:

**code defaults → environment → runtime store**

Each layer overrides the one before it, and the merge happens in **one
declared place** — a single module that produces the effective config.
Nothing downstream re-reads `process.env`, re-queries the settings
collection, or applies its own fallback: a second merge site is a second
source of truth, and the two drift silently because both "work".

## Bootstrap vs operational

Split settings by what they are needed *for*, not by how convenient they
are to edit:

- **Bootstrap** — everything required to start the process and reach its
  dependencies: connection strings, credentials, API keys, the address of
  the settings store itself. These come from the environment and **never**
  live in the runtime store. A setting needed to reach the store cannot be
  read from the store, and a secret in the store is a secret in a backup,
  in a replica, and on every screen that renders it.
- **Operational** — tuning a running system does without a redeploy:
  thresholds, batch sizes, toggles, copy. These may live in the store and
  may be exposed to an admin surface.

A secret is bootstrap by definition. There is no operational exception.

## One validated accessor

The effective config is read through a single typed accessor that
**validates at the boundary** — parse the raw document once, against a
schema, and hand the rest of the system a typed value.

An `as` cast is not validation: it silences the compiler about a shape
nobody checked, and every cast on a config document is a runtime failure
waiting for the one deployment where the field is absent. If a config
document needs repeated casts to be usable, the accessor is missing.

## A key with no readers is a defect

Every configuration key MUST have at least one reader. A key nothing
reads is not a provision for later — it is a defect with a UI:

- It is indistinguishable from a working setting, so operators change it
  and expect an effect.
- An admin screen that writes it promises control the system does not
  implement.
- It survives review precisely because it looks like configuration.

Provide the key when the code that reads it lands, not before. When
removing a reader, remove the key, its schema entry, and its admin
control in the same change.

## Secrets never reach a log

A value read from a secret-bearing configuration field MUST NOT be
written to a log, printed to stdout, included in an error message, or
sent to telemetry — including from a debug branch that "only runs
locally", behind a flag the committed env template ships enabled.

Redaction is the **logger's** responsibility, not each call site's: the
logger knows the field names and shapes that carry secrets and masks them
centrally. A rule that every call site must remember is a rule that holds
until the first debugging session at 2am.

## References

- [`framework/boundaries.md`](../../boundaries.md) — § Never do #1: never
  commit `.env`, `.env.local`, `.dev.vars`, or hardcoded secrets.
- [`framework/skills/reviewing-changes/SKILL.md`](../reviewing-changes/SKILL.md)
  — dimension 5 applies these checks to a diff.
- [`docs/writing-skills.md`](../../../docs/writing-skills.md) — skill
  authoring conventions.
