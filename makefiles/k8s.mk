##@ Kubernetes manifests

.PHONY: certificates

certificates: ## Apply the self-signed issuer and the Grafana certificate
	@scripts/k8s-apply.sh namespaces cert-manager
