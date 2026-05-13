.PHONY: help install profile-init reset

help:
	@echo "Targets:"
	@echo "  install                    Run ./scripts/ai-install.sh"
	@echo "  profile-init PROFILE=name  Run ./scripts/ai-profile-init.sh \"name\""
	@echo "  reset                      Run ./scripts/ai-switch.sh --reset"
	@echo ""
	@echo "Direct script forms:"
	@echo "  ./scripts/ai-install.sh"
	@echo "  ./scripts/ai-profile-init.sh <profile>"
	@echo "  source ./scripts/ai-switch.sh <profile>"
	@echo "  source ./scripts/ai-switch.sh --reset"
	@echo "  ./scripts/ai-workspace.sh"
	@echo "  ./scripts/ai-project.sh"

install:
	./scripts/ai-install.sh

profile-init:
	@if [ -z "$(PROFILE)" ]; then \
		echo "usage: make profile-init PROFILE=<name>" >&2; \
		exit 2; \
	fi
	./scripts/ai-profile-init.sh "$(PROFILE)"

reset:
	./scripts/ai-switch.sh --reset
