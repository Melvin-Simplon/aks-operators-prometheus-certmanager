##@ Checks

.PHONY: menu status lint

menu: ## Interactive menu of every target
	@MAKE="$(MAKE)" scripts/menu.sh $(MAKEFILE_LIST)

status: ## Read-only health report of the whole stack
	@scripts/status.sh

lint: ## Run shellcheck on scripts
	@shellcheck -x scripts/*.sh
