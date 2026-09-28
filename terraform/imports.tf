import {
  to = azurerm_resource_group.main
  id = "/subscriptions/${var.subscription_id}/resourceGroups/test-rg"
}

import {
  to = azurerm_kubernetes_cluster.main
  id = "/subscriptions/${var.subscription_id}/resourceGroups/test-rg/providers/Microsoft.ContainerService/managedClusters/test-steve"
}
