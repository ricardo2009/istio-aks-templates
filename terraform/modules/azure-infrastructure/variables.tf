# ===============================================================================
# AZURE INFRASTRUCTURE MODULE - VARIABLES
# ===============================================================================

variable "resource_group_name" {
  description = "Nome do Resource Group"
  type        = string
}

variable "location" {
  description = "Localização dos recursos Azure"
  type        = string
}

variable "resource_prefix" {
  description = "Prefixo para nomeação dos recursos"
  type        = string
}

variable "vnet_address_space" {
  description = "Espaço de endereçamento da VNet"
  type        = list(string)
}

variable "clusters" {
  description = "Configuração dos clusters AKS"
  type = map(object({
    name               = string
    subnet_cidr        = string
    node_count         = number
    vm_size           = string
    max_pods          = number
    availability_zones = list(string)
    workloads         = list(string)
  }))
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes"
  type        = string
}

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

variable "enable_pod_security_policy" {
  description = "Habilitar Pod Security Policy"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_sku" {
  description = "SKU do Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
