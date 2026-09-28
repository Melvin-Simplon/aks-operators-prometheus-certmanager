##@ General

.PHONY: help status lint

help: ## Show available targets
	@awk 'BEGIN { FS = ":[^#]*## " } \
		/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next } \
		/^[a-zA-Z_-]+:[^#]*## / { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

status: ## Read-only health report of the whole stack
	@scripts/status.sh

lint: ## Run shellcheck on scripts
	@shellcheck -x scripts/*.sh
