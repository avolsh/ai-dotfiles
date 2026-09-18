# Architecture Style: ddd-layered

*Last updated: 2026-09-18*

The style organises code as bounded contexts, and each context is layered into domain, application and
infrastructure. The style names no language or tool. A stack binding under [`../stacks/`](../stacks/) maps
each concept to folders and each rule to the check that enforces it. A project picks the style per
component in `docs/architecture/profile.md` § Components. How the component is driven through `make` is in
[`../make-contract.md`](../make-contract.md).

---

## Concepts

| Concept | What it is |
|---|---|
| **Bounded context** | One model with its own language, usually one aggregate family or one CMS collection family. Named in singular kebab-case. A component has **at least one**; a small site still has one (for example `page`). A second appears only when a concept has its own model and its own storage. |
| **Domain layer** | Types, value rules and repository ports of a context, written in domain terms only. |
| **Application layer** | Use cases: one operation each, taking ports as dependencies and returning domain types. |
| **Infrastructure layer** | Adapters that implement ports against an external system (database, CMS, HTTP API, file store), plus their mappers and queries. |
| **Shared** | Cross-cutting code used by more than one context, with the same three-layer split. It is not a context. |
| **Composition root** | The single place that reads adapter configuration, constructs adapters and binds use cases to them. |
| **Entry-point layer** | What the outside world calls: routes and pages, HTTP handlers, CLI commands, pipeline steps, jobs. |
| **Presentation layer** *(optional)* | UI components. Its rules come from the stack binding. |
| **Module entry point** | The one public surface of a module (a context, a shared module, a component group): an index file, a package API or an exported facade, depending on the stack. |

## Dependency rules

Rule IDs are stable. A stack binding names exactly one enforcing check per rule, and specs and reviews cite
the IDs.

| # | Rule |
|---|---|
| L1 | **Explicit types, one per source unit.** A public type lives in its own source unit, named after it, where the stack allows it; the binding states the unit. No ambient or global type declarations: every type is imported where it is used. |
| L2 | **Module entry points are the only external entry.** Code outside a module depends only on its entry point, never on a path inside it. Inside a module, code never imports its own entry point. |
| L3 | **No cross-context dependencies.** A context reaches another only through `shared`. Each exception is an allowlist entry recorded in `docs/architecture/module-map.md` as a design decision, and a new component starts with an empty allowlist. |
| L4 | **`shared` depends on no context.** |
| L5 | **The domain depends on nothing outside the domain.** The domain layer imports no SDK, framework, infrastructure or application code. The application layer imports no infrastructure. |
| L6 | **Entry points call use cases only.** The entry-point layer depends on the composition root, application use cases, domain types and presentation. It never depends on infrastructure or an adapter directly. |
| L7 | **Composition in one place.** Only the composition root constructs adapters and reads adapter configuration. |

## Shared-library components

A component whose job is to be consumed by other components or repositories, rather than run, follows the
style with these additions:

- **Holds infrastructure and tooling only.** That covers clients for external systems and their generic
  types, asset and image loaders, i18n and metadata helpers, loaders for third-party scripts, and shared dev
  scripts. Its code sits mostly in `shared/`. It has contexts only for a domain concept it genuinely owns.
- **No composition root and no entry-point layer.** The consumer wires it.
- **No design-system UI when its consumers have separate design systems.** A third-party script loader
  renders no design-system UI, so it counts as infrastructure. A consumer-specific model, such as one
  site's page types, lives in that consumer.
- **Consumed only through module entry points** (L2). The consuming project records how it fetches the
  library: package, submodule or clone.
- **Coordinated merge.** When consumers build against a moving branch of the library, a change to a library
  entry point merges in the same release as the consumer changes. The library's
  `docs/architecture/module-map.md` publishes the old → new entry-point map before any consumer switches.

## Architecture Profile rows this style settles

A project copies these rows into its `docs/architecture/profile.md` for each component using the style. The
stack binding settles or refines the others.

| Item | Stated style | Source | Open question |
|---|---|---|---|
| Domain modelling | **DDD, tactical-light.** At least one bounded context per component. The domain layer holds types and repository ports in domain terms only. No entity class hierarchy is required until a rule needs behaviour. | [`styles/ddd-layered.md § Concepts`](ddd-layered.md#concepts); L3, L5 | When a concept gains behaviour, does it become an entity type with methods, or functions over a type? |
| Code organisation | **Bounded-context modules, each layered** domain → application → infrastructure, with cross-cutting code in `shared`, one composition root, and an entry-point layer that calls use cases only. Types are explicit and module entry points are the only external entry. | [`styles/ddd-layered.md`](ddd-layered.md); L1–L7 | — |
| Integration style | **Through ports.** Every external system is reached by an infrastructure adapter implementing a domain port, wired in the composition root. The protocol (sync call, batch, event) is a project fact. | L5, L7 | Project fact: which systems, which protocol, and who owns each contract? |

Programming paradigm, error model, immutability and concurrency are left to the stack binding or the
project.
