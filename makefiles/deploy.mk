##@ Deploy the stack

# Listed in install order: each step needs the previous one

.PHONY: cert-manager certificates traefik ingress alerts dashboards

cert-manager: ## Install or upgrade cert-manager
	@scripts/helm-release.sh cert-manager

certificates: ## Apply the self-signed issuer and the Grafana certificate
	@scripts/k8s-apply.sh namespaces cert-manager

traefik: ## Install or upgrade the Traefik reverse proxy
	@scripts/helm-release.sh traefik

ingress: ## Expose Grafana over HTTPS through Traefik
	@scripts/k8s-apply.sh ingress

alerts: ## Apply the alert rules for pods and certificates
	@scripts/k8s-apply.sh monitoring

dashboards: ## Load the Grafana dashboards from k8s/grafana/
	@scripts/k8s-apply.sh grafana
