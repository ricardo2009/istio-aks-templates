# ===============================================================================
# AZURE INFRASTRUCTURE MODULE - MAIN CONFIGURATION
# ===============================================================================
# Módulo responsável por provisionar toda a infraestrutura base Azure
# Inclui: Resource Group, VNet, Subnets, AKS Clusters, Log Analytics
# ===============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# ===============================================================================
# LOCAL VALUES
# ===============================================================================

locals {
  # Common naming convention
  name_prefix = var.resource_prefix
  
  # Network configuration
  subnet_configs = {
    primary = {
      name             = "${local.name_prefix}-subnet-primary"
      address_prefixes = [var.clusters.primary.subnet_cidr]
    }
    secondary = {
      name             = "${local.name_prefix}-subnet-secondary"
      address_prefixes = [var.clusters.secondary.subnet_cidr]
    }
    loadtest = {
      name             = "${local.name_prefix}-subnet-loadtest"
      address_prefixes = [var.clusters.loadtest.subnet_cidr]
    }
    apim = {
      name             = "${local.name_prefix}-subnet-apim"
      address_prefixes = ["10.4.0.0/24"]
    }
    gateway = {
      name             = "${local.name_prefix}-subnet-gateway"
      address_prefixes = ["10.5.0.0/24"]
    }
  }
  
  # Common tags
  common_tags = merge(var.tags, {
    Module = "azure-infrastructure"
  })
}

# ===============================================================================
# RANDOM RESOURCES
# ===============================================================================

resource "random_id" "workspace_suffix" {
  byte_length = 4
}

resource "random_id" "storage_suffix" {
  byte_length = 4
}

# ===============================================================================
# RESOURCE GROUP
# ===============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ===============================================================================
# VIRTUAL NETWORK AND SUBNETS
# ===============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Primary Cluster Subnet
resource "azurerm_subnet" "primary" {
  name                 = local.subnet_configs.primary.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = local.subnet_configs.primary.address_prefixes
  
  # Enable service endpoints
  service_endpoints = [
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.Storage",
    "Microsoft.AzureCosmosDB"
  ]
}

# Secondary Cluster Subnet
resource "azurerm_subnet" "secondary" {
  name                 = local.subnet_configs.secondary.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = local.subnet_configs.secondary.address_prefixes
  
  # Enable service endpoints
  service_endpoints = [
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.Storage",
    "Microsoft.AzureCosmosDB"
  ]
}

# Load Testing Cluster Subnet
resource "azurerm_subnet" "loadtest" {
  name                 = local.subnet_configs.loadtest.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = local.subnet_configs.loadtest.address_prefixes
  
  # Enable service endpoints
  service_endpoints = [
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.Storage"
  ]
}

# APIM Subnet
resource "azurerm_subnet" "apim" {
  name                 = local.subnet_configs.apim.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = local.subnet_configs.apim.address_prefixes
  
  # Enable service endpoints
  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.Storage"
  ]
}

# Gateway Subnet (for Application Gateway if needed)
resource "azurerm_subnet" "gateway" {
  name                 = local.subnet_configs.gateway.name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = local.subnet_configs.gateway.address_prefixes
}

# ===============================================================================
# NETWORK SECURITY GROUPS
# ===============================================================================

resource "azurerm_network_security_group" "aks_primary" {
  name                = "${local.name_prefix}-nsg-primary"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Allow inbound HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow inbound HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow Istio sidecar communication
  security_rule {
    name                       = "AllowIstioSidecar"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "15000-15090"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_network_security_group" "aks_secondary" {
  name                = "${local.name_prefix}-nsg-secondary"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Allow cross-cluster communication
  security_rule {
    name                       = "AllowCrossCluster"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080-8090"
    source_address_prefix      = var.clusters.primary.subnet_cidr
    destination_address_prefix = "*"
  }

  # Allow Istio sidecar communication
  security_rule {
    name                       = "AllowIstioSidecar"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "15000-15090"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_network_security_group" "aks_loadtest" {
  name                = "${local.name_prefix}-nsg-loadtest"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Allow outbound to target clusters
  security_rule {
    name                       = "AllowLoadTestTraffic"
    priority                   = 1001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443", "8080-8090"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "primary" {
  subnet_id                 = azurerm_subnet.primary.id
  network_security_group_id = azurerm_network_security_group.aks_primary.id
}

resource "azurerm_subnet_network_security_group_association" "secondary" {
  subnet_id                 = azurerm_subnet.secondary.id
  network_security_group_id = azurerm_network_security_group.aks_secondary.id
}

resource "azurerm_subnet_network_security_group_association" "loadtest" {
  subnet_id                 = azurerm_subnet.loadtest.id
  network_security_group_id = azurerm_network_security_group.aks_loadtest.id
}

# ===============================================================================
# LOG ANALYTICS WORKSPACE
# ===============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-law-${random_id.workspace_suffix.hex}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = 90
  tags                = local.common_tags
}

# ===============================================================================
# CONTAINER REGISTRY
# ===============================================================================

resource "azurerm_container_registry" "main" {
  name                = "${replace(local.name_prefix, "-", "")}acr${random_id.storage_suffix.hex}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium"
  admin_enabled       = false
  tags                = local.common_tags

  # Enable geo-replication for high availability
  georeplications {
    location                = "East US 2"
    zone_redundancy_enabled = true
    tags                    = local.common_tags
  }

  # Network access rules
  network_rule_set {
    default_action = "Deny"

    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.primary.id
    }

    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.secondary.id
    }

    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.loadtest.id
    }
  }
}

# ===============================================================================
# AKS CLUSTERS
# ===============================================================================

# Primary AKS Cluster
resource "azurerm_kubernetes_cluster" "primary" {
  name                = var.clusters.primary.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.clusters.primary.name}-dns"
  kubernetes_version  = var.kubernetes_version
  tags                = local.common_tags

  # Default node pool
  default_node_pool {
    name                = "system"
    node_count          = var.clusters.primary.node_count
    vm_size             = var.clusters.primary.vm_size
    vnet_subnet_id      = azurerm_subnet.primary.id
    zones               = var.clusters.primary.availability_zones
    max_pods            = var.clusters.primary.max_pods
    os_disk_size_gb     = 128
    os_disk_type        = "Managed"
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = 3
    max_count           = 20

    upgrade_settings {
      max_surge = "10%"
    }

    tags = local.common_tags
  }

  # Identity configuration
  identity {
    type = "SystemAssigned"
  }

  # Network configuration
  network_profile {
    network_plugin      = "azure"
    network_policy      = "azure"
    dns_service_ip      = "10.100.0.10"
    service_cidr        = "10.100.0.0/16"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  # RBAC configuration
  role_based_access_control_enabled = var.enable_rbac

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Service mesh (Istio)
  service_mesh_profile {
    mode                             = "Istio"
    internal_ingress_gateway_enabled = true
    external_ingress_gateway_enabled = true
  }

  # Auto-scaler profile
  auto_scaler_profile {
    balance_similar_node_groups      = false
    expander                        = "random"
    max_graceful_termination_sec    = "600"
    max_node_provisioning_time      = "15m"
    max_unready_nodes               = 3
    max_unready_percentage          = 45
    new_pod_scale_up_delay          = "10s"
    scale_down_delay_after_add      = "10m"
    scale_down_delay_after_delete   = "10s"
    scale_down_delay_after_failure  = "3m"
    scan_interval                   = "10s"
    scale_down_threshold            = "0.5"
    scale_down_unneeded_time        = "10m"
    scale_down_utilization_threshold = "0.5"
    empty_bulk_delete_max           = "10"
    skip_nodes_with_local_storage   = false
    skip_nodes_with_system_pods     = true
  }

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4, 5]
    }
  }

  depends_on = [
    azurerm_subnet.primary,
    azurerm_log_analytics_workspace.main
  ]
}

# Secondary AKS Cluster
resource "azurerm_kubernetes_cluster" "secondary" {
  name                = var.clusters.secondary.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.clusters.secondary.name}-dns"
  kubernetes_version  = var.kubernetes_version
  tags                = local.common_tags

  # Default node pool
  default_node_pool {
    name                = "system"
    node_count          = var.clusters.secondary.node_count
    vm_size             = var.clusters.secondary.vm_size
    vnet_subnet_id      = azurerm_subnet.secondary.id
    zones               = var.clusters.secondary.availability_zones
    max_pods            = var.clusters.secondary.max_pods
    os_disk_size_gb     = 128
    os_disk_type        = "Managed"
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 15

    upgrade_settings {
      max_surge = "10%"
    }

    tags = local.common_tags
  }

  # Identity configuration
  identity {
    type = "SystemAssigned"
  }

  # Network configuration
  network_profile {
    network_plugin      = "azure"
    network_policy      = "azure"
    dns_service_ip      = "10.101.0.10"
    service_cidr        = "10.101.0.0/16"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  # RBAC configuration
  role_based_access_control_enabled = var.enable_rbac

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Service mesh (Istio)
  service_mesh_profile {
    mode                             = "Istio"
    internal_ingress_gateway_enabled = true
    external_ingress_gateway_enabled = true
  }

  # Auto-scaler profile
  auto_scaler_profile {
    balance_similar_node_groups      = false
    expander                        = "random"
    max_graceful_termination_sec    = "600"
    max_node_provisioning_time      = "15m"
    max_unready_nodes               = 3
    max_unready_percentage          = 45
    new_pod_scale_up_delay          = "10s"
    scale_down_delay_after_add      = "10m"
    scale_down_delay_after_delete   = "10s"
    scale_down_delay_after_failure  = "3m"
    scan_interval                   = "10s"
    scale_down_threshold            = "0.5"
    scale_down_unneeded_time        = "10m"
    scale_down_utilization_threshold = "0.5"
    empty_bulk_delete_max           = "10"
    skip_nodes_with_local_storage   = false
    skip_nodes_with_system_pods     = true
  }

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4, 5]
    }
  }

  depends_on = [
    azurerm_subnet.secondary,
    azurerm_log_analytics_workspace.main
  ]
}

# Load Testing AKS Cluster
resource "azurerm_kubernetes_cluster" "loadtest" {
  name                = var.clusters.loadtest.name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.clusters.loadtest.name}-dns"
  kubernetes_version  = var.kubernetes_version
  tags                = local.common_tags

  # Default node pool - optimized for load testing
  default_node_pool {
    name                = "system"
    node_count          = var.clusters.loadtest.node_count
    vm_size             = var.clusters.loadtest.vm_size
    vnet_subnet_id      = azurerm_subnet.loadtest.id
    zones               = var.clusters.loadtest.availability_zones
    max_pods            = var.clusters.loadtest.max_pods
    os_disk_size_gb     = 256
    os_disk_type        = "Managed"
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = 3
    max_count           = 50

    upgrade_settings {
      max_surge = "25%"
    }

    tags = local.common_tags
  }

  # Identity configuration
  identity {
    type = "SystemAssigned"
  }

  # Network configuration
  network_profile {
    network_plugin      = "azure"
    network_policy      = "azure"
    dns_service_ip      = "10.102.0.10"
    service_cidr        = "10.102.0.0/16"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  # RBAC configuration
  role_based_access_control_enabled = var.enable_rbac

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Auto-scaler profile - optimized for load testing
  auto_scaler_profile {
    balance_similar_node_groups      = true
    expander                        = "priority"
    max_graceful_termination_sec    = "300"
    max_node_provisioning_time      = "10m"
    max_unready_nodes               = 10
    max_unready_percentage          = 50
    new_pod_scale_up_delay          = "5s"
    scale_down_delay_after_add      = "5m"
    scale_down_delay_after_delete   = "5s"
    scale_down_delay_after_failure  = "1m"
    scan_interval                   = "5s"
    scale_down_threshold            = "0.3"
    scale_down_unneeded_time        = "5m"
    scale_down_utilization_threshold = "0.3"
    empty_bulk_delete_max           = "20"
    skip_nodes_with_local_storage   = false
    skip_nodes_with_system_pods     = true
  }

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3, 4, 5]
    }
  }

  depends_on = [
    azurerm_subnet.loadtest,
    azurerm_log_analytics_workspace.main
  ]
}

# ===============================================================================
# RBAC ASSIGNMENTS
# ===============================================================================

# Grant AKS clusters access to Container Registry
resource "azurerm_role_assignment" "primary_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.primary.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "secondary_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.secondary.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "loadtest_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.loadtest.kubelet_identity[0].object_id
}

# Grant Network Contributor role to AKS clusters for subnet operations
resource "azurerm_role_assignment" "primary_network_contributor" {
  scope                = azurerm_subnet.primary.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.primary.identity[0].principal_id
}

resource "azurerm_role_assignment" "secondary_network_contributor" {
  scope                = azurerm_subnet.secondary.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.secondary.identity[0].principal_id
}

resource "azurerm_role_assignment" "loadtest_network_contributor" {
  scope                = azurerm_subnet.loadtest.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.loadtest.identity[0].principal_id
}

# ===============================================================================
# PRIVATE DNS ZONES
# ===============================================================================

resource "azurerm_private_dns_zone" "main" {
  name                = "privatelink.${var.location}.azmk8s.io"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = "${local.name_prefix}-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}
