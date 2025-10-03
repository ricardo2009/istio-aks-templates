# ===============================================================================
# MONITORING & OBSERVABILITY MODULE - OUTPUTS
# ===============================================================================

output "prometheus_endpoint" {
  description = "Endpoint do Prometheus"
  value       = var.prometheus_enabled ? "http://prometheus.${var.namespace}.svc.cluster.local:9090" : null
}

output "grafana_endpoint" {
  description = "Endpoint do Grafana"
  value       = var.grafana_enabled ? "http://grafana.${var.namespace}.svc.cluster.local:3000" : null
}

output "jaeger_endpoint" {
  description = "Endpoint do Jaeger"
  value       = var.jaeger_enabled ? "http://jaeger-query.${var.namespace}.svc.cluster.local:16686" : null
}

output "alertmanager_endpoint" {
  description = "Endpoint do AlertManager"
  value       = var.alertmanager_enabled ? "http://alertmanager.${var.namespace}.svc.cluster.local:9093" : null
}

output "monitoring_namespace" {
  description = "Namespace dos componentes de monitoramento"
  value       = var.namespace
}

output "dashboards_configmap" {
  description = "Nome do ConfigMap com dashboards do Grafana"
  value       = var.grafana_enabled ? "grafana-dashboards" : null
}

output "prometheus_config" {
  description = "Configuração do Prometheus"
  value = var.prometheus_enabled ? {
    retention     = var.prometheus_retention
    storage_size  = var.prometheus_storage_size
    endpoint      = "http://prometheus.${var.namespace}.svc.cluster.local:9090"
  } : null
}

output "monitoring_status" {
  description = "Status dos componentes de monitoramento"
  value = {
    prometheus    = var.prometheus_enabled
    grafana      = var.grafana_enabled
    jaeger       = var.jaeger_enabled
    alertmanager = var.alertmanager_enabled
    azure_monitor = var.azure_monitor_enabled
  }
}
