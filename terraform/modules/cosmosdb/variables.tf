# ===============================================================================
# COSMOSDB MODULE - VARIABLES
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

variable "consistency_level" {
  description = "Nível de consistência do CosmosDB"
  type        = string
  default     = "Session"
  
  validation {
    condition = contains([
      "BoundedStaleness", "Eventual", "Session", "Strong", "ConsistentPrefix"
    ], var.consistency_level)
    error_message = "Consistency level deve ser um valor válido."
  }
}

variable "max_interval_in_seconds" {
  description = "Intervalo máximo em segundos para BoundedStaleness"
  type        = number
  default     = 300
  
  validation {
    condition     = var.max_interval_in_seconds >= 5 && var.max_interval_in_seconds <= 86400
    error_message = "Max interval deve estar entre 5 e 86400 segundos."
  }
}

variable "max_staleness_prefix" {
  description = "Prefixo máximo de staleness para BoundedStaleness"
  type        = number
  default     = 100000
  
  validation {
    condition     = var.max_staleness_prefix >= 10 && var.max_staleness_prefix <= 2147483647
    error_message = "Max staleness prefix deve estar entre 10 e 2147483647."
  }
}

variable "failover_locations" {
  description = "Localizações de failover para CosmosDB"
  type = list(object({
    location          = string
    failover_priority = number
    zone_redundant    = bool
  }))
  default = [
    {
      location          = "West US 3"
      failover_priority = 0
      zone_redundant    = true
    },
    {
      location          = "East US 2"
      failover_priority = 1
      zone_redundant    = true
    }
  ]
}

variable "databases" {
  description = "Configuração dos bancos de dados CosmosDB"
  type = map(object({
    throughput = number
    containers = map(object({
      partition_key_path = string
      throughput        = number
    }))
  }))
  default = {
    "ecommerce" = {
      throughput = 1000
      containers = {
        "users" = {
          partition_key_path = "/userId"
          throughput        = 400
        }
        "orders" = {
          partition_key_path = "/customerId"
          throughput        = 400
        }
        "products" = {
          partition_key_path = "/categoryId"
          throughput        = 400
        }
        "payments" = {
          partition_key_path = "/orderId"
          throughput        = 400
        }
      }
    }
    "analytics" = {
      throughput = 800
      containers = {
        "events" = {
          partition_key_path = "/eventType"
          throughput        = 400
        }
        "metrics" = {
          partition_key_path = "/metricName"
          throughput        = 400
        }
      }
    }
  }
}

variable "backup_type" {
  description = "Tipo de backup do CosmosDB"
  type        = string
  default     = "Periodic"
  
  validation {
    condition = contains([
      "Periodic", "Continuous"
    ], var.backup_type)
    error_message = "Backup type deve ser Periodic ou Continuous."
  }
}

variable "backup_interval_in_minutes" {
  description = "Intervalo de backup em minutos"
  type        = number
  default     = 240
  
  validation {
    condition     = var.backup_interval_in_minutes >= 60 && var.backup_interval_in_minutes <= 1440
    error_message = "Backup interval deve estar entre 60 e 1440 minutos."
  }
}

variable "backup_retention_in_hours" {
  description = "Retenção de backup em horas"
  type        = number
  default     = 720
  
  validation {
    condition     = var.backup_retention_in_hours >= 8 && var.backup_retention_in_hours <= 8760
    error_message = "Backup retention deve estar entre 8 e 8760 horas."
  }
}

variable "enable_virtual_network_filter" {
  description = "Habilitar filtro de rede virtual"
  type        = bool
  default     = true
}

variable "virtual_network_rules" {
  description = "Regras de rede virtual"
  type = list(object({
    id                                   = string
    ignore_missing_vnet_service_endpoint = bool
  }))
  default = []
}

variable "enable_analytical_storage" {
  description = "Habilitar analytical storage"
  type        = bool
  default     = true
}

variable "enable_free_tier" {
  description = "Habilitar free tier"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "ID do Log Analytics Workspace para diagnósticos"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
