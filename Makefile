.PHONY: help install install-check profile-init reset project workspace links-check validate-specs lint-rules validate-anchors sync-system-templates sync-agents-check check doctor doctor-fast install-git-hooks tests spec-metrics

help:
	@echo "Targets:"
	@echo "  install                    Run ai-install.sh (idempotent ~/.zshrc setup)"
	@echo "  install-check              Check ~/.zshrc managed block for drift"
	@echo "  profile-init PROFILE=name  Initialize a profile's tool subdirs"
	@echo "  reset                      Remove active-profile env (ai-switch --reset)"
	@echo "  project                    Scaffold current dir as a project repo"
	@echo "  workspace                  Scaffold current dir as a workspace root"
	@echo "  doctor                     Verify active-profile invariants (symlinks, manifest)"
	@echo "  install-git-hooks          Point this repo's core.hooksPath at scripts/git-hooks"
	@echo "  tests                      Run all script self-tests (hooks, doctor, pre-commit, metrics)"
	@echo "  spec-metrics               Report framework-vs-product spec share by month"
	@echo "  links-check                Verify markdown link integrity"
	@echo "  validate-specs             Validate spec corpus (front-matter, deps, naming, etc.)"
	@echo "  lint-rules                 Flag verbatim canonical-rule duplicates outside their canonical files"
	@echo "  validate-anchors           Verify markdown #fragment links resolve to existing anchors"
	@echo "  sync-system-templates      Regenerate framework/templates/system/{claude,copilot,codex}/* from _canonical.md"
	@echo "  sync-agents-check          Validate spec corpus + lint rule duplicates + anchor fragments (CI alias)"
	@echo "  check                      Run all checks (links-check + install-check + validate-specs + lint-rules + validate-anchors)"
	@echo ""
	@echo "Source-only (cannot be a Make target):"
	@echo "  source ./scripts/ai-switch.sh <profile>"

install:
	./scripts/ai-install.sh

install-check:
	./scripts/ai-install.sh --check

profile-init:
	@if [ -z "$(PROFILE)" ]; then \
		echo "usage: make profile-init PROFILE=<name>" >&2; \
		exit 2; \
	fi
	./scripts/ai-profile-init.sh "$(PROFILE)"

reset:
	./scripts/ai-switch.sh --reset

project:
	./scripts/ai-project.sh

workspace:
	./scripts/ai-workspace.sh

install-git-hooks:
	git config core.hooksPath scripts/git-hooks
	@echo "core.hooksPath -> scripts/git-hooks (pre-commit backstop active)"

tests:
	./framework/scripts/test/check-md-links.test.sh
	./framework/scripts/test/hooks.test.sh
	./scripts/test/ai-doctor.test.sh
	./scripts/test/pre-commit.test.sh
	./scripts/test/spec-metrics.test.sh
	./scripts/test/validate-specs.test.sh
	./scripts/test/profile-links.test.sh
	./scripts/test/ai-switch.test.sh

spec-metrics:
	python3 ./scripts/spec-metrics.py

doctor:
	./scripts/ai-doctor.sh

doctor-fast:
	./scripts/ai-doctor.sh --fast

links-check:
	./framework/scripts/check-md-links.sh

validate-specs:
	python3 ./scripts/validate-specs.py

lint-rules:
	python3 ./scripts/lint-rules.py

validate-anchors:
	python3 ./scripts/validate-anchors.py

sync-system-templates:
	./scripts/generate-system-templates.sh

# CI entry point. Mirrors the per-project `make sync-agents-check`
# convention. Chains the framework-internal checks: spec validation +
# canonical-rule duplicate lint + anchor-fragment resolution.
sync-agents-check: validate-specs lint-rules validate-anchors

check: links-check install-check validate-specs lint-rules validate-anchors tests

submodule-update:
	git submodule update --remote --recursive
