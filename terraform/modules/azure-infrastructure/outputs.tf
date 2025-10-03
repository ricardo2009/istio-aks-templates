# ===============================================================================
# AZURE INFRASTRUCTURE MODULE - OUTPUTS
# ===============================================================================

# Resource Group
output "resource_group_name" {
  description = "Nome do Resource Group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID do Resource Group"
  value       = azurerm_resource_group.main.id
}

# Virtual Network
output "vnet_id" {
  description = "ID da Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Nome da Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "vnet_address_space" {
  description = "Espaço de endereçamento da VNet"
  value       = azurerm_virtual_network.main.address_space
}

# Subnets
output "primary_subnet_id" {
  description = "ID da subnet do cluster primário"
  value       = azurerm_subnet.primary.id
}

output "secondary_subnet_id" {
  description = "ID da subnet do cluster secundário"
  value       = azurerm_subnet.secondary.id
}

output "loadtest_subnet_id" {
  description = "ID da subnet do cluster de load testing"
  value       = azurerm_subnet.loadtest.id
}

output "apim_subnet_id" {
  description = "ID da subnet do APIM"
  value       = azurerm_subnet.apim.id
}

output "gateway_subnet_id" {
  description = "ID da subnet do gateway"
  value       = azurerm_subnet.gateway.id
}

output "primary_subnet_cidr" {
  description = "CIDR da subnet do cluster primário"
  value       = azurerm_subnet.primary.address_prefixes[0]
}

output "secondary_subnet_cidr" {
  description = "CIDR da subnet do cluster secundário"
  value       = azurerm_subnet.secondary.address_prefixes[0]
}

output "loadtest_subnet_cidr" {
  description = "CIDR da subnet do cluster de load testing"
  value       = azurerm_subnet.loadtest.address_prefixes[0]
}

output "apim_subnet_cidr" {
  description = "CIDR da subnet do APIM"
  value       = azurerm_subnet.apim.address_prefixes[0]
}

# AKS Clusters
output "clusters" {
  description = "Informações dos clusters AKS"
  value = {
    primary = {
      id                         = azurerm_kubernetes_cluster.primary.id
      name                       = azurerm_kubernetes_cluster.primary.name
      fqdn                       = azurerm_kubernetes_cluster.primary.fqdn
      kubernetes_version         = azurerm_kubernetes_cluster.primary.kubernetes_version
      node_resource_group_name   = azurerm_kubernetes_cluster.primary.node_resource_group
      host                       = azurerm_kubernetes_cluster.primary.kube_config.0.host
      client_certificate         = azurerm_kubernetes_cluster.primary.kube_config.0.client_certificate
      client_key                 = azurerm_kubernetes_cluster.primary.kube_config.0.client_key
      cluster_ca_certificate     = azurerm_kubernetes_cluster.primary.kube_config.0.cluster_ca_certificate
      identity_principal_id      = azurerm_kubernetes_cluster.primary.identity[0].principal_id
      kubelet_identity_object_id = azurerm_kubernetes_cluster.primary.kubelet_identity[0].object_id
    }
    secondary = {
      id                         = azurerm_kubernetes_cluster.secondary.id
      name                       = azurerm_kubernetes_cluster.secondary.name
      fqdn                       = azurerm_kubernetes_cluster.secondary.fqdn
      kubernetes_version         = azurerm_kubernetes_cluster.secondary.kubernetes_version
      node_resource_group_name   = azurerm_kubernetes_cluster.secondary.node_resource_group
      host                       = azurerm_kubernetes_cluster.secondary.kube_config.0.host
      client_certificate         = azurerm_kubernetes_cluster.secondary.kube_config.0.client_certificate
      client_key                 = azurerm_kubernetes_cluster.secondary.kube_config.0.client_key
      cluster_ca_certificate     = azurerm_kubernetes_cluster.secondary.kube_config.0.cluster_ca_certificate
      identity_principal_id      = azurerm_kubernetes_cluster.secondary.identity[0].principal_id
      kubelet_identity_object_id = azurerm_kubernetes_cluster.secondary.kubelet_identity[0].object_id
    }
    loadtest = {
      id                         = azurerm_kubernetes_cluster.loadtest.id
      name                       = azurerm_kubernetes_cluster.loadtest.name
      fqdn                       = azurerm_kubernetes_cluster.loadtest.fqdn
      kubernetes_version         = azurerm_kubernetes_cluster.loadtest.kubernetes_version
      node_resource_group_name   = azurerm_kubernetes_cluster.loadtest.node_resource_group
      host                       = azurerm_kubernetes_cluster.loadtest.kube_config.0.host
      client_certificate         = azurerm_kubernetes_cluster.loadtest.kube_config.0.client_certificate
      client_key                 = azurerm_kubernetes_cluster.loadtest.kube_config.0.client_key
      cluster_ca_certificate     = azurerm_kubernetes_cluster.loadtest.kube_config.0.cluster_ca_certificate
      identity_principal_id      = azurerm_kubernetes_cluster.loadtest.identity[0].principal_id
      kubelet_identity_object_id = azurerm_kubernetes_cluster.loadtest.kubelet_identity[0].object_id
    }
  }
  sensitive = true
}

# Container Registry
output "container_registry_id" {
  description = "ID do Container Registry"
  value       = azurerm_container_registry.main.id
}

output "container_registry_name" {
  description = "Nome do Container Registry"
  value       = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  description = "Login server do Container Registry"
  value       = azurerm_container_registry.main.login_server
}

# Log Analytics
output "log_analytics_workspace_id" {
  description = "ID do Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Nome do Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_key" {
  description = "Chave primária do Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

# Network Security Groups
output "network_security_groups" {
  description = "IDs dos Network Security Groups"
  value = {
    primary   = azurerm_network_security_group.aks_primary.id
    secondary = azurerm_network_security_group.aks_secondary.id
    loadtest  = azurerm_network_security_group.aks_loadtest.id
  }
}

# Private DNS Zone
output "private_dns_zones" {
  description = "Informações das Private DNS Zones"
  value = {
    main = {
      id   = azurerm_private_dns_zone.main.id
      name = azurerm_private_dns_zone.main.name
    }
  }
}
