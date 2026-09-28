output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "ingress_public_ip_name" {
  value = azurerm_public_ip.ingress.name
}

output "ingress_ip" {
  value = azurerm_public_ip.ingress.ip_address
}

output "ingress_fqdn" {
  value = azurerm_public_ip.ingress.fqdn
}
