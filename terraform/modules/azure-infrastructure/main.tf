# Azure Infrastructure Module - Main Configuration
# This module creates the core Azure infrastructure for the Enterprise Istio on AKS solution

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(var.common_tags, {
    Component = "Infrastructure"
  })
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = [var.vnet_address_space]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(var.common_tags, {
    Component = "Networking"
  })
}

# Subnets
resource "azurerm_subnet" "aks_primary" {
  name                 = "${var.prefix}-aks-primary-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_primary_subnet_address_prefix]
}

resource "azurerm_subnet" "aks_secondary" {
  name                 = "${var.prefix}-aks-secondary-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_secondary_subnet_address_prefix]
}

resource "azurerm_subnet" "aks_loadtest" {
  name                 = "${var.prefix}-aks-loadtest-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_loadtest_subnet_address_prefix]
}

resource "azurerm_subnet" "apim" {
  name                 = "${var.prefix}-apim-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.apim_subnet_address_prefix]
}

# Network Security Groups
resource "azurerm_network_security_group" "aks" {
  name                = "${var.prefix}-aks-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

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

  tags = merge(var.common_tags, {
    Component = "Security"
  })
}

resource "azurerm_network_security_group" "apim" {
  name                = "${var.prefix}-apim-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowAPIMManagement"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.common_tags, {
    Component = "Security"
  })
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "aks_primary" {
  subnet_id                 = azurerm_subnet.aks_primary.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "aks_secondary" {
  subnet_id                 = azurerm_subnet.aks_secondary.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "aks_loadtest" {
  subnet_id                 = azurerm_subnet.aks_loadtest.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days

  tags = merge(var.common_tags, {
    Component = "Monitoring"
  })
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = "${replace(var.prefix, "-", "")}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium"
  admin_enabled       = false

  identity {
    type = "SystemAssigned"
  }

  network_rule_set {
    default_action = "Allow"
  }

  tags = merge(var.common_tags, {
    Component = "Container Registry"
  })
}

# AKS Clusters
resource "azurerm_kubernetes_cluster" "primary" {
  name                = "${var.prefix}-aks-primary"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.prefix}-aks-primary"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.aks_primary_node_count
    vm_size             = var.aks_primary_vm_size
    vnet_subnet_id      = azurerm_subnet.aks_primary.id
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = var.aks_primary_min_count
    max_count           = var.aks_primary_max_count
    os_disk_size_gb     = 100
    os_disk_type        = "Managed"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.aks_service_cidr
    dns_service_ip    = var.aks_dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  service_mesh_profile {
    mode                             = "Istio"
    internal_ingress_gateway_enabled = true
    external_ingress_gateway_enabled = true
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  azure_policy_enabled = true

  tags = merge(var.common_tags, {
    Component = "AKS Primary"
  })
}

resource "azurerm_kubernetes_cluster" "secondary" {
  name                = "${var.prefix}-aks-secondary"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.prefix}-aks-secondary"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.aks_secondary_node_count
    vm_size             = var.aks_secondary_vm_size
    vnet_subnet_id      = azurerm_subnet.aks_secondary.id
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = var.aks_secondary_min_count
    max_count           = var.aks_secondary_max_count
    os_disk_size_gb     = 100
    os_disk_type        = "Managed"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.aks_service_cidr_secondary
    dns_service_ip    = var.aks_dns_service_ip_secondary
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  service_mesh_profile {
    mode                             = "Istio"
    internal_ingress_gateway_enabled = true
    external_ingress_gateway_enabled = true
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  azure_policy_enabled = true

  tags = merge(var.common_tags, {
    Component = "AKS Secondary"
  })
}

resource "azurerm_kubernetes_cluster" "loadtest" {
  name                = "${var.prefix}-aks-loadtest"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.prefix}-aks-loadtest"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.loadtest_node_count
    vm_size             = var.loadtest_vm_size
    vnet_subnet_id      = azurerm_subnet.aks_loadtest.id
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = var.loadtest_min_count
    max_count           = var.loadtest_max_count
    os_disk_size_gb     = 100
    os_disk_type        = "Managed"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = var.loadtest_service_cidr
    dns_service_ip    = var.loadtest_dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  azure_policy_enabled = true

  tags = merge(var.common_tags, {
    Component = "AKS LoadTest"
  })
}

# Role Assignments for ACR
resource "azurerm_role_assignment" "aks_primary_acr" {
  principal_id                     = azurerm_kubernetes_cluster.primary.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_secondary_acr" {
  principal_id                     = azurerm_kubernetes_cluster.secondary.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_loadtest_acr" {
  principal_id                     = azurerm_kubernetes_cluster.loadtest.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.prefix}-appinsights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = merge(var.common_tags, {
    Component = "Monitoring"
  })
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-lb-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(var.common_tags, {
    Component = "Networking"
  })
}
