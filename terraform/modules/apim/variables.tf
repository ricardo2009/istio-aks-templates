# ===============================================================================
# AZURE API MANAGEMENT MODULE - VARIABLES
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

variable "sku_name" {
  description = "SKU do Azure API Management"
  type        = string
  default     = "Premium_1"
  
  validation {
    condition = contains([
      "Developer_1", "Standard_1", "Standard_2", 
      "Premium_1", "Premium_2", "Premium_4", "Premium_8"
    ], var.sku_name)
    error_message = "APIM SKU deve ser um valor válido."
  }
}

variable "capacity" {
  description = "Capacidade do Azure API Management"
  type        = number
  default     = 1
  
  validation {
    condition     = var.capacity >= 1 && var.capacity <= 12
    error_message = "APIM capacity deve estar entre 1 e 12."
  }
}

variable "publisher_name" {
  description = "Nome do publisher do APIM"
  type        = string
}

variable "publisher_email" {
  description = "Email do publisher do APIM"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.publisher_email))
    error_message = "Publisher email deve ser um endereço de email válido."
  }
}

variable "virtual_network_type" {
  description = "Tipo de configuração de rede virtual"
  type        = string
  default     = "Internal"
  
  validation {
    condition = contains([
      "None", "External", "Internal"
    ], var.virtual_network_type)
    error_message = "Virtual network type deve ser None, External ou Internal."
  }
}

variable "subnet_id" {
  description = "ID da subnet para APIM (obrigatório se virtual_network_type não for None)"
  type        = string
  default     = null
}

variable "key_vault_id" {
  description = "ID do Key Vault para integração de certificados"
  type        = string
}

variable "cluster_endpoints" {
  description = "Endpoints dos clusters AKS para configuração de backend"
  type = object({
    primary   = string
    secondary = string
  })
}

variable "enable_application_insights" {
  description = "Habilitar Application Insights para APIM"
  type        = bool
  default     = true
}

variable "enable_developer_portal" {
  description = "Habilitar portal do desenvolvedor"
  type        = bool
  default     = true
}

variable "custom_domain" {
  description = "Domínio customizado para APIM"
  type        = string
  default     = ""
}

variable "ssl_certificate_name" {
  description = "Nome do certificado SSL no Key Vault"
  type        = string
  default     = "gateway-tls-cert"
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
