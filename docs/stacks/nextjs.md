# Stack Binding: nextjs

*Last updated: 2026-09-18*

How a Next.js (App Router, TypeScript) component implements an architecture style and the
[make contract](../make-contract.md). Today this binding covers the
[`ddd-layered`](../styles/ddd-layered.md) style. It applies to a **site**, a deployable Next.js app, and to a
**library**, TypeScript source that sites compile. A project names this binding per component in
`docs/architecture/profile.md` § Components.

---

## Folder mapping (ddd-layered)

```
src/
├── app/                               entry-point layer: routes, layouts, route handlers, metadata
├── contexts/<context>/                bounded context
│   ├── domain/                        exported types, repository ports
│   ├── application/                   use cases: `<verb>-<noun>.use-case.ts`, `export const <verb><Noun> = async`
│   ├── infrastructure/                adapters: CMS queries, mappers, SDK calls
│   └── index.ts                       module entry point
├── components/{atoms,molecules,organisms}/   presentation layer
├── shared/{domain,application,infrastructure}/
└── composition-root.ts                composition root
```

- `middleware.ts`, `sw.ts`, `robots.ts`, `sitemap.ts` and the Next.js config files stay where Next.js requires
  them, and they belong to the entry-point layer.
- Assets (`assets/locales/*.json`, images) sit beside the module that reads them, or in `shared/`.
- Aliases: `@/*` → `src/*`. A site consuming a library adds `@lib/*` → the library's `src/*`. Relative
  imports stay inside their own module.
- A **library** has `shared/` and, only for a concept it owns, `contexts/`. It has no `app/`, `components/`
  or `composition-root.ts`.
- A folder the component has nothing for is left out, never created empty.

## Enforcement of L1–L7

The component carries two checks, modelled on each other across projects:

- an ESLint boundaries config, `eslint.boundaries.mjs`, which exports `CONTEXTS`,
  `CONTEXT_IMPORT_ALLOWLIST` and the pattern builders, run by `lint`;
- an export-structure audit, `check:exports` (`src/scripts/check-export-structure.js`), run first by `test`.

| Rule | Enforcing check |
|---|---|
| L1 | `check:exports`: one exported `type` / `interface` / `class` / component per `.ts(x)` file, named after it; no `.d.ts` file in `src/` (script-style `.d.ts` files make every top-level type global without any keyword), and no `declare global` / `declare namespace` anywhere. Root `env.d.ts` and `next-env.d.ts` are the only allowed declaration files. |
| L2 | `check:exports`: barrel audit. It resolves every import. From outside a module, a target past the module's `index.ts` fails. From inside a module, a target that is the module's own `index.ts` fails. ESLint `no-restricted-imports` deep-path patterns into `@/contexts/*/**`, `@/shared/*/**` and `@lib/**` report the first half in the editor. |
| L3 | ESLint `no-restricted-imports` per context, generated from `CONTEXT_IMPORT_ALLOWLIST` in `eslint.boundaries.mjs` |
| L4 | ESLint `no-restricted-imports` on `src/shared/**`: `@/contexts/*`, `@/contexts/**` |
| L5 | ESLint `no-restricted-imports` overrides. `**/domain/**` bans SDK packages, `next`, `next/*`, `react`, `**/infrastructure/**` and `**/application/**`. `**/application/**` bans `**/infrastructure/**`. |
| L6 | ESLint `no-restricted-imports` override on `src/app/**` and `src/middleware.ts`, which bans `**/infrastructure/**` |
| L7 | `check:exports`: adapter construction (`new …Adapter`, `create…Adapter`) and CMS env reads outside `src/composition-root.ts` fail |

## UI component rules

| # | Rule | Enforced by |
|---|---|---|
| K1 | Components live under `components/{atoms,molecules,organisms}` and nowhere else. A component's level is its level in the project's **Figma design system**, named in `docs/architecture/profile.md`, and its file name is the Figma component name in kebab-case. | `check:exports` for the three level folders. Figma parity (level and name) cannot be checked from code, so the spec that adds or moves a component carries a manual acceptance criterion comparing it with the Figma file. |
| K2 | A level imports only its own and lower levels: organisms → molecules → atoms. | ESLint `no-restricted-imports` overrides per level |
| K3 | Components take data as props and import no `application/` or `infrastructure/`. Only `app/` fetches, by calling a use case. Types from a context entry point are allowed. | ESLint `no-restricted-imports` override on `src/components/**` |
| K4 | Pages and templates are not component levels. The page is the route in `app/`, which composes organisms. | `check:exports` (K1 folder rule) |
| K5 | One entry point per level (`components/<level>/index.ts`) and one exported component per file (L1). | `check:exports` |
| K6 | A library has no `components/` folder and no `.tsx` outside `shared/infrastructure/`, where third-party script loaders live. | `check:exports` in the library |

## Make binding

| Contract target / step | Command |
|---|---|
| `clean` | remove `.next`, deploy-tool output dirs, generated service-worker files (`public/sw.js`, `public/workbox-*.js`, …), downloaded CMS assets, `_dev/tmp`. The shared `_dev/clean.sh` lives in the library when there is one. |
| `format` | `npm run format` → `prettier --write` over `src/` and root configs |
| step 2 format check | `npm run format:check` → `prettier --check` over the same paths |
| `lint` / step 3 | `npm run lint` → `eslint .` |
| `typecheck` / step 4 | `npm run typecheck` → `tsc --noEmit -p <tsconfig>` for each `tsconfig` |
| `test` / step 5 | `npm test` → `check:exports`, then `jest` |
| `run` | `npm run dev` → `next dev`. For a library: `n/a — library`. |
| step 6 production build | site: `npx next build`. Library: none, because consumers compile it. |
| `dup-report` | `node "$(AI_DOTFILES)/scripts/report-duplication.js" --scan-root src` |
| `audit` | `npm audit --json` summarised by severity, exiting 0 |
| `deps-install` | `npm install`. A site's `prepare` script also fetches the library. |
| `deps-update` | the shared `_dev/dependencies/update.sh`, then `make clean` |
| `env-local` | `_dev/local.sh`, which starts the CMS and databases. For a library: `n/a — library`. |
| deploy family | `<platform>-build`: `make clean`, then the platform adapter's build. `<platform>-preview`: its local preview. |

The npm scripts keep `build` for the deploy adapter, which calls it. `make build` calls each step directly,
so its steps stay separate.

## Architecture Profile rows this binding settles

These are copied alongside the style's rows. Placeholders in `<…>` are project facts. The binding settles
only what Next.js itself decides. Error model, immutability and concurrency depend on what the project does
(what it reads, writes and runs), so the project fills them from its own facts.

| Item | Stated style | Source | Open question |
|---|---|---|---|
| Architectural style | **Next.js App Router site** rendering `<static / incremental revalidation / on-request>` pages from `<data source>`, deployed to `<platform>`. A library is a **TypeScript source library** that consuming sites compile. It is never built on its own. | [`stacks/nextjs.md`](nextjs.md); the deploy family in the Makefile; project ADR for the placeholders | — |
| Programming paradigm | **Function components for UI; exported async functions for use cases.** | [`§ Folder mapping`](nextjs.md#folder-mapping-ddd-layered) | Are adapters classes or factory functions returning the port? |
