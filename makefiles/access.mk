##@ Access

.PHONY: grafana traefik-dashboard

grafana: ## Open Grafana, admin password copied to the clipboard
	@scripts/grafana.sh

traefik-dashboard: ## Open the Traefik dashboard on localhost:9000 (port-forward)
	@scripts/traefik-dashboard.sh
