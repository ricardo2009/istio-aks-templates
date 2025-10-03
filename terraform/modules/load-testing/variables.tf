# ===============================================================================
# LOAD TESTING MODULE - VARIABLES
# ===============================================================================

variable "cluster" {
  description = "Configuração do cluster de load testing"
  type = object({
    host                   = string
    client_certificate     = string
    client_key            = string
    cluster_ca_certificate = string
  })
}

variable "target_rps" {
  description = "RPS alvo para load testing"
  type        = number
  default     = 600000
  
  validation {
    condition     = var.target_rps >= 1000 && var.target_rps <= 1000000
    error_message = "Target RPS deve estar entre 1000 e 1000000."
  }
}

variable "test_duration" {
  description = "Duração do teste de carga"
  type        = string
  default     = "10m"
  
  validation {
    condition     = can(regex("^[0-9]+[smh]$", var.test_duration))
    error_message = "Test duration deve estar no formato '10m', '30s', '1h', etc."
  }
}

variable "ramp_up_duration" {
  description = "Duração do ramp-up do teste de carga"
  type        = string
  default     = "2m"
  
  validation {
    condition     = can(regex("^[0-9]+[smh]$", var.ramp_up_duration))
    error_message = "Ramp up duration deve estar no formato '2m', '30s', '1h', etc."
  }
}

variable "target_endpoints" {
  description = "Endpoints alvo para load testing"
  type = object({
    primary_gateway   = string
    secondary_gateway = string
    apim_gateway     = string
  })
}

variable "enable_k6" {
  description = "Habilitar K6 load testing"
  type        = bool
  default     = true
}

variable "enable_artillery" {
  description = "Habilitar Artillery load testing"
  type        = bool
  default     = true
}

variable "enable_custom" {
  description = "Habilitar custom load generator"
  type        = bool
  default     = true
}

variable "prometheus_endpoint" {
  description = "Endpoint do Prometheus para métricas"
  type        = string
  default     = "http://prometheus-server.monitoring.svc.cluster.local:80/api/v1/write"
}

variable "k6_replicas" {
  description = "Número de réplicas K6"
  type        = number
  default     = 50
  
  validation {
    condition     = var.k6_replicas >= 1 && var.k6_replicas <= 200
    error_message = "K6 replicas deve estar entre 1 e 200."
  }
}

variable "artillery_replicas" {
  description = "Número de réplicas Artillery"
  type        = number
  default     = 30
  
  validation {
    condition     = var.artillery_replicas >= 1 && var.artillery_replicas <= 100
    error_message = "Artillery replicas deve estar entre 1 e 100."
  }
}

variable "custom_replicas" {
  description = "Número de réplicas do custom load generator"
  type        = number
  default     = 20
  
  validation {
    condition     = var.custom_replicas >= 1 && var.custom_replicas <= 100
    error_message = "Custom replicas deve estar entre 1 e 100."
  }
}

variable "enable_600k_job" {
  description = "Habilitar job de teste de 600k RPS"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Habilitar monitoramento de load testing"
  type        = bool
  default     = true
}

variable "resource_requests" {
  description = "Resource requests para pods de load testing"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "1000m"
    memory = "1Gi"
  }
}

variable "resource_limits" {
  description = "Resource limits para pods de load testing"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "4000m"
    memory = "4Gi"
  }
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
