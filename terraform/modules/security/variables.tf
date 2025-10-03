# ===============================================================================
# SECURITY MODULE - VARIABLES
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

variable "tenant_id" {
  description = "Tenant ID do Azure AD"
  type        = string
}

variable "key_vault_sku" {
  description = "SKU do Key Vault"
  type        = string
  default     = "premium"
  
  validation {
    condition = contains([
      "standard", "premium"
    ], var.key_vault_sku)
    error_message = "Key Vault SKU deve ser 'standard' ou 'premium'."
  }
}

variable "enable_soft_delete" {
  description = "Habilitar soft delete no Key Vault"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Dias de retenção para soft delete"
  type        = number
  default     = 90
  
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "Soft delete retention deve estar entre 7 e 90 dias."
  }
}

variable "enable_purge_protection" {
  description = "Habilitar purge protection no Key Vault"
  type        = bool
  default     = true
}

variable "certificate_validity_months" {
  description = "Validade dos certificados em meses"
  type        = number
  default     = 24
  
  validation {
    condition     = var.certificate_validity_months >= 1 && var.certificate_validity_months <= 36
    error_message = "Certificate validity deve estar entre 1 e 36 meses."
  }
}

variable "clusters" {
  description = "Informações dos clusters AKS para configuração de acesso"
  type = map(object({
    id                         = string
    name                       = string
    identity_principal_id      = string
    kubelet_identity_object_id = string
    subnet_id                  = string
  }))
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
