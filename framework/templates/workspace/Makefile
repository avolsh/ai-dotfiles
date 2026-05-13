.PHONY: sync-agents sync-agents-check help

help:
	@echo "Targets:"
	@echo "  sync-agents        Regenerate AGENTS.md from .github/copilot-instructions.md"
	@echo "  sync-agents-check  Check for drift (exits non-zero if AGENTS.md needs regeneration)"

sync-agents:
	./.github/scripts/sync-agents.sh

sync-agents-check:
	./.github/scripts/sync-agents.sh --check
