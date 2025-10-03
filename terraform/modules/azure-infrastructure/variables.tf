# ===============================================================================
# AZURE INFRASTRUCTURE MODULE - VARIABLES
# ===============================================================================

# Basic Configuration
variable "resource_group_name" {
  description = "Nome do Resource Group"
  type        = string
}

variable "location" {
  description = "Localização dos recursos Azure"
  type        = string
}

variable "prefix" {
  description = "Prefixo para nomeação dos recursos"
  type        = string
}

variable "environment" {
  description = "Ambiente (development, staging, production)"
  type        = string
}

# Network Configuration
variable "vnet_address_space" {
  description = "Espaço de endereçamento da VNet"
  type        = string
}

variable "aks_primary_subnet_address_prefix" {
  description = "Prefixo de endereço da subnet do cluster primário"
  type        = string
}

variable "aks_secondary_subnet_address_prefix" {
  description = "Prefixo de endereço da subnet do cluster secundário"
  type        = string
}

variable "aks_loadtest_subnet_address_prefix" {
  description = "Prefixo de endereço da subnet do cluster de load testing"
  type        = string
}

variable "apim_subnet_address_prefix" {
  description = "Prefixo de endereço da subnet do APIM"
  type        = string
}

# Kubernetes Configuration
variable "kubernetes_version" {
  description = "Versão do Kubernetes"
  type        = string
}

# Primary AKS Cluster Configuration
variable "aks_primary_node_count" {
  description = "Número inicial de nós do cluster primário"
  type        = number
}

variable "aks_primary_vm_size" {
  description = "Tamanho da VM dos nós do cluster primário"
  type        = string
}

variable "aks_primary_min_count" {
  description = "Número mínimo de nós para autoscaling do cluster primário"
  type        = number
}

variable "aks_primary_max_count" {
  description = "Número máximo de nós para autoscaling do cluster primário"
  type        = number
}

variable "aks_service_cidr" {
  description = "CIDR dos serviços do cluster primário"
  type        = string
}

variable "aks_dns_service_ip" {
  description = "IP do serviço DNS do cluster primário"
  type        = string
}

# Secondary AKS Cluster Configuration
variable "aks_secondary_node_count" {
  description = "Número inicial de nós do cluster secundário"
  type        = number
}

variable "aks_secondary_vm_size" {
  description = "Tamanho da VM dos nós do cluster secundário"
  type        = string
}

variable "aks_secondary_min_count" {
  description = "Número mínimo de nós para autoscaling do cluster secundário"
  type        = number
}

variable "aks_secondary_max_count" {
  description = "Número máximo de nós para autoscaling do cluster secundário"
  type        = number
}

variable "aks_service_cidr_secondary" {
  description = "CIDR dos serviços do cluster secundário"
  type        = string
}

variable "aks_dns_service_ip_secondary" {
  description = "IP do serviço DNS do cluster secundário"
  type        = string
}

# Load Testing Cluster Configuration
variable "loadtest_node_count" {
  description = "Número inicial de nós do cluster de load testing"
  type        = number
}

variable "loadtest_vm_size" {
  description = "Tamanho da VM dos nós do cluster de load testing"
  type        = string
}

variable "loadtest_min_count" {
  description = "Número mínimo de nós para autoscaling do cluster de load testing"
  type        = number
  default     = 2
}

variable "loadtest_max_count" {
  description = "Número máximo de nós para autoscaling do cluster de load testing"
  type        = number
  default     = 20
}

variable "loadtest_service_cidr" {
  description = "CIDR dos serviços do cluster de load testing"
  type        = string
  default     = "10.3.0.0/16"
}

variable "loadtest_dns_service_ip" {
  description = "IP do serviço DNS do cluster de load testing"
  type        = string
  default     = "10.3.0.10"
}

# Monitoring Configuration
variable "log_analytics_retention_days" {
  description = "Dias de retenção do Log Analytics"
  type        = number
}

variable "log_analytics_workspace_sku" {
  description = "SKU do Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
}

# Feature Flags
variable "enable_istio" {
  description = "Habilitar Istio service mesh"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Habilitar monitoramento"
  type        = bool
  default     = true
}

variable "enable_rbac" {
  description = "Habilitar RBAC"
  type        = bool
  default     = true
}

variable "enable_azure_policy" {
  description = "Habilitar Azure Policy"
  type        = bool
  default     = true
}

# Tags
variable "common_tags" {
  description = "Tags comuns para todos os recursos"
  type        = map(string)
  default     = {}
}
