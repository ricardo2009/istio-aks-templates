# Enterprise Istio on AKS - Main Terraform Configuration
# This is the root module that orchestrates all infrastructure components

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  # Uncomment and configure for production use
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "terraformstatestorage"
  #   container_name       = "tfstate"
  #   key                  = "istio-aks-production.tfstate"
  # }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Configure the Azure AD Provider
provider "azuread" {}

# Data sources
data "azurerm_client_config" "current" {}

# Local values
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    CreatedBy   = "Terraform"
    CreatedAt   = timestamp()
  }
}

# Azure Infrastructure Module
module "azure_infrastructure" {
  source = "./modules/azure-infrastructure"

  # Basic Configuration
  resource_group_name = var.resource_group_name
  location           = var.location
  prefix             = var.prefix
  environment        = var.environment

  # Network Configuration
  vnet_address_space                     = var.vnet_address_space
  aks_primary_subnet_address_prefix      = var.aks_primary_subnet_address_prefix
  aks_secondary_subnet_address_prefix    = var.aks_secondary_subnet_address_prefix
  aks_loadtest_subnet_address_prefix     = var.aks_loadtest_subnet_address_prefix
  apim_subnet_address_prefix             = var.apim_subnet_address_prefix

  # AKS Configuration
  kubernetes_version = var.kubernetes_version
  
  # Primary AKS Cluster
  aks_primary_node_count = var.aks_primary_node_count
  aks_primary_vm_size    = var.aks_primary_vm_size
  aks_primary_min_count  = var.aks_primary_min_count
  aks_primary_max_count  = var.aks_primary_max_count
  aks_service_cidr       = var.aks_service_cidr
  aks_dns_service_ip     = var.aks_dns_service_ip

  # Secondary AKS Cluster
  aks_secondary_node_count = var.aks_secondary_node_count
  aks_secondary_vm_size    = var.aks_secondary_vm_size
  aks_secondary_min_count  = var.aks_secondary_min_count
  aks_secondary_max_count  = var.aks_secondary_max_count
  aks_service_cidr_secondary = var.aks_service_cidr_secondary
  aks_dns_service_ip_secondary = var.aks_dns_service_ip_secondary

  # Monitoring
  log_analytics_retention_days = var.log_analytics_retention_days

  # Tags
  common_tags = local.common_tags
}

# Security Module (Azure Key Vault)
module "security" {
  source = "./modules/security"

  resource_group_name = module.azure_infrastructure.resource_group_name
  location           = var.location
  prefix             = var.prefix
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id

  # AKS Integration
  aks_primary_principal_id   = module.azure_infrastructure.aks_primary_principal_id
  aks_secondary_principal_id = module.azure_infrastructure.aks_secondary_principal_id

  common_tags = local.common_tags


}

# API Management Module
module "apim" {
  source = "./modules/apim"

  resource_group_name = module.azure_infrastructure.resource_group_name
  location           = var.location
  prefix             = var.prefix
  
  # Network Configuration
  subnet_id = module.azure_infrastructure.apim_subnet_id
  
  # AKS Integration
  aks_primary_fqdn   = module.azure_infrastructure.aks_primary_fqdn
  aks_secondary_fqdn = module.azure_infrastructure.aks_secondary_fqdn

  # Monitoring
  application_insights_id = module.azure_infrastructure.application_insights_id

  common_tags = local.common_tags


}

# CosmosDB Module
module "cosmosdb" {
  source = "./modules/cosmosdb"

  resource_group_name = module.azure_infrastructure.resource_group_name
  location           = var.location
  prefix             = var.prefix
  
  # Multi-region Configuration
  failover_locations = var.cosmosdb_failover_locations
  
  # Performance Configuration
  throughput = var.cosmosdb_throughput

  common_tags = local.common_tags


}

# Load Testing Module
module "load_testing" {
  source = "./modules/load-testing"

  resource_group_name = module.azure_infrastructure.resource_group_name
  location           = var.location
  prefix             = var.prefix
  
  # Network Configuration
  subnet_id = module.azure_infrastructure.aks_loadtest_subnet_id
  
  # Performance Configuration
  node_count = var.loadtest_node_count
  vm_size    = var.loadtest_vm_size

  common_tags = local.common_tags


}

## NGINX and KEDA Module
module "nginx_keda" {
  source = "./modules/nginx-keda"

  # Cluster Configuration
  cluster = {
    host                   = module.azure_infrastructure.aks_primary_host
    client_certificate     = module.azure_infrastructure.aks_primary_client_certificate
    client_key            = module.azure_infrastructure.aks_primary_client_key
    cluster_ca_certificate = module.azure_infrastructure.aks_primary_cluster_ca_certificate
  }

}

# Cross-Cluster Communication Module
module "cross_cluster" {
  source = "./modules/cross-cluster"

  # Primary Cluster Configuration
  primary_cluster_name           = module.azure_infrastructure.aks_primary_name
  primary_cluster_resource_group = module.azure_infrastructure.resource_group_name
  primary_cluster_endpoint       = module.azure_infrastructure.aks_primary_fqdn

  # Secondary Cluster Configuration
  secondary_cluster_name           = module.azure_infrastructure.aks_secondary_name
  secondary_cluster_resource_group = module.azure_infrastructure.resource_group_name
  secondary_cluster_endpoint       = module.azure_infrastructure.aks_secondary_fqdn

}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = module.azure_infrastructure.resource_group_name
  location           = var.location
  prefix             = var.prefix

  # AKS Integration
  aks_primary_name   = module.azure_infrastructure.aks_primary_name
  aks_secondary_name = module.azure_infrastructure.aks_secondary_name
  
  # Log Analytics Integration
  log_analytics_workspace_id = module.azure_infrastructure.log_analytics_workspace_id

  common_tags = local.common_tags

}
