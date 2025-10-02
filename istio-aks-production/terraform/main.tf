# ===============================================================================
# ISTIO AKS PRODUCTION ENVIRONMENT - MAIN CONFIGURATION
# ===============================================================================
# Solução empresarial completa com 3 clusters AKS, APIM, CosmosDB e load testing
# Capacidade: 600k RPS com alta disponibilidade e resiliência
# ===============================================================================

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  # Backend configuration for production state management
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-prod"
    storage_account_name = "saterraformstateprod"
    container_name       = "tfstate"
    key                  = "istio-aks-production.tfstate"
  }
}

# ===============================================================================
# PROVIDER CONFIGURATIONS
# ===============================================================================

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

# Data sources for existing resources
data "azurerm_client_config" "current" {}

# ===============================================================================
# LOCAL VALUES
# ===============================================================================

locals {
  # Environment configuration
  environment = "production"
  project     = "istio-aks"
  
  # Resource naming convention
  resource_prefix = "${local.project}-${local.environment}"
  
  # Common tags for all resources
  common_tags = {
    Environment   = local.environment
    Project       = local.project
    ManagedBy     = "terraform"
    Owner         = var.owner
    CostCenter    = var.cost_center
    CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
  }
  
  # Network configuration
  vnet_address_space = ["10.0.0.0/8"]
  
  # Cluster configurations
  clusters = {
    primary = {
      name                = "${local.resource_prefix}-primary"
      subnet_cidr         = "10.1.0.0/16"
      node_count          = var.primary_cluster_node_count
      vm_size             = var.primary_cluster_vm_size
      max_pods            = 110
      availability_zones  = ["1", "2", "3"]
      workloads          = ["frontend", "api-gateway", "user-service"]
    }
    secondary = {
      name                = "${local.resource_prefix}-secondary"
      subnet_cidr         = "10.2.0.0/16"
      node_count          = var.secondary_cluster_node_count
      vm_size             = var.secondary_cluster_vm_size
      max_pods            = 110
      availability_zones  = ["1", "2", "3"]
      workloads          = ["order-service", "payment-service", "notification-service"]
    }
    loadtest = {
      name                = "${local.resource_prefix}-loadtest"
      subnet_cidr         = "10.3.0.0/16"
      node_count          = var.loadtest_cluster_node_count
      vm_size             = var.loadtest_cluster_vm_size
      max_pods            = 250
      availability_zones  = ["1", "2", "3"]
      workloads          = ["load-generators", "monitoring-tools"]
    }
  }
}

# ===============================================================================
# AZURE INFRASTRUCTURE MODULE
# ===============================================================================

module "azure_infrastructure" {
  source = "./modules/azure-infrastructure"
  
  # Basic configuration
  resource_group_name = var.resource_group_name
  location           = var.location
  resource_prefix    = local.resource_prefix
  
  # Network configuration
  vnet_address_space = local.vnet_address_space
  clusters          = local.clusters
  
  # AKS configuration
  kubernetes_version = var.kubernetes_version
  enable_istio      = true
  enable_monitoring = true
  
  # Security configuration
  enable_rbac                = true
  enable_azure_policy        = true
  enable_pod_security_policy = true
  
  # Monitoring configuration
  log_analytics_workspace_sku = "PerGB2018"
  
  # Tags
  tags = local.common_tags
}

# ===============================================================================
# SECURITY MODULE
# ===============================================================================

module "security" {
  source = "./modules/security"
  
  # Dependencies
  depends_on = [module.azure_infrastructure]
  
  # Basic configuration
  resource_group_name = module.azure_infrastructure.resource_group_name
  location           = var.location
  resource_prefix    = local.resource_prefix
  
  # Key Vault configuration
  key_vault_sku                    = "premium"
  enable_soft_delete              = true
  soft_delete_retention_days      = 90
  enable_purge_protection         = true
  
  # Certificate configuration
  certificate_validity_months = 24
  
  # Cluster information for RBAC
  clusters = {
    primary   = module.azure_infrastructure.clusters.primary
    secondary = module.azure_infrastructure.clusters.secondary
    loadtest  = module.azure_infrastructure.clusters.loadtest
  }
  
  # Service principal information
  tenant_id = data.azurerm_client_config.current.tenant_id
  
  # Tags
  tags = local.common_tags
}

# ===============================================================================
# AZURE API MANAGEMENT MODULE
# ===============================================================================

module "apim" {
  source = "./modules/apim"
  
  # Dependencies
  depends_on = [module.azure_infrastructure, module.security]
  
  # Basic configuration
  resource_group_name = module.azure_infrastructure.resource_group_name
  location           = var.location
  resource_prefix    = local.resource_prefix
  
  # APIM configuration
  sku_name     = var.apim_sku_name
  capacity     = var.apim_capacity
  
  # Publisher information
  publisher_name  = var.apim_publisher_name
  publisher_email = var.apim_publisher_email
  
  # Network configuration
  virtual_network_type = "Internal"
  subnet_id           = module.azure_infrastructure.apim_subnet_id
  
  # Security configuration
  key_vault_id = module.security.key_vault_id
  
  # Cluster endpoints for API backend
  cluster_endpoints = {
    primary   = module.azure_infrastructure.clusters.primary.fqdn
    secondary = module.azure_infrastructure.clusters.secondary.fqdn
  }
  
  # Tags
  tags = local.common_tags
}

# ===============================================================================
# COSMOSDB MODULE
# ===============================================================================

module "cosmosdb" {
  source = "./modules/cosmosdb"
  
  # Dependencies
  depends_on = [module.azure_infrastructure]
  
  # Basic configuration
  resource_group_name = module.azure_infrastructure.resource_group_name
  location           = var.location
  resource_prefix    = local.resource_prefix
  
  # CosmosDB configuration
  consistency_level       = var.cosmosdb_consistency_level
  max_interval_in_seconds = var.cosmosdb_max_interval_in_seconds
  max_staleness_prefix    = var.cosmosdb_max_staleness_prefix
  
  # Multi-region configuration
  failover_locations = var.cosmosdb_failover_locations
  
  # Database and container configuration
  databases = var.cosmosdb_databases
  
  # Backup configuration
  backup_type                = "Periodic"
  backup_interval_in_minutes = 240
  backup_retention_in_hours  = 720
  
  # Network configuration
  enable_virtual_network_filter = true
  virtual_network_rules = [
    {
      id                                   = module.azure_infrastructure.primary_subnet_id
      ignore_missing_vnet_service_endpoint = false
    },
    {
      id                                   = module.azure_infrastructure.secondary_subnet_id
      ignore_missing_vnet_service_endpoint = false
    }
  ]
  
  # Tags
  tags = local.common_tags
}

# ===============================================================================
# NGINX INGRESS CONTROLLER MODULE
# ===============================================================================

module "nginx_ingress" {
  source = "./modules/nginx-ingress"
  
  # Dependencies
  depends_on = [module.azure_infrastructure, module.security]
  
  # Cluster configurations
  clusters = {
    primary = {
      host                 = module.azure_infrastructure.clusters.primary.host
      client_certificate   = module.azure_infrastructure.clusters.primary.client_certificate
      client_key          = module.azure_infrastructure.clusters.primary.client_key
      cluster_ca_certificate = module.azure_infrastructure.clusters.primary.cluster_ca_certificate
    }
    secondary = {
      host                 = module.azure_infrastructure.clusters.secondary.host
      client_certificate   = module.azure_infrastructure.clusters.secondary.client_certificate
      client_key          = module.azure_infrastructure.clusters.secondary.client_key
      cluster_ca_certificate = module.azure_infrastructure.clusters.secondary.cluster_ca_certificate
    }
  }
  
  # NGINX configuration
  replica_count = var.nginx_replica_count
  
  # Performance configuration for 600k RPS
  worker_processes     = "auto"
  worker_connections   = 16384
  keepalive_timeout    = 65
  keepalive_requests   = 10000
  
  # SSL configuration
  ssl_protocols        = "TLSv1.2 TLSv1.3"
  ssl_ciphers         = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
  
  # Key Vault integration
  key_vault_id = module.security.key_vault_id
  
  # Tags
  tags = local.common_tags
}

# ===============================================================================
# APPLICATIONS MODULE
# ===============================================================================

module "applications" {
  source = "./modules/applications"
  
  # Dependencies
  depends_on = [
    module.azure_infrastructure,
    module.security,
    module.cosmosdb,
    module.nginx_ingress
  ]
  
  # Cluster configurations
  clusters = {
    primary = {
      host                 = module.azure_infrastructure.clusters.primary.host
      client_certificate   = module.azure_infrastructure.clusters.primary.client_certificate
      client_key          = module.azure_infrastructure.clusters.primary.client_key
      cluster_ca_certificate = module.azure_infrastructure.clusters.primary.cluster_ca_certificate
    }
    secondary = {
      host                 = module.azure_infrastructure.clusters.secondary.host
      client_certificate   = module.azure_infrastructure.clusters.secondary.client_certificate
      client_key          = module.azure_infrastructure.clusters.secondary.client_key
      cluster_ca_certificate = module.azure_infrastructure.clusters.secondary.cluster_ca_certificate
    }
  }
  
  # Application configuration
  applications = var.applications
  
  # CosmosDB connection
  cosmosdb_endpoint = module.cosmosdb.endpoint
  cosmosdb_key     = module.cosmosdb.primary_key
  
  # Container registry
  container_registry_url = var.container_registry_url
  
  # Istio configuration
  enable_istio_injection = true
  enable_mtls           = true
  
  # Tags
  tags = local.common_tags
}

# ===============================================================================
# OBSERVABILITY MODULE
# ===============================================================================

module "observability" {
  source = "./modules/observability"
  
  # Dependencies
  depends_on = [
    module.azure_infrastructure,
    module.applications
  ]
  
  # Cluster configurations
  clusters = {
    primary = {
      host                 = module.azure_infrastructure.clusters.primary.host
      client_certificate   = module.azure_infrastructure.clusters.primary.client_certificate
      client_key          = module.azure_infrastructure.clusters.primary.client_key
      cluster_ca_certificate = module.azure_infrastructure.clusters.primary.cluster_ca_certificate
    }
    secondary = {
      host                 = module.azure_infrastructure.clusters.secondary.host
      client_certificate   = module.azure_infrastructure.clusters.secondary.client_certificate
      client_key          = module.azure_infrastructure.clusters.secondary.client_key
      cluster_ca_certificate = module.azure_infrastructure.clusters.secondary.cluster_ca_certificate
    }
    loadtest = {
      host                 = module.azure_infrastructure.clusters.loadtest.host
      client_certificate   = module.azure_infrastructure.clusters.loadtest.client_certificate
      client_key          = module.azure_infrastructure.clusters.loadtest.client_key
      cluster_ca_certificate = module.azure_infrastructure.clusters.loadtest.cluster_ca_certificate
    }
  }
  
  # Azure Monitor integration
  log_analytics_workspace_id = module.azure_infrastructure.log_analytics_workspace_id
  
  # Monitoring configuration
  enable_prometheus = true
  enable_grafana   = true
  enable_jaeger    = false  # Using Azure Application Insights instead
  
  # Custom dashboards
  enable_custom_dashboards = true
  
  # Tags
  tags = local.common_tags
}

# ===============================================================================
# LOAD TESTING MODULE
# ===============================================================================

module "load_testing" {
  source = "./modules/load-testing"
  
  # Dependencies
  depends_on = [
    module.azure_infrastructure,
    module.applications,
    module.observability
  ]
  
  # Load testing cluster configuration
  cluster = {
    host                 = module.azure_infrastructure.clusters.loadtest.host
    client_certificate   = module.azure_infrastructure.clusters.loadtest.client_certificate
    client_key          = module.azure_infrastructure.clusters.loadtest.client_key
    cluster_ca_certificate = module.azure_infrastructure.clusters.loadtest.cluster_ca_certificate
  }
  
  # Load testing configuration
  target_rps           = 600000
  test_duration        = "10m"
  ramp_up_duration     = "2m"
  
  # Target endpoints
  target_endpoints = {
    primary_gateway   = module.nginx_ingress.primary_external_ip
    secondary_gateway = module.nginx_ingress.secondary_external_ip
    apim_gateway     = module.apim.gateway_url
  }
  
  # Load testing tools
  enable_k6        = true
  enable_artillery = true
  enable_custom    = true
  
  # Monitoring integration
  prometheus_endpoint = module.observability.prometheus_endpoint
  
  # Tags
  tags = local.common_tags
}
