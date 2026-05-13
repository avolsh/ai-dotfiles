.PHONY: sync-agents sync-agents-check help

help:
	@echo "Targets:"
	@echo "  sync-agents        Regenerate AGENTS.md from .github/copilot-instructions.md"
	@echo "  sync-agents-check  Check for drift (exits non-zero if AGENTS.md needs regeneration)"
	@echo ""
	@echo "Add project-specific targets (build, test, run-*) below."

sync-agents:
	./.github/scripts/sync-agents.sh

sync-agents-check:
	./.github/scripts/sync-agents.sh --check

# --- Project-specific targets below ---
# Add build, test, and run-* targets here as the project grows.
