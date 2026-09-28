##@ Deploy the stack

# Listed in install order: each step needs the previous one

.PHONY: cert-manager certificates traefik ingress

cert-manager: ## Install or upgrade cert-manager
	@scripts/helm-release.sh cert-manager

certificates: ## Apply the self-signed issuer and the Grafana certificate
	@scripts/k8s-apply.sh namespaces cert-manager

traefik: ## Install or upgrade the Traefik reverse proxy
	@scripts/helm-release.sh traefik

ingress: ## Expose Grafana over HTTPS through Traefik
	@scripts/k8s-apply.sh ingress
