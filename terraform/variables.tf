variable "subscription_id" {
  description = "Azure subscription hosting the cluster"
  type        = string
  default     = "e637ffef-fec0-4228-8787-e612a65e5b08"
}

variable "dns_label" {
  description = "DNS label of the ingress public IP, gives <label>.<region>.cloudapp.azure.com"
  type        = string
  default     = "monitoring-groupe3"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.dns_label))
    error_message = "3 to 63 lowercase letters, digits or hyphens, starting with a letter."
  }
}
