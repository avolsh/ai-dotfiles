# framework/skills/ — skill catalog

*Last updated: 2026-08-13*

On-demand knowledge modules the AI loads when relevant (progressive
disclosure via each skill's `SKILL.md`). Two kinds live here:

1. **System-scope methodology skills** — authored for this framework.
2. **Tech-stack skills** — cherry-picked from the `upstream/` quarry and
   vendored (copied, never symlinked — see
   [`../upstream/README.md`](../upstream/README.md)).

## System-scope skills

| Skill | What it teaches |
|---|---|
| `writing-specs` | Writing specs, asking questions, planning/splitting tasks |
| `reviewing-changes` | Spec-conformance review checklist |
| `model-selection` | Which model tier (fast/default/deep) to use per task |
| `bootstrapping-project` | Setting up a new project with the framework |
| `writing-docs` | Doc conventions, glossary format, freshness rules |
| `configuring-applications` | Config layering (defaults → env → store), bootstrap vs operational, one validated accessor, dead keys, secrets never reaching a log |
| `avoiding-duplication` | Axis-of-variation test, single-sourced vocabularies, mapper round-trips, when a copy is accepted |

## Tech-stack skills (vendored)

Source: `wshobson/agents` (`../upstream/wshobson-agents` @ `cf6059d`).
Re-sync provenance when the submodule SHA changes.

| Dir | Skill `name` | Stack | Use it for |
|---|---|---|---|
| `typescript-advanced-types` | `typescript-advanced-types` | TypeScript | Generics, conditional/mapped types, template literals, utility types |
| `modern-javascript-patterns` | `modern-javascript-patterns` | TS / JS | ES6+, async/await, modules, functional patterns |
| `javascript-testing-patterns` | `javascript-testing-patterns` | TS / JS | Jest/Vitest/Testing Library, mocking, TDD/BDD |
| `nodejs-backend-patterns` | `nodejs-backend-patterns` | TS / Node | Express/Fastify services, middleware, auth, REST/GraphQL backends |
| `go-concurrency-patterns` | `go-concurrency-patterns` | Go | Goroutines, channels, sync primitives, context, race debugging |
| `api-design-principles` | `api-design-principles` | REST / GraphQL | API design + review standards (incl. GraphQL schema design refs) |
| `microservices-patterns` | `microservices-patterns` | REST / services | Service boundaries, event-driven comms, resilience |
| `postgresql` | `postgresql-table-design` | Postgres | Schema design/review: types, indexing, constraints, performance |
| `k8s-manifest-generator` | `k8s-manifest-generator` | Kubernetes | Production-ready Deployment/Service/ConfigMap/Secret manifests |
| `helm-chart-scaffolding` | `helm-chart-scaffolding` | Kubernetes | Helm chart structure, templating, packaging |
| `gitops-workflow` | `gitops-workflow` | Kubernetes | ArgoCD/Flux declarative deploys, continuous reconciliation |
| `k8s-security-policies` | `k8s-security-policies` | Kubernetes | NetworkPolicy, PodSecurity, RBAC |
| `terraform-module-library` | `terraform-module-library` | Cloud infra | Reusable Terraform modules (AWS/Azure/GCP/OCI) |
| `istio-traffic-management` | `istio-traffic-management` | Cloud infra | Mesh routing, load balancing, circuit breakers, canaries |
| `service-mesh-observability` | `service-mesh-observability` | Cloud infra | Distributed tracing, metrics, SLOs for mesh traffic |
| `cost-optimization` | `cost-optimization` | Cloud infra | Rightsizing, tagging, reserved instances, spend analysis |

## Cross-cutting skills (vendored)

Stack-agnostic disciplines that complement the spec lifecycle without
replacing it. Sources: `obra/superpowers` (`../upstream/superpowers` @
`6fd4507`) and `anthropics/skills` (`../upstream/anthropic-skills` @
`5754626`).

| Dir | Skill `name` | Source | Use it for |
|---|---|---|---|
| `frontend-design` | `frontend-design` | anthropic | UI/visual implementation quality (layout, typography, CSS) — pairs with the Figma flow |
| `test-driven-development` | `test-driven-development` | superpowers | Test-first discipline for any feature/bugfix |
| `systematic-debugging` | `systematic-debugging` | superpowers | Root-cause method for bugs/test failures before proposing fixes |
| `using-git-worktrees` | `using-git-worktrees` | superpowers | Isolated workspace for feature work / plan execution |

## Coverage notes (not vendored)

| Item | Status |
|---|---|
| **Figma** | Provided by the Figma MCP server as `/figma-*` skills (`figma-use`, `figma-generate-design`, `figma-code-connect`, …). The `upstream/mcp-server-guide` submodule is the source of record. No copy needed. |
| **Cloudflare** | Only source is the official `cloudflare` connector plugin (`workers-best-practices`, `wrangler`, `durable-objects`, …), which currently lives in an ephemeral `.tmp/` plugin cache. Install the plugin properly rather than vendoring from `.tmp/`. |
| **Java** | No SKILL.md upstream — only a `java-pro` sub-agent in `wshobson-agents/plugins/jvm-languages/agents/`. Author a skill with `skill-creator` if needed. |
| **MongoDB** | No dedicated skill or agent upstream. Lean on `postgresql` + `microservices-patterns` for now, or author one. |
| **superpowers `writing-plans` / `executing-plans`** | Deliberately **not** vendored — they duplicate the framework's `writing-specs` + spec lifecycle, which is the canonical planning/execution workflow (see `../upstream/README.md`). |
| **superpowers `requesting-code-review`** | Deliberately **not** vendored — overlaps `reviewing-changes` + the bespoke reviewer sub-agent. |
| **superpowers `verification-before-completion`** | Deliberately **not** vendored — overlaps `agent-protocol`'s completion checklists. |

## Re-syncing a vendored skill

```sh
# from ai-dotfiles/ — <repo> is one of: wshobson-agents, superpowers, anthropic-skills
git submodule update --remote framework/upstream/<repo>
git diff --submodule framework/upstream/<repo>   # review before adopting
cp -R framework/upstream/<repo>/.../skills/<skill> framework/skills/
```

Vendored copies are intentional snapshots — an upstream update must not
silently change agent behaviour (`framework/boundaries.md § Ask first`).
