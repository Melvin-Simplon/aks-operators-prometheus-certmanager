##@ Access

.PHONY: grafana prometheus alertmanager traefik-dashboard open-all

grafana: ## Open Grafana, admin password copied to the clipboard
	@scripts/grafana.sh

prometheus: ## Open the Prometheus alerts on localhost:9090 (port-forward)
	@scripts/open-ui.sh prometheus

alertmanager: ## Open Alertmanager on localhost:9093 (port-forward)
	@scripts/open-ui.sh alertmanager

traefik-dashboard: ## Open the Traefik dashboard on localhost:9000 (port-forward)
	@scripts/open-ui.sh traefik

open-all: ## Open all of the above at once, Ctrl+C closes every tunnel
	@scripts/grafana.sh
	@scripts/open-ui.sh prometheus alertmanager traefik
