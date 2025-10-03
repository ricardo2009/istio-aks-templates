# ===============================================================================
# MONITORING & OBSERVABILITY MODULE - VARIABLES
# ===============================================================================

variable "cluster_config" {
  description = "Configuração do cluster Kubernetes"
  type = object({
    host                   = string
    client_certificate     = string
    client_key            = string
    cluster_ca_certificate = string
  })
}

variable "cluster_name" {
  description = "Nome do cluster AKS"
  type        = string
  default     = "primary"
}

variable "namespace" {
  description = "Namespace para componentes de monitoramento"
  type        = string
  default     = "monitoring"
}

# Prometheus Configuration
variable "prometheus_enabled" {
  description = "Habilitar Prometheus"
  type        = bool
  default     = true
}

variable "prometheus_retention" {
  description = "Período de retenção do Prometheus"
  type        = string
  default     = "30d"
}

variable "prometheus_storage_size" {
  description = "Tamanho do storage do Prometheus"
  type        = string
  default     = "50Gi"
}

# Grafana Configuration
variable "grafana_enabled" {
  description = "Habilitar Grafana"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Senha do admin do Grafana"
  type        = string
  default     = "admin123"
  sensitive   = true
}

# Jaeger Configuration
variable "jaeger_enabled" {
  description = "Habilitar Jaeger"
  type        = bool
  default     = true
}

variable "jaeger_storage_type" {
  description = "Tipo de storage do Jaeger"
  type        = string
  default     = "memory"
  
  validation {
    condition     = contains(["memory", "elasticsearch", "cassandra"], var.jaeger_storage_type)
    error_message = "Jaeger storage type deve ser memory, elasticsearch ou cassandra."
  }
}

# Alerting Configuration
variable "alertmanager_enabled" {
  description = "Habilitar AlertManager"
  type        = bool
  default     = true
}

variable "alert_webhook_url" {
  description = "URL do webhook para alertas"
  type        = string
  default     = ""
}

# Azure Monitor Integration
variable "azure_monitor_enabled" {
  description = "Habilitar integração com Azure Monitor"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "ID do Log Analytics Workspace"
  type        = string
  default     = ""
}

# Resource Configuration
variable "monitoring_resources" {
  description = "Recursos para componentes de monitoramento"
  type = object({
    prometheus = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    grafana = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
  })
  default = {
    prometheus = {
      requests = {
        cpu    = "500m"
        memory = "2Gi"
      }
      limits = {
        cpu    = "2000m"
        memory = "8Gi"
      }
    }
    grafana = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "1Gi"
      }
    }
  }
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
