# Make contract: $(AI_DOTFILES)/docs/make-contract.md. Commands per stack: $(AI_DOTFILES)/docs/stacks/.
# Every target of a declared tier exists. Replace each `todo` stub with the stack binding's command. A target
# with no meaning here prints one `n/a — <reason>` line and exits 0; it is never deleted.
# A repository without source code deletes the code-tier block and sets MAKE_CONTRACT_TIERS := core.

# Recipes are POSIX shell on Linux, macOS and Windows (WSL2 / Git Bash): make-contract.md § Platform requirements.
SHELL := /bin/sh

# Read by the make-contract conformance check.
MAKE_CONTRACT_TIERS := core code
# Project-specific targets this repo promises to keep, e.g. its deploy targets `<platform>-build`.
MAKE_CONTRACT_REQUIRED :=
# Names retired by renaming them onto a contract target.
MAKE_CONTRACT_RETIRED :=

# The AI framework checkout, exported by the framework installer; set it here if your shell does not.
AI_DOTFILES ?=

# A stub that fails until the project fills it, so a scaffolded `make build` never passes on nothing.
todo = @echo "$(1): not implemented yet — see $(AI_DOTFILES)/docs/make-contract.md"; exit 1

# --- core tier -------------------------------------------------------------------------------------------

.PHONY: help clean build docs-check quality-gates-check sync-agents sync-agents-check

help: ## List the targets this Makefile defines
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-22s %s\n", $$1, $$2}'

clean: ## Remove build output and generated files (never dependencies, sources or .env*)
	$(call todo,clean)

# The verification sequence: numbered gate steps in contract order, first failure stops the run. Keep it in
# step with the Build and Run table in `_canonical.md`. It never rewrites the tree.
build: ## Verification sequence: docs-check, then the code-tier steps
	$(MAKE) clean
	$(MAKE) docs-check
	$(BUILD_CODE_STEPS)

docs-check: quality-gates-check sync-agents-check ## Every documentation drift check, plus make-contract conformance
	@test -d "$(AI_DOTFILES)/scripts" \
	  || { echo "docs-check: framework not found at $(AI_DOTFILES); set AI_DOTFILES"; exit 1; }
	@if test -f "$(AI_DOTFILES)/scripts/check-make-contract.py"; then \
	  python3 "$(AI_DOTFILES)/scripts/check-make-contract.py" .; \
	else echo "docs-check: make-contract check not shipped yet, skipped"; fi
	@echo "docs-check: all checks passed"

quality-gates-check: ## The Build and Run table against the Kind / Mode contract
	@test -f "$(AI_DOTFILES)/scripts/validate-quality-gates.py" \
	  || { echo "quality-gates-check: framework not found at $(AI_DOTFILES); set AI_DOTFILES"; exit 1; }
	python3 "$(AI_DOTFILES)/scripts/validate-quality-gates.py" .

sync-agents: ## Regenerate CLAUDE.md, AGENTS.md and copilot-instructions.md from _canonical.md
	./.github/scripts/sync-agents.sh

sync-agents-check: ## Fail when the rendered agent files drift from _canonical.md
	./.github/scripts/sync-agents.sh --check

# >>> code tier — delete from here to the closing marker in a repository without source code --------------

.PHONY: format lint typecheck test run dup-report audit deps-install deps-update env-local

# Build steps 2–6, run by `build` after docs-check. Remove step 6 when the component ships no artifact.
define BUILD_CODE_STEPS
$(call todo,build step 2 (format check))
$(MAKE) lint
$(MAKE) typecheck
$(MAKE) test
$(call todo,build step 6 (production build))
endef

format: ## Rewrite sources with the formatter (never a build step)
	$(call todo,format)

lint: ## Static analysis, including the style's dependency rules
	$(call todo,lint)

typecheck: ## Compile or type-check every module; no release artifacts
	$(call todo,typecheck)

test: ## Unit suites and the style's structure audits
	$(call todo,test)

run: ## Start the app or service locally in dev mode
	$(call todo,run)

dup-report: ## Duplicated-code report (exits 0 whatever it finds)
	@test -f "$(AI_DOTFILES)/scripts/report-duplication.js" \
	  || { echo "dup-report: framework not found at $(AI_DOTFILES); set AI_DOTFILES"; exit 2; }
	node "$(AI_DOTFILES)/scripts/report-duplication.js" --scan-root src

audit: ## Dependency vulnerability report (exits 0 whatever it finds)
	$(call todo,audit)

deps-install: ## Install dependencies from the lockfile
	$(call todo,deps-install)

deps-update: ## Bump dependencies, then clean
	$(call todo,deps-update)
	$(MAKE) clean

env-local: ## Start the local backing services
	$(call todo,env-local)

# <<< code tier ----------------------------------------------------------------------------------------------

# --- Project-specific targets below (make-contract.md § Naming rule, § Target families) ---
