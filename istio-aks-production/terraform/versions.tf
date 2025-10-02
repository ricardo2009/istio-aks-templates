# ===============================================================================
# ISTIO AKS PRODUCTION ENVIRONMENT - PROVIDER VERSIONS
# ===============================================================================
# Definições de versões dos providers para garantir compatibilidade
# ===============================================================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    # Azure Resource Manager Provider
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80.0"
    }
    
    # Azure Active Directory Provider
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45.0"
    }
    
    # Kubernetes Provider
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    
    # Helm Provider
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11.0"
    }
    
    # Kubectl Provider (for advanced Kubernetes resources)
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
    
    # Random Provider (for generating random values)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
    
    # Time Provider (for time-based resources)
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.0"
    }
    
    # TLS Provider (for certificate generation)
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
    
    # HTTP Provider (for HTTP requests and data sources)
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4.0"
    }
    
    # Local Provider (for local file operations)
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    
    # Null Provider (for null resources and provisioners)
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
  
  # Backend configuration for production state management
  # This should be configured via backend config file or CLI
  # Example: terraform init -backend-config="backend.conf"
  backend "azurerm" {
    # Configuration will be provided via backend config file
    # resource_group_name  = "rg-terraform-state-prod"
    # storage_account_name = "saterraformstateprod"
    # container_name       = "tfstate"
    # key                  = "istio-aks-production.tfstate"
  }
}

# ===============================================================================
# PROVIDER CONFIGURATIONS
# ===============================================================================

# Configure the Azure Provider
provider "azurerm" {
  features {
    # Resource Group features
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    # Key Vault features
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    
    # Virtual Machine features
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
    
    # Cognitive Services features
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    
    # Template Deployment features
    template_deployment {
      delete_nested_items_during_deletion = true
    }
    
    # Log Analytics features
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
  }
  
  # Skip provider registration for faster deployments
  # Only enable if you have proper permissions
  skip_provider_registration = false
  
  # Storage use AzureAD for authentication
  storage_use_azuread = true
}

# Configure the Azure Active Directory Provider
provider "azuread" {
  # Use the same tenant as AzureRM provider
}

# Configure the Random Provider
provider "random" {
  # No specific configuration needed
}

# Configure the Time Provider
provider "time" {
  # No specific configuration needed
}

# Configure the TLS Provider
provider "tls" {
  # No specific configuration needed
}

# Configure the HTTP Provider
provider "http" {
  # No specific configuration needed
}

# Configure the Local Provider
provider "local" {
  # No specific configuration needed
}

# Configure the Null Provider
provider "null" {
  # No specific configuration needed
}

# ===============================================================================
# DYNAMIC PROVIDER CONFIGURATIONS
# ===============================================================================
# These providers are configured dynamically based on cluster information

# Kubernetes Provider for Primary Cluster
provider "kubernetes" {
  alias = "primary"
  
  host                   = module.azure_infrastructure.clusters.primary.host
  client_certificate     = base64decode(module.azure_infrastructure.clusters.primary.client_certificate)
  client_key            = base64decode(module.azure_infrastructure.clusters.primary.client_key)
  cluster_ca_certificate = base64decode(module.azure_infrastructure.clusters.primary.cluster_ca_certificate)
}

# Kubernetes Provider for Secondary Cluster
provider "kubernetes" {
  alias = "secondary"
  
  host                   = module.azure_infrastructure.clusters.secondary.host
  client_certificate     = base64decode(module.azure_infrastructure.clusters.secondary.client_certificate)
  client_key            = base64decode(module.azure_infrastructure.clusters.secondary.client_key)
  cluster_ca_certificate = base64decode(module.azure_infrastructure.clusters.secondary.cluster_ca_certificate)
}

# Kubernetes Provider for Load Testing Cluster
provider "kubernetes" {
  alias = "loadtest"
  
  host                   = module.azure_infrastructure.clusters.loadtest.host
  client_certificate     = base64decode(module.azure_infrastructure.clusters.loadtest.client_certificate)
  client_key            = base64decode(module.azure_infrastructure.clusters.loadtest.client_key)
  cluster_ca_certificate = base64decode(module.azure_infrastructure.clusters.loadtest.cluster_ca_certificate)
}

# Helm Provider for Primary Cluster
provider "helm" {
  alias = "primary"
  
  kubernetes {
    host                   = module.azure_infrastructure.clusters.primary.host
    client_certificate     = base64decode(module.azure_infrastructure.clusters.primary.client_certificate)
    client_key            = base64decode(module.azure_infrastructure.clusters.primary.client_key)
    cluster_ca_certificate = base64decode(module.azure_infrastructure.clusters.primary.cluster_ca_certificate)
  }
}

# Helm Provider for Secondary Cluster
provider "helm" {
  alias = "secondary"
  
  kubernetes {
    host                   = module.azure_infrastructure.clusters.secondary.host
    client_certificate     = base64decode(module.azure_infrastructure.clusters.secondary.client_certificate)
    client_key            = base64decode(module.azure_infrastructure.clusters.secondary.client_key)
    cluster_ca_certificate = base64decode(module.azure_infrastructure.clusters.secondary.cluster_ca_certificate)
  }
}

# Helm Provider for Load Testing Cluster
provider "helm" {
  alias = "loadtest"
  
  kubernetes {
    host                   = module.azure_infrastructure.clusters.loadtest.host
    client_certificate     = base64decode(module.azure_infrastructure.clusters.loadtest.client_certificate)
    client_key            = base64decode(module.azure_infrastructure.clusters.loadtest.client_key)
    cluster_ca_certificate = base64decode(module.azure_infrastructure.clusters.loadtest.cluster_ca_certificate)
  }
}

# Kubectl Provider for Primary Cluster
provider "kubectl" {
  alias = "primary"
  
  host                   = module.azure_infrastructure.clusters.primary.host
  client_certificate     = base64decode(module.azure_infrastructure.clusters.primary.client_certificate)
  client_key            = base64decode(module.azure_infrastructure.clusters.primary.client_key)
  cluster_ca_certificate = base64decode(module.azure_infrastructure.clusters.primary.cluster_ca_certificate)
  load_config_file       = false
}

# Kubectl Provider for Secondary Cluster
provider "kubectl" {
  alias = "secondary"
  
  host                   = module.azure_infrastructure.clusters.secondary.host
  client_certificate     = base64decode(module.azure_infrastructure.clusters.secondary.client_certificate)
  client_key            = base64decode(module.azure_infrastructure.clusters.secondary.client_key)
  cluster_ca_certificate = base64decode(module.azure_infrastructure.clusters.secondary.cluster_ca_certificate)
  load_config_file       = false
}

# Kubectl Provider for Load Testing Cluster
provider "kubectl" {
  alias = "loadtest"
  
  host                   = module.azure_infrastructure.clusters.loadtest.host
  client_certificate     = base64decode(module.azure_infrastructure.clusters.loadtest.client_certificate)
  client_key            = base64decode(module.azure_infrastructure.clusters.loadtest.client_key)
  cluster_ca_certificate = base64decode(module.azure_infrastructure.clusters.loadtest.cluster_ca_certificate)
  load_config_file       = false
}
