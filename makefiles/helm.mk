##@ Helm releases

.PHONY: cert-manager

cert-manager: ## Install or upgrade cert-manager
	@scripts/helm-release.sh cert-manager
