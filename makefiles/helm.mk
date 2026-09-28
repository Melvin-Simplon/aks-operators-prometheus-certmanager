##@ Helm releases

.PHONY: cert-manager traefik traefik-dashboard

cert-manager: ## Install or upgrade cert-manager
	@scripts/helm-release.sh cert-manager

traefik: ## Install or upgrade the Traefik reverse proxy
	@scripts/helm-release.sh traefik

traefik-dashboard: ## Open the Traefik dashboard on localhost:9000 (port-forward)
	@scripts/traefik-dashboard.sh
