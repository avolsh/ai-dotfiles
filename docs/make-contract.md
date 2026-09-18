# Make Contract

*Last updated: 2026-09-18*

Every project that adopts this contract uses the same `make` target names for the same actions, whatever its
language. The contract says *what* each target does. A stack binding under [`stacks/`](stacks/) says which
command does it in that stack. How the code is organised is an architecture style under [`styles/`](styles/).
A project names its stack and style per component in `docs/architecture/profile.md` (§ Components). The
project scaffold [`framework/templates/project/Makefile`](../framework/templates/project/Makefile) carries
both tiers as stubs.

---

## Make is the facade

`make` is the single entry point of every repository. People, CI and agents type `make <target>` without
first learning what the repository is built with. The stack's own tools sit behind it: compilers, package
managers, build tools and shell scripts. The stack binding names the command each target runs. A target that
needs no build tool, such as `sync-agents` or `docs-check`, calls a script directly.

The facade does not vary per repository. A second entry point (another task runner) would bring back
per-repository discovery and a second conformance check. If a workspace ever needs one, the target names and
semantics below move to a runner-neutral task contract, and each runner gets its own binding. Until then,
the contract is `make`. The trigger is concrete: a team that must build natively on Windows without WSL or
Git Bash ([§ Platform requirements](#platform-requirements)).

## Platform requirements

| Needs | Why |
|---|---|
| GNU make ≥ 3.81 | 3.81 is what macOS ships. No feature newer than it: no `.ONESHELL`, `$(file …)` or `--output-sync`. |
| A POSIX shell (`/bin/sh`) | Every recipe and `_dev/*.sh` is POSIX shell. The Makefile sets `SHELL := /bin/sh`, so the user's own shell does not matter. |
| `python3` | Framework checks (`quality-gates-check`, the conformance check). |
| `node` | Code tier only: `dup-report` runs the framework's `report-duplication.js`. |
| The stack's own tools | Named by the stack binding. |

| OS | Support |
|---|---|
| Linux | Native. This is also what CI runs. |
| macOS | Native, with GNU make 3.81 from the Xcode command-line tools. |
| Windows | Supported through **WSL2** (recommended: a full Linux) or **Git Bash** with GNU make from `winget` / `scoop`. Native PowerShell or `cmd` without a POSIX shell is not supported. |

Recipes and `_dev/*.sh` are portable POSIX:

- no flags that exist only in BSD or only in GNU tools, such as `sed -i ''` (BSD) or `sed -i` without a suffix
  (GNU) — write to a temp file and move it instead;
- no bash-only syntax under `#!/bin/sh`;
- paths use `/`.

The repository's `.gitattributes` keeps `Makefile`, `*.mk` and `*.sh` at `eol=lf`. Otherwise a Windows
checkout converts them to CRLF and they fail with `/bin/sh^M: bad interpreter`.

## Tiers

| Tier | Applies to | Targets |
|---|---|---|
| **core** | every repository, including docs-only and infrastructure repos | `help`, `clean`, `build`, `docs-check`, `quality-gates-check`, `sync-agents`, `sync-agents-check` |
| **code** | every repository with source code | `format`, `lint`, `typecheck`, `test`, `run`, `dup-report`, `audit`, `deps-install`, `deps-update`, `env-local` |

A repository defines every target of each tier it declares. A target in a declared tier that has no meaning
for the project still exists: it prints one line, `<target>: n/a — <reason>`, and exits 0. An example is
`run` in a library. The contract is checked by name. A missing target makes muscle memory and agent
instructions fail differently in each repo.

## Declarations

A Makefile declares, near the top:

```make
# Tiers this repository implements: core, or core code.
MAKE_CONTRACT_TIERS := core code
# Project-specific targets this repository promises to keep (e.g. its deploy targets). Optional.
MAKE_CONTRACT_REQUIRED :=
# Names retired by renaming them onto a contract target. Optional.
MAKE_CONTRACT_RETIRED :=
```

The conformance check reads all three.

## Core tier

| Target | Semantics |
|---|---|
| `help` | Lists the targets this Makefile defines, one line each. It is the first target in the file, so a bare `make` runs it. |
| `clean` | Removes build output and generated files. Never touches installed dependencies, sources or `.env*`. Idempotent. In a docs-only repo: generated reports. |
| `build` | The verification sequence (below). Stops at the first failing step and names it. Never rewrites the tree. |
| `docs-check` | Every documentation drift check the repository owns, including `quality-gates-check`, `sync-agents-check` and the [conformance check](#conformance-check). Ends with a one-line summary. |
| `quality-gates-check` | `$(AI_DOTFILES)/scripts/validate-quality-gates.py .`: checks the `_canonical.md` Build and Run table against the Kind / Mode contract. |
| `sync-agents` | Regenerates `CLAUDE.md`, `AGENTS.md` and `.github/copilot-instructions.md` from `_canonical.md`. |
| `sync-agents-check` | Fails when the rendered agent files have drifted from `_canonical.md`. |

## Code tier

| Target | Semantics |
|---|---|
| `format` | Rewrites sources with the stack's formatter. The developer command. Never a step of `build`. |
| `lint` | Static analysis over the whole repository, including the architecture style's dependency rules. Reports and never rewrites. |
| `typecheck` | Compiles or type-checks every module of the repository without producing release artifacts. |
| `test` | Runs every unit suite plus the style's structure audits. Suites that need live services stay outside it as `test-<suite>`. |
| `run` | Starts the component's app or service locally in dev mode. |
| `dup-report` | Duplicated-code report through `$(AI_DOTFILES)/scripts/report-duplication.js`. A report: exits 0 whatever it finds, and 2 only if the scan did not run. |
| `audit` | Dependency vulnerability report by severity. A report: exits 0 whatever it finds, and 2 only if the audit did not run. |
| `deps-install` | Installs dependencies from the lockfile, including any source library the component consumes. |
| `deps-update` | Bumps dependencies to their latest versions, then runs `make clean`. |
| `env-local` | Starts the local backing services the component needs, such as databases or a CMS. |

## `build` step order

`build` runs these numbered gate steps in this order. The stack binding names the command for each. The same
steps appear, numbered, in the project's `_canonical.md` § Build and Run table.

| # | Step | Tier |
|---|---|---|
| — | `make clean` (un-numbered pre-step, optional) | core |
| 1 | `docs-check` | core |
| 2 | format check (reports, never rewrites) | code |
| 3 | `lint` | code |
| 4 | `typecheck` | code |
| 5 | `test` | code |
| 6 | production build, when the component ships a deployable artifact | code |

A core-only repository runs step 1 alone. `dup-report` and `audit` are `report` rows in the Build and Run
table, never `build` steps. `format` is never a step.

## Target families

Project-specific targets that recur across projects follow a family pattern. None is required by name. A
repository that promises a member lists it in `MAKE_CONTRACT_REQUIRED`.

| Family | Pattern | Semantics |
|---|---|---|
| Deploy | `<platform>-build`, `<platform>-preview`, `<platform>-deploy`, `env-<environment>-update` | platform production build (runs `make clean` first); local preview of that build; deploy; apply infrastructure for a named environment |
| Pipeline step | `run-init`, `run-step-<N>[<letter>][-<qualifier>]` | one batch step of a staged pipeline |
| Test suite | `test-<suite>` | a suite kept out of `test`, e.g. one that needs live services |
| Docs sub-check | `<subject>-check` | one check `docs-check` depends on, also runnable alone |
| Operational | `<verb>-<object>` with a `-report` twin when destructive | migrations, repairs, backfills, evaluations |

## Naming rule

A project-specific target is any name that is not in a tier. It follows these rules:

1. Lowercase kebab-case. No `:`, because colon names belong to package-manager scripts.
2. The name is `<verb>-<object>[-<qualifier>]`, or follows a family pattern above.
3. It never reuses or shadows a tier target's name with another meaning. It never adds a second name for a
   tier action: `clear` or `purge` beside `clean`, `dev`, `start`, `serve` or `admin` beside `run`, or
   `check` beside `build`.
4. A report that exits 0 whatever it finds is `<subject>-report` or `audit-<subject>`. A step or app launched
   by hand is `run-<thing>`. A local environment action is `env-<thing>`, and a dependency action is
   `deps-<thing>`.
5. A target that writes shared data destructively has a `-report` twin that prints what it would change and
   writes nothing (`repair-<x>-report` / `repair-<x>`).
6. Each project-specific target has a one-line comment above it: what it does and, where possible, which spec
   introduced it.

## Multiple components

A repository holding more than one component (for example a service and a web app, each with its own
build) satisfies the contract at its root:

- The root Makefile defines every target of its declared tiers.
- Each code-tier target and `build` delegates to every component in a fixed order,
  `$(MAKE) -C <component-path> <target>`. It stops at the first failure and names the component.
- A component may keep its own Makefile following the same contract. If it does, the conformance check runs
  on the root and on each component Makefile.
- `run` and `env-local` may take `COMPONENT=<path>` and default to the first component.
- Each component is one row of the project's `docs/architecture/profile.md` § Components.

## Conformance check

*Implemented by [`scripts/check-make-contract.py`](../scripts/check-make-contract.py); this section is the
contract that script meets.*

- **Location:** `$(AI_DOTFILES)/scripts/check-make-contract.py`. One shared script that no repo copies.
- **Invocation:** `python3 "$(AI_DOTFILES)/scripts/check-make-contract.py" .` as a recipe line of
  `docs-check`, guarded like `quality-gates-check`: if the framework is missing, it prints a message naming
  `AI_DOTFILES` and exits 1. It is not a separate target, so the tiers stay as listed.
- **Recipe reading:** recipes are read as the shell gets them: continuation lines joined, quotes respected, and
  only the command word of each command (after `if` / `then` / `do`, `(`, `cd <dir> &&`) counts as a
  call. A `make` inside an `echo` is text, not a call. A `cd <dir>` moves the rest of the line into
  `<dir>` until its subshell closes; `-C <dir>` does the same for one call. Directories named through a
  shell variable (`$$d` in a loop) are not followed.
- **Target discovery:** from `make -pRrq -f Makefile : 2>/dev/null`, the database make itself builds, so
  targets defined through includes or pattern rules count. It never parses the Makefile text. With
  components, it repeats this for each directory a recipe calls into (`$(MAKE) -C <dir>` or
  `cd <dir> && $(MAKE)`), from the root and from each component in turn, and checks every Makefile it
  reaches.
- **Declarations:** it reads `MAKE_CONTRACT_TIERS`, `MAKE_CONTRACT_REQUIRED` and `MAKE_CONTRACT_RETIRED`
  from that database. A missing tiers value, or one other than `core` or `core code`, fails.
- **Fails (exit 1) when:**
  1. a target of a declared tier is missing;
  2. a name in `MAKE_CONTRACT_REQUIRED` is not defined;
  3. a name from naming rule 3's alias list, or from `MAKE_CONTRACT_RETIRED`, is defined;
  4. a recipe calls `make <target>` or `$(MAKE) <target>` for a target that the Makefile of the directory
     it runs in does not define: its own Makefile, or the called directory's for a call into another
     directory. A call into a directory with no Makefile fails too, unless the directory is missing and
     git ignores it (a consumed library, as in rule 5);
  5. a recipe runs a `_dev/*.sh` path that does not exist. Paths inside a consumed library that only exists
     after `deps-install` are exempt: a directory that is missing and that git ignores (`git check-ignore`).
     A missing directory git does not ignore is a finding, so a typo is not mistaken for a library;
  6. `SHELL` is not `/bin/sh`, or `.gitattributes` does not set `eol=lf` for `Makefile`, `*.mk` and `*.sh`.
- **Output:** one line per finding, `make-contract: <rule> <target> — <detail>`. On success it prints
  `make-contract: <tiers>, <n> targets, conforms`, per Makefile. A component's lines carry its path
  (`make-contract: <rule> [<path>] <target> — …`, `make-contract: [<path>] <tiers>, …`). Exit 2 when `make`
  itself cannot run.
- **Tests:** `scripts/test/check-make-contract.test.sh` (run by `make tests`) builds its fixtures: one Makefile
  per failure rule, one conforming Makefile per tier set, and one multi-component tree.

## Adopting the contract

The spec that brings a repository onto the contract lists every current target with a verdict. The verdicts
are **keep** (name and meaning already match), **keep\*** (name matches, recipe changes), **rename**, **add**
and **remove**. The spec also lists the declarations the Makefile gains. Once the Makefile conforms, the
conformance check is the only record, and the contract itself names no adopter.
