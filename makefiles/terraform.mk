##@ Terraform

.PHONY: tf-check tf-plan tf-apply

tf-check: ## Init, format and validate
	@scripts/terraform.sh check

tf-plan: ## Check, then show the plan
	@scripts/terraform.sh plan

tf-apply: ## Check, plan, confirm, then apply the saved plan
	@scripts/terraform.sh apply
