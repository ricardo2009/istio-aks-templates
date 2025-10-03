# ===============================================================================
# NGINX INGRESS CONTROLLER & KEDA MODULE - OUTPUTS
# ===============================================================================

# ===============================================================================
# NGINX INGRESS CONTROLLER OUTPUTS
# ===============================================================================

output "nginx_ingress_namespace" {
  description = "Namespace do NGINX Ingress Controller"
  value       = kubernetes_namespace.nginx_ingress.metadata[0].name
}

output "nginx_ingress_release_name" {
  description = "Nome do release Helm do NGINX Ingress Controller"
  value       = helm_release.nginx_ingress.name
}

output "nginx_ingress_chart_version" {
  description = "Versão do chart do NGINX Ingress Controller"
  value       = helm_release.nginx_ingress.version
}

output "nginx_ingress_status" {
  description = "Status do NGINX Ingress Controller"
  value       = helm_release.nginx_ingress.status
}

output "nginx_ingress_service_name" {
  description = "Nome do serviço do NGINX Ingress Controller"
  value       = "${helm_release.nginx_ingress.name}-controller"
}

output "nginx_ingress_class_name" {
  description = "Nome da classe do NGINX Ingress"
  value       = "nginx"
}

output "nginx_custom_headers_configmap" {
  description = "Nome do ConfigMap de headers customizados"
  value       = kubernetes_config_map.custom_headers.metadata[0].name
}

# ===============================================================================
# KEDA OUTPUTS
# ===============================================================================

output "keda_namespace" {
  description = "Namespace do KEDA"
  value       = kubernetes_namespace.keda_system.metadata[0].name
}

output "keda_release_name" {
  description = "Nome do release Helm do KEDA"
  value       = helm_release.keda.name
}

output "keda_chart_version" {
  description = "Versão do chart do KEDA"
  value       = helm_release.keda.version
}

output "keda_status" {
  description = "Status do KEDA"
  value       = helm_release.keda.status
}

output "keda_operator_name" {
  description = "Nome do operador KEDA"
  value       = "keda-operator"
}

output "keda_metrics_server_name" {
  description = "Nome do servidor de métricas KEDA"
  value       = "keda-metrics-apiserver"
}

output "keda_webhooks_name" {
  description = "Nome dos webhooks KEDA"
  value       = "keda-admission-webhooks"
}

# ===============================================================================
# SCALED OBJECTS OUTPUTS
# ===============================================================================

output "scaled_objects" {
  description = "Lista de ScaledObjects criados"
  value = {
    api_gateway     = "api-gateway-scaler"
    user_service    = "user-service-scaler"
    product_service = "product-service-scaler"
    order_service   = "order-service-scaler"
    payment_service = "payment-service-scaler"
  }
}

output "backup_hpa" {
  description = "Lista de HPAs de backup criados"
  value = {
    api_gateway = kubernetes_horizontal_pod_autoscaler_v2.api_gateway_hpa_backup.metadata[0].name
  }
}

# ===============================================================================
# CONFIGURATION OUTPUTS
# ===============================================================================

output "nginx_configuration" {
  description = "Configuração do NGINX Ingress Controller"
  value = {
    replica_count = var.nginx_replica_count
    resources     = var.nginx_resources
    node_selector = var.nginx_node_selector
    tolerations   = var.nginx_tolerations
  }
  sensitive = false
}

output "keda_configuration" {
  description = "Configuração do KEDA"
  value = {
    operator_replicas      = var.keda_operator_replica_count
    metrics_server_replicas = var.keda_metrics_server_replica_count
    webhooks_replicas      = var.keda_webhooks_replica_count
    log_level             = var.keda_log_level
  }
  sensitive = false
}

output "scaling_configuration" {
  description = "Configuração de escalonamento dos microserviços"
  value = {
    api_gateway = {
      min_replicas = var.api_gateway_min_replicas
      max_replicas = var.api_gateway_max_replicas
    }
    user_service = {
      min_replicas = var.user_service_min_replicas
      max_replicas = var.user_service_max_replicas
    }
    product_service = {
      min_replicas = var.product_service_min_replicas
      max_replicas = var.product_service_max_replicas
    }
    order_service = {
      min_replicas = var.order_service_min_replicas
      max_replicas = var.order_service_max_replicas
    }
    payment_service = {
      min_replicas = var.payment_service_min_replicas
      max_replicas = var.payment_service_max_replicas
    }
  }
  sensitive = false
}

# ===============================================================================
# MONITORING OUTPUTS
# ===============================================================================

output "monitoring_endpoints" {
  description = "Endpoints de monitoramento"
  value = {
    nginx_metrics = {
      port = 10254
      path = "/metrics"
    }
    keda_operator_metrics = {
      port = 8080
      path = "/metrics"
    }
    keda_metrics_server_metrics = {
      port = 9022
      path = "/metrics"
    }
    keda_webhooks_metrics = {
      port = 8080
      path = "/metrics"
    }
  }
  sensitive = false
}

output "health_check_endpoints" {
  description = "Endpoints de verificação de saúde"
  value = {
    nginx_health = {
      port = 10254
      path = "/healthz"
    }
    nginx_ready = {
      port = 10254
      path = "/ready"
    }
  }
  sensitive = false
}

# ===============================================================================
# SECURITY OUTPUTS
# ===============================================================================

output "security_headers" {
  description = "Headers de segurança configurados"
  value = {
    x_frame_options           = "SAMEORIGIN"
    x_content_type_options    = "nosniff"
    x_xss_protection          = "1; mode=block"
    referrer_policy           = "strict-origin-when-cross-origin"
    strict_transport_security = "max-age=31536000; includeSubDomains; preload"
  }
  sensitive = false
}

# ===============================================================================
# PERFORMANCE OUTPUTS
# ===============================================================================

output "performance_configuration" {
  description = "Configuração de performance do NGINX"
  value = {
    worker_processes         = "auto"
    worker_connections       = "16384"
    keepalive_requests       = "10000"
    upstream_keepalive_connections = "320"
    proxy_buffer_size        = "16k"
    proxy_buffers_number     = "8"
  }
  sensitive = false
}

output "rate_limiting" {
  description = "Configuração de rate limiting"
  value = {
    requests_per_second = "1000"
    connections_limit   = "100"
  }
  sensitive = false
}

# ===============================================================================
# DEPLOYMENT INFO
# ===============================================================================

output "deployment_info" {
  description = "Informações de deployment"
  value = {
    nginx_chart_version = var.nginx_chart_version
    nginx_image_tag     = var.nginx_image_tag
    keda_chart_version  = var.keda_chart_version
    prometheus_enabled  = var.enable_prometheus_monitoring
    applications_namespace = var.applications_namespace
  }
  sensitive = false
}
