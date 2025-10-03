# ===============================================================================
# NGINX INGRESS CONTROLLER & KEDA MODULE - VARIABLES
# ===============================================================================

variable "cluster" {
  description = "Configuração do cluster Kubernetes"
  type = object({
    host                   = string
    client_certificate     = string
    client_key            = string
    cluster_ca_certificate = string
  })
}

# ===============================================================================
# NGINX INGRESS CONTROLLER VARIABLES
# ===============================================================================

variable "nginx_chart_version" {
  description = "Versão do chart Helm do NGINX Ingress Controller"
  type        = string
  default     = "4.8.3"
}

variable "nginx_image_tag" {
  description = "Tag da imagem do NGINX Ingress Controller"
  type        = string
  default     = "v1.9.4"
}

variable "nginx_replica_count" {
  description = "Número de réplicas do NGINX Ingress Controller"
  type        = number
  default     = 3
  
  validation {
    condition     = var.nginx_replica_count >= 2 && var.nginx_replica_count <= 20
    error_message = "NGINX replica count deve estar entre 2 e 20."
  }
}

variable "nginx_resources" {
  description = "Recursos para o NGINX Ingress Controller"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "1000m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "4000m"
      memory = "4Gi"
    }
  }
}

variable "nginx_node_selector" {
  description = "Node selector para o NGINX Ingress Controller"
  type        = map(string)
  default     = {}
}

variable "nginx_tolerations" {
  description = "Tolerations para o NGINX Ingress Controller"
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default = []
}

variable "public_ip_name" {
  description = "Nome do IP público para o Load Balancer"
  type        = string
  default     = ""
}

variable "dns_label" {
  description = "Label DNS para o Load Balancer"
  type        = string
  default     = ""
}

# ===============================================================================
# KEDA VARIABLES
# ===============================================================================

variable "keda_chart_version" {
  description = "Versão do chart Helm do KEDA"
  type        = string
  default     = "2.12.1"
}

variable "keda_operator_replica_count" {
  description = "Número de réplicas do KEDA Operator"
  type        = number
  default     = 2
  
  validation {
    condition     = var.keda_operator_replica_count >= 1 && var.keda_operator_replica_count <= 5
    error_message = "KEDA operator replica count deve estar entre 1 e 5."
  }
}

variable "keda_metrics_server_replica_count" {
  description = "Número de réplicas do KEDA Metrics Server"
  type        = number
  default     = 2
  
  validation {
    condition     = var.keda_metrics_server_replica_count >= 1 && var.keda_metrics_server_replica_count <= 5
    error_message = "KEDA metrics server replica count deve estar entre 1 e 5."
  }
}

variable "keda_webhooks_replica_count" {
  description = "Número de réplicas do KEDA Webhooks"
  type        = number
  default     = 2
  
  validation {
    condition     = var.keda_webhooks_replica_count >= 1 && var.keda_webhooks_replica_count <= 5
    error_message = "KEDA webhooks replica count deve estar entre 1 e 5."
  }
}

variable "keda_operator_resources" {
  description = "Recursos para o KEDA Operator"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "keda_metrics_server_resources" {
  description = "Recursos para o KEDA Metrics Server"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
    }
  }
}

variable "keda_webhooks_resources" {
  description = "Recursos para o KEDA Webhooks"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "keda_node_selector" {
  description = "Node selector para componentes do KEDA"
  type        = map(string)
  default     = {}
}

variable "keda_tolerations" {
  description = "Tolerations para componentes do KEDA"
  type = list(object({
    key      = string
    operator = string
    value    = string
    effect   = string
  }))
  default = []
}

variable "keda_log_level" {
  description = "Nível de log para componentes do KEDA"
  type        = string
  default     = "info"
  
  validation {
    condition = contains([
      "debug", "info", "warn", "error"
    ], var.keda_log_level)
    error_message = "KEDA log level deve ser debug, info, warn ou error."
  }
}

# ===============================================================================
# MONITORING VARIABLES
# ===============================================================================

variable "enable_prometheus_monitoring" {
  description = "Habilitar monitoramento Prometheus"
  type        = bool
  default     = true
}

variable "prometheus_server_address" {
  description = "Endereço do servidor Prometheus"
  type        = string
  default     = "http://prometheus-server.monitoring.svc.cluster.local:80"
}

variable "jaeger_collector_host" {
  description = "Host do coletor Jaeger"
  type        = string
  default     = "jaeger-collector.monitoring.svc.cluster.local"
}

# ===============================================================================
# APPLICATION SCALING VARIABLES
# ===============================================================================

variable "applications_namespace" {
  description = "Namespace das aplicações"
  type        = string
  default     = "ecommerce"
}

variable "redis_address" {
  description = "Endereço do Redis para KEDA"
  type        = string
  default     = "redis-master.redis.svc.cluster.local:6379"
}

# API Gateway scaling
variable "api_gateway_min_replicas" {
  description = "Número mínimo de réplicas do API Gateway"
  type        = number
  default     = 3
}

variable "api_gateway_max_replicas" {
  description = "Número máximo de réplicas do API Gateway"
  type        = number
  default     = 50
}

# User Service scaling
variable "user_service_min_replicas" {
  description = "Número mínimo de réplicas do User Service"
  type        = number
  default     = 2
}

variable "user_service_max_replicas" {
  description = "Número máximo de réplicas do User Service"
  type        = number
  default     = 20
}

# Product Service scaling
variable "product_service_min_replicas" {
  description = "Número mínimo de réplicas do Product Service"
  type        = number
  default     = 3
}

variable "product_service_max_replicas" {
  description = "Número máximo de réplicas do Product Service"
  type        = number
  default     = 30
}

# Order Service scaling
variable "order_service_min_replicas" {
  description = "Número mínimo de réplicas do Order Service"
  type        = number
  default     = 2
}

variable "order_service_max_replicas" {
  description = "Número máximo de réplicas do Order Service"
  type        = number
  default     = 25
}

# Payment Service scaling
variable "payment_service_min_replicas" {
  description = "Número mínimo de réplicas do Payment Service"
  type        = number
  default     = 2
}

variable "payment_service_max_replicas" {
  description = "Número máximo de réplicas do Payment Service"
  type        = number
  default     = 15
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
