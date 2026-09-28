resource "azurerm_resource_group" "main" {
  name     = "test-rg"
  location = "australiaeast"
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "test-steve"
  location            = "polandcentral"
  resource_group_name = azurerm_resource_group.main.name
  node_resource_group = "MC_test-rg_test-steve_francecentral"
  dns_prefix          = "test-steve-dns"
  kubernetes_version  = "1.35.7"
  sku_tier            = "Free"

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 168

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                 = "agentpool"
    vm_size              = "Standard_D2s_v3"
    node_count           = 1
    orchestrator_version = "1.35.7"
    os_disk_size_gb      = 128

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  node_provisioning_profile {
    mode = "Manual"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "azure"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.0.0.0/16"
    dns_service_ip      = "10.0.0.10"
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Sunday"
    duration    = 8
    start_time  = "00:00"
    utc_offset  = "+00:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Sunday"
    duration    = 8
    start_time  = "00:00"
    utc_offset  = "+00:00"
  }

  lifecycle {
    prevent_destroy = true
    # Azure leaves this field unset in Manual mode, the provider would force "Auto"
    ignore_changes = [node_provisioning_profile[0].default_node_pools]
  }
}

# Dedicated pool: only monitoring workloads tolerate the taint
resource "azurerm_kubernetes_cluster_node_pool" "monitoring" {
  name                  = "monitoring"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D4s_v4"
  node_count            = 1
  mode                  = "User"
  os_disk_size_gb       = 128

  node_labels = {
    workload = "monitoring"
  }
  node_taints = ["workload=monitoring:NoSchedule"]

  # Regional quota is 6 vCPU and this pool fills it: no room for a surge node
  upgrade_settings {
    max_unavailable = "1"
  }
}
