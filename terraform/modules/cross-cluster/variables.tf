# ===============================================================================
# CROSS-CLUSTER COMMUNICATION MODULE - VARIABLES
# ===============================================================================

# ===============================================================================
# CLUSTER CONFIGURATION
# ===============================================================================

variable "primary_cluster" {
  description = "Configuração do cluster primário"
  type = object({
    name         = string
    region       = string
    network      = string
    mesh_id      = string
    cluster_name = string
  })
}

variable "secondary_cluster" {
  description = "Configuração do cluster secundário"
  type = object({
    name         = string
    region       = string
    network      = string
    mesh_id      = string
    cluster_name = string
  })
}

variable "loadtest_cluster" {
  description = "Configuração do cluster de load testing"
  type = object({
    name         = string
    region       = string
    network      = string
    mesh_id      = string
    cluster_name = string
  })
}

# ===============================================================================
# ISTIO CONFIGURATION
# ===============================================================================

variable "istio_revision" {
  description = "Revisão do Istio para multi-cluster"
  type        = string
  default     = "default"
}

variable "mesh_id" {
  description = "ID único do mesh Istio"
  type        = string
  default     = "mesh1"
}

variable "trust_domain" {
  description = "Domínio de confiança do Istio"
  type        = string
  default     = "cluster.local"
}

# ===============================================================================
# CLUSTER ACCESS CONFIGURATION
# ===============================================================================

variable "cluster_ca_certificates" {
  description = "Certificados CA dos clusters para acesso cross-cluster"
  type        = map(string)
  sensitive   = true
}

variable "cluster_tokens" {
  description = "Tokens de acesso aos clusters"
  type        = map(string)
  sensitive   = true
}

variable "cluster_endpoints" {
  description = "Endpoints dos clusters para comunicação cross-cluster"
  type = map(object({
    api_server_url    = string
    discovery_address = string
    eastwest_gateway  = string
  }))
}

# ===============================================================================
# CROSS-CLUSTER SERVICES CONFIGURATION
# ===============================================================================

variable "cross_cluster_services" {
  description = "Configuração dos serviços cross-cluster"
  type = map(object({
    service_name       = string
    namespace          = string
    port              = number
    protocol          = string
    clusters          = list(string)
    traffic_distribution = list(number)
    address_suffix    = number
    service_account   = string
    allowed_methods   = list(string)
  }))
  default = {
    user-service = {
      service_name       = "user-service"
      namespace          = "ecommerce"
      port              = 80
      protocol          = "http"
      clusters          = ["primary", "secondary"]
      traffic_distribution = [70, 30]
      address_suffix    = 1
      service_account   = "user-service"
      allowed_methods   = ["GET", "POST", "PUT", "DELETE"]
    }
    product-service = {
      service_name       = "product-service"
      namespace          = "ecommerce"
      port              = 80
      protocol          = "http"
      clusters          = ["primary", "secondary"]
      traffic_distribution = [60, 40]
      address_suffix    = 2
      service_account   = "product-service"
      allowed_methods   = ["GET", "POST", "PUT", "DELETE"]
    }
    order-service = {
      service_name       = "order-service"
      namespace          = "ecommerce"
      port              = 80
      protocol          = "http"
      clusters          = ["primary", "secondary"]
      traffic_distribution = [80, 20]
      address_suffix    = 3
      service_account   = "order-service"
      allowed_methods   = ["GET", "POST", "PUT", "PATCH"]
    }
    payment-service = {
      service_name       = "payment-service"
      namespace          = "ecommerce"
      port              = 80
      protocol          = "http"
      clusters          = ["primary"]
      traffic_distribution = [100]
      address_suffix    = 4
      service_account   = "payment-service"
      allowed_methods   = ["POST", "GET"]
    }
  }
}

variable "cross_cluster_namespaces" {
  description = "Namespaces que participam da comunicação cross-cluster"
  type        = list(string)
  default     = ["ecommerce", "monitoring", "istio-system"]
}

# ===============================================================================
# NETWORK CONFIGURATION
# ===============================================================================

variable "network_config" {
  description = "Configuração de rede para cross-cluster"
  type = object({
    enable_network_policies = bool
    allowed_cidr_blocks    = list(string)
    dns_suffix             = string
  })
  default = {
    enable_network_policies = true
    allowed_cidr_blocks    = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    dns_suffix             = "cluster.local"
  }
}

# ===============================================================================
# SECURITY CONFIGURATION
# ===============================================================================

variable "security_config" {
  description = "Configuração de segurança cross-cluster"
  type = object({
    enable_mtls_strict     = bool
    enable_authorization   = bool
    enable_network_policies = bool
    certificate_ttl        = string
  })
  default = {
    enable_mtls_strict     = true
    enable_authorization   = true
    enable_network_policies = true
    certificate_ttl        = "24h"
  }
}

# ===============================================================================
# TRAFFIC MANAGEMENT
# ===============================================================================

variable "traffic_config" {
  description = "Configuração de gerenciamento de tráfego"
  type = object({
    enable_fault_injection    = bool
    enable_circuit_breaker   = bool
    enable_retry_policy      = bool
    default_timeout          = string
    max_retries             = number
    circuit_breaker_threshold = number
  })
  default = {
    enable_fault_injection    = true
    enable_circuit_breaker   = true
    enable_retry_policy      = true
    default_timeout          = "30s"
    max_retries             = 3
    circuit_breaker_threshold = 5
  }
}

# ===============================================================================
# OBSERVABILITY CONFIGURATION
# ===============================================================================

variable "enable_prometheus_monitoring" {
  description = "Habilitar monitoramento Prometheus para cross-cluster"
  type        = bool
  default     = true
}

variable "enable_jaeger_tracing" {
  description = "Habilitar tracing Jaeger para cross-cluster"
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Habilitar access logging para cross-cluster"
  type        = bool
  default     = true
}

variable "telemetry_config" {
  description = "Configuração de telemetria cross-cluster"
  type = object({
    metrics_interval     = string
    tracing_sample_rate = number
    access_log_format   = string
  })
  default = {
    metrics_interval     = "15s"
    tracing_sample_rate = 1.0
    access_log_format   = "json"
  }
}

# ===============================================================================
# PERFORMANCE CONFIGURATION
# ===============================================================================

variable "performance_config" {
  description = "Configuração de performance cross-cluster"
  type = object({
    connection_pool_size      = number
    max_connections_per_host = number
    keepalive_timeout        = string
    request_timeout          = string
    idle_timeout            = string
  })
  default = {
    connection_pool_size      = 100
    max_connections_per_host = 50
    keepalive_timeout        = "60s"
    request_timeout          = "30s"
    idle_timeout            = "300s"
  }
}

# ===============================================================================
# LOAD BALANCING CONFIGURATION
# ===============================================================================

variable "load_balancing_config" {
  description = "Configuração de load balancing cross-cluster"
  type = object({
    algorithm                = string
    locality_lb_setting     = bool
    outlier_detection       = bool
    health_check_interval   = string
    unhealthy_threshold     = number
    healthy_threshold       = number
  })
  default = {
    algorithm                = "LEAST_CONN"
    locality_lb_setting     = true
    outlier_detection       = true
    health_check_interval   = "30s"
    unhealthy_threshold     = 3
    healthy_threshold       = 2
  }
}

# ===============================================================================
# DISASTER RECOVERY CONFIGURATION
# ===============================================================================

variable "disaster_recovery_config" {
  description = "Configuração de disaster recovery"
  type = object({
    enable_failover         = bool
    failover_timeout       = string
    backup_cluster_priority = map(number)
    auto_failback          = bool
  })
  default = {
    enable_failover         = true
    failover_timeout       = "30s"
    backup_cluster_priority = {
      primary   = 1
      secondary = 2
      loadtest  = 3
    }
    auto_failback = true
  }
}

# ===============================================================================
# COMMON CONFIGURATION
# ===============================================================================

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "istio-aks-production"
}
