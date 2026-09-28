##@ Kubernetes manifests

.PHONY: certificates ingress

certificates: ## Apply the self-signed issuer and the Grafana certificate
	@scripts/k8s-apply.sh namespaces cert-manager

ingress: ## Expose Grafana over HTTPS through Traefik
	@scripts/k8s-apply.sh ingress
