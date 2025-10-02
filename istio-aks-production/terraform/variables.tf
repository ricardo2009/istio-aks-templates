# ===============================================================================
# ISTIO AKS PRODUCTION ENVIRONMENT - VARIABLES
# ===============================================================================
# Variáveis para configuração completa da solução empresarial
# ===============================================================================

# ===============================================================================
# BASIC CONFIGURATION
# ===============================================================================

variable "resource_group_name" {
  description = "Nome do Resource Group principal"
  type        = string
  default     = "rg-istio-aks-production"
}

variable "location" {
  description = "Localização dos recursos Azure"
  type        = string
  default     = "West US 3"
  
  validation {
    condition = contains([
      "West US 3", "East US 2", "West Europe", "North Europe",
      "Southeast Asia", "Australia East", "Brazil South"
    ], var.location)
    error_message = "Location deve ser uma região Azure válida com suporte completo."
  }
}

variable "owner" {
  description = "Proprietário dos recursos (para tagging)"
  type        = string
  default     = "DevOps Team"
}

variable "cost_center" {
  description = "Centro de custo (para tagging)"
  type        = string
  default     = "Engineering"
}

# ===============================================================================
# KUBERNETES CONFIGURATION
# ===============================================================================

variable "kubernetes_version" {
  description = "Versão do Kubernetes para os clusters AKS"
  type        = string
  default     = "1.28.3"
}

# Primary Cluster Configuration
variable "primary_cluster_node_count" {
  description = "Número de nós no cluster primário"
  type        = number
  default     = 5
  
  validation {
    condition     = var.primary_cluster_node_count >= 3 && var.primary_cluster_node_count <= 100
    error_message = "Node count deve estar entre 3 e 100."
  }
}

variable "primary_cluster_vm_size" {
  description = "Tamanho da VM para nós do cluster primário"
  type        = string
  default     = "Standard_D4s_v3"
}

# Secondary Cluster Configuration
variable "secondary_cluster_node_count" {
  description = "Número de nós no cluster secundário"
  type        = number
  default     = 4
  
  validation {
    condition     = var.secondary_cluster_node_count >= 3 && var.secondary_cluster_node_count <= 100
    error_message = "Node count deve estar entre 3 e 100."
  }
}

variable "secondary_cluster_vm_size" {
  description = "Tamanho da VM para nós do cluster secundário"
  type        = string
  default     = "Standard_D4s_v3"
}

# Load Testing Cluster Configuration
variable "loadtest_cluster_node_count" {
  description = "Número de nós no cluster de load testing"
  type        = number
  default     = 6
  
  validation {
    condition     = var.loadtest_cluster_node_count >= 3 && var.loadtest_cluster_node_count <= 100
    error_message = "Node count deve estar entre 3 e 100."
  }
}

variable "loadtest_cluster_vm_size" {
  description = "Tamanho da VM para nós do cluster de load testing"
  type        = string
  default     = "Standard_D8s_v3"
}

# ===============================================================================
# AZURE API MANAGEMENT CONFIGURATION
# ===============================================================================

variable "apim_sku_name" {
  description = "SKU do Azure API Management"
  type        = string
  default     = "Premium_1"
  
  validation {
    condition = contains([
      "Developer_1", "Standard_1", "Standard_2", 
      "Premium_1", "Premium_2", "Premium_4", "Premium_8"
    ], var.apim_sku_name)
    error_message = "APIM SKU deve ser um valor válido."
  }
}

variable "apim_capacity" {
  description = "Capacidade do Azure API Management"
  type        = number
  default     = 2
  
  validation {
    condition     = var.apim_capacity >= 1 && var.apim_capacity <= 12
    error_message = "APIM capacity deve estar entre 1 e 12."
  }
}

variable "apim_publisher_name" {
  description = "Nome do publisher do APIM"
  type        = string
  default     = "Istio AKS Production"
}

variable "apim_publisher_email" {
  description = "Email do publisher do APIM"
  type        = string
  default     = "admin@company.com"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.apim_publisher_email))
    error_message = "Publisher email deve ser um endereço de email válido."
  }
}

# ===============================================================================
# COSMOSDB CONFIGURATION
# ===============================================================================

variable "cosmosdb_consistency_level" {
  description = "Nível de consistência do CosmosDB"
  type        = string
  default     = "Session"
  
  validation {
    condition = contains([
      "BoundedStaleness", "Eventual", "Session", "Strong", "ConsistentPrefix"
    ], var.cosmosdb_consistency_level)
    error_message = "Consistency level deve ser um valor válido."
  }
}

variable "cosmosdb_max_interval_in_seconds" {
  description = "Intervalo máximo em segundos para BoundedStaleness"
  type        = number
  default     = 300
}

variable "cosmosdb_max_staleness_prefix" {
  description = "Prefixo máximo de staleness para BoundedStaleness"
  type        = number
  default     = 100000
}

variable "cosmosdb_failover_locations" {
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

variable "cosmosdb_databases" {
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

# ===============================================================================
# NGINX INGRESS CONFIGURATION
# ===============================================================================

variable "nginx_replica_count" {
  description = "Número de réplicas do NGINX Ingress Controller"
  type        = number
  default     = 3
  
  validation {
    condition     = var.nginx_replica_count >= 2 && var.nginx_replica_count <= 20
    error_message = "NGINX replica count deve estar entre 2 e 20."
  }
}

# ===============================================================================
# APPLICATION CONFIGURATION
# ===============================================================================

variable "container_registry_url" {
  description = "URL do Container Registry"
  type        = string
  default     = "istioaksprod.azurecr.io"
}

variable "applications" {
  description = "Configuração das aplicações"
  type = map(object({
    cluster     = string
    namespace   = string
    replicas    = number
    image       = string
    port        = number
    cpu_request = string
    cpu_limit   = string
    mem_request = string
    mem_limit   = string
    env_vars    = map(string)
  }))
  default = {
    "frontend" = {
      cluster     = "primary"
      namespace   = "ecommerce"
      replicas    = 3
      image       = "frontend:latest"
      port        = 3000
      cpu_request = "100m"
      cpu_limit   = "500m"
      mem_request = "128Mi"
      mem_limit   = "512Mi"
      env_vars = {
        "NODE_ENV" = "production"
        "API_URL"  = "http://api-gateway:8080"
      }
    }
    "api-gateway" = {
      cluster     = "primary"
      namespace   = "ecommerce"
      replicas    = 3
      image       = "api-gateway:latest"
      port        = 8080
      cpu_request = "200m"
      cpu_limit   = "1000m"
      mem_request = "256Mi"
      mem_limit   = "1Gi"
      env_vars = {
        "NODE_ENV" = "production"
      }
    }
    "user-service" = {
      cluster     = "primary"
      namespace   = "ecommerce"
      replicas    = 2
      image       = "user-service:latest"
      port        = 8081
      cpu_request = "150m"
      cpu_limit   = "750m"
      mem_request = "256Mi"
      mem_limit   = "768Mi"
      env_vars = {
        "NODE_ENV" = "production"
      }
    }
    "order-service" = {
      cluster     = "secondary"
      namespace   = "ecommerce"
      replicas    = 3
      image       = "order-service:latest"
      port        = 8082
      cpu_request = "200m"
      cpu_limit   = "1000m"
      mem_request = "256Mi"
      mem_limit   = "1Gi"
      env_vars = {
        "NODE_ENV" = "production"
      }
    }
    "payment-service" = {
      cluster     = "secondary"
      namespace   = "ecommerce"
      replicas    = 2
      image       = "payment-service:latest"
      port        = 8083
      cpu_request = "150m"
      cpu_limit   = "750m"
      mem_request = "256Mi"
      mem_limit   = "768Mi"
      env_vars = {
        "NODE_ENV" = "production"
      }
    }
    "notification-service" = {
      cluster     = "secondary"
      namespace   = "ecommerce"
      replicas    = 2
      image       = "notification-service:latest"
      port        = 8084
      cpu_request = "100m"
      cpu_limit   = "500m"
      mem_request = "128Mi"
      mem_limit   = "512Mi"
      env_vars = {
        "NODE_ENV" = "production"
      }
    }
  }
}

# ===============================================================================
# LOAD TESTING CONFIGURATION
# ===============================================================================

variable "load_test_target_rps" {
  description = "RPS alvo para load testing"
  type        = number
  default     = 600000
  
  validation {
    condition     = var.load_test_target_rps >= 1000 && var.load_test_target_rps <= 1000000
    error_message = "Target RPS deve estar entre 1000 e 1000000."
  }
}

variable "load_test_duration" {
  description = "Duração do teste de carga"
  type        = string
  default     = "10m"
}

variable "load_test_ramp_up_duration" {
  description = "Duração do ramp-up do teste de carga"
  type        = string
  default     = "2m"
}

# ===============================================================================
# FEATURE FLAGS
# ===============================================================================

variable "enable_advanced_monitoring" {
  description = "Habilitar monitoramento avançado"
  type        = bool
  default     = true
}

variable "enable_auto_scaling" {
  description = "Habilitar auto scaling com KEDA"
  type        = bool
  default     = true
}

variable "enable_cross_cluster_communication" {
  description = "Habilitar comunicação cross-cluster"
  type        = bool
  default     = true
}

variable "enable_mtls_strict" {
  description = "Habilitar mTLS strict mode"
  type        = bool
  default     = true
}

variable "enable_network_policies" {
  description = "Habilitar Network Policies"
  type        = bool
  default     = true
}

variable "enable_pod_security_policies" {
  description = "Habilitar Pod Security Policies"
  type        = bool
  default     = true
}

# ===============================================================================
# OPTIONAL OVERRIDES
# ===============================================================================

variable "custom_domain" {
  description = "Domínio customizado para aplicações"
  type        = string
  default     = ""
}

variable "ssl_certificate_source" {
  description = "Fonte do certificado SSL (keyvault, letsencrypt, custom)"
  type        = string
  default     = "keyvault"
  
  validation {
    condition = contains([
      "keyvault", "letsencrypt", "custom"
    ], var.ssl_certificate_source)
    error_message = "SSL certificate source deve ser keyvault, letsencrypt ou custom."
  }
}

variable "backup_retention_days" {
  description = "Dias de retenção para backups"
  type        = number
  default     = 30
  
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "Backup retention deve estar entre 7 e 365 dias."
  }
}

variable "monitoring_retention_days" {
  description = "Dias de retenção para dados de monitoramento"
  type        = number
  default     = 90
  
  validation {
    condition     = var.monitoring_retention_days >= 30 && var.monitoring_retention_days <= 730
    error_message = "Monitoring retention deve estar entre 30 e 730 dias."
  }
}
