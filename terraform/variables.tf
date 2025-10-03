# Enterprise Istio on AKS - Root Variables Configuration

# Basic Configuration
variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-istio-aks-production"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US 2"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "istio-aks-prod"
  
  validation {
    condition     = length(var.prefix) <= 15 && can(regex("^[a-z0-9-]+$", var.prefix))
    error_message = "Prefix must be 15 characters or less and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "Enterprise Istio on AKS"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "Platform Team"
}

# Network Configuration
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_primary_subnet_address_prefix" {
  description = "Address prefix for the primary AKS subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "aks_secondary_subnet_address_prefix" {
  description = "Address prefix for the secondary AKS subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "aks_loadtest_subnet_address_prefix" {
  description = "Address prefix for the load testing AKS subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "apim_subnet_address_prefix" {
  description = "Address prefix for the APIM subnet"
  type        = string
  default     = "10.0.4.0/24"
}

# AKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for AKS clusters"
  type        = string
  default     = "1.28.9"
}

# Primary AKS Cluster Configuration
variable "aks_primary_node_count" {
  description = "Initial number of nodes for primary AKS cluster"
  type        = number
  default     = 3
}

variable "aks_primary_vm_size" {
  description = "VM size for primary AKS cluster nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "aks_primary_min_count" {
  description = "Minimum number of nodes for primary AKS cluster autoscaling"
  type        = number
  default     = 2
}

variable "aks_primary_max_count" {
  description = "Maximum number of nodes for primary AKS cluster autoscaling"
  type        = number
  default     = 10
}

variable "aks_service_cidr" {
  description = "Service CIDR for primary AKS cluster"
  type        = string
  default     = "10.1.0.0/16"
}

variable "aks_dns_service_ip" {
  description = "DNS service IP for primary AKS cluster"
  type        = string
  default     = "10.1.0.10"
}

# Secondary AKS Cluster Configuration
variable "aks_secondary_node_count" {
  description = "Initial number of nodes for secondary AKS cluster"
  type        = number
  default     = 3
}

variable "aks_secondary_vm_size" {
  description = "VM size for secondary AKS cluster nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "aks_secondary_min_count" {
  description = "Minimum number of nodes for secondary AKS cluster autoscaling"
  type        = number
  default     = 2
}

variable "aks_secondary_max_count" {
  description = "Maximum number of nodes for secondary AKS cluster autoscaling"
  type        = number
  default     = 10
}

variable "aks_service_cidr_secondary" {
  description = "Service CIDR for secondary AKS cluster"
  type        = string
  default     = "10.2.0.0/16"
}

variable "aks_dns_service_ip_secondary" {
  description = "DNS service IP for secondary AKS cluster"
  type        = string
  default     = "10.2.0.10"
}

# Load Testing Configuration
variable "loadtest_node_count" {
  description = "Number of nodes for load testing cluster"
  type        = number
  default     = 5
}

variable "loadtest_vm_size" {
  description = "VM size for load testing cluster nodes"
  type        = string
  default     = "Standard_F16s_v2"
}

# CosmosDB Configuration
variable "cosmosdb_failover_locations" {
  description = "List of failover locations for CosmosDB"
  type = list(object({
    location          = string
    failover_priority = number
  }))
  default = [
    {
      location          = "East US 2"
      failover_priority = 0
    },
    {
      location          = "West US 2"
      failover_priority = 1
    }
  ]
}

variable "cosmosdb_throughput" {
  description = "Throughput for CosmosDB containers"
  type        = number
  default     = 1000
}

# Monitoring Configuration
variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 30
  
  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "Log Analytics retention must be between 30 and 730 days."
  }
}
