# ===============================================================================
# LOAD TESTING MODULE - OUTPUTS
# ===============================================================================

# Namespace Information
output "namespace" {
  description = "Namespace do load testing"
  value = {
    name = kubernetes_namespace.load_testing.metadata[0].name
    labels = kubernetes_namespace.load_testing.metadata[0].labels
  }
}

# Available Tools
output "available_tools" {
  description = "Ferramentas de load testing disponíveis"
  value = {
    k6       = var.enable_k6
    artillery = var.enable_artillery
    custom   = var.enable_custom
  }
}

# Test Endpoints
output "test_endpoints" {
  description = "Endpoints configurados para teste"
  value = var.target_endpoints
}

# Load Testing Configuration
output "load_test_config" {
  description = "Configuração dos testes de carga"
  value = {
    target_rps       = var.target_rps
    test_duration    = var.test_duration
    ramp_up_duration = var.ramp_up_duration
    k6_replicas      = var.k6_replicas
    artillery_replicas = var.artillery_replicas
    custom_replicas  = var.custom_replicas
  }
}

# K6 Deployment Information
output "k6_deployment" {
  description = "Informações do deployment K6"
  value = var.enable_k6 ? {
    name      = kubernetes_deployment.k6[0].metadata[0].name
    namespace = kubernetes_deployment.k6[0].metadata[0].namespace
    replicas  = kubernetes_deployment.k6[0].spec[0].replicas
  } : null
}

# Artillery Deployment Information
output "artillery_deployment" {
  description = "Informações do deployment Artillery"
  value = var.enable_artillery ? {
    name      = kubernetes_deployment.artillery[0].metadata[0].name
    namespace = kubernetes_deployment.artillery[0].metadata[0].namespace
    replicas  = kubernetes_deployment.artillery[0].spec[0].replicas
  } : null
}

# Custom Load Generator Deployment Information
output "custom_deployment" {
  description = "Informações do deployment custom load generator"
  value = var.enable_custom ? {
    name      = kubernetes_deployment.custom_load_generator[0].metadata[0].name
    namespace = kubernetes_deployment.custom_load_generator[0].metadata[0].namespace
    replicas  = kubernetes_deployment.custom_load_generator[0].spec[0].replicas
  } : null
}

# ConfigMaps Information
output "configmaps" {
  description = "ConfigMaps criados para load testing"
  value = {
    k6_script = {
      name      = kubernetes_config_map.k6_script.metadata[0].name
      namespace = kubernetes_config_map.k6_script.metadata[0].namespace
    }
    artillery_config = {
      name      = kubernetes_config_map.artillery_config.metadata[0].name
      namespace = kubernetes_config_map.artillery_config.metadata[0].namespace
    }
    custom_generator = {
      name      = kubernetes_config_map.custom_load_generator.metadata[0].name
      namespace = kubernetes_config_map.custom_load_generator.metadata[0].namespace
    }
  }
}

# Monitoring Information
output "monitoring_info" {
  description = "Informações de monitoramento"
  value = {
    metrics_service = {
      name      = kubernetes_service.load_test_metrics.metadata[0].name
      namespace = kubernetes_service.load_test_metrics.metadata[0].namespace
      port      = kubernetes_service.load_test_metrics.spec[0].port[0].port
    }
    prometheus_endpoint = var.prometheus_endpoint
  }
}

# Commands for Manual Testing
output "manual_test_commands" {
  description = "Comandos para execução manual de testes"
  value = {
    k6_test = var.enable_k6 ? "kubectl exec -n ${kubernetes_namespace.load_testing.metadata[0].name} deployment/${kubernetes_deployment.k6[0].metadata[0].name} -- k6 run /scripts/test.js" : "K6 not enabled"
    
    artillery_test = var.enable_artillery ? "kubectl exec -n ${kubernetes_namespace.load_testing.metadata[0].name} deployment/${kubernetes_deployment.artillery[0].metadata[0].name} -- artillery run /config/artillery.yml" : "Artillery not enabled"
    
    custom_test = var.enable_custom ? "kubectl exec -n ${kubernetes_namespace.load_testing.metadata[0].name} deployment/${kubernetes_deployment.custom_load_generator[0].metadata[0].name} -- python /scripts/load_generator.py" : "Custom generator not enabled"
    
    run_600k_job = "kubectl apply -f - <<EOF\n${kubectl_manifest.load_test_600k_job.yaml_body}\nEOF"
  }
}

# Scaling Commands
output "scaling_commands" {
  description = "Comandos para escalar os testes"
  value = {
    scale_k6 = var.enable_k6 ? "kubectl scale deployment ${kubernetes_deployment.k6[0].metadata[0].name} -n ${kubernetes_namespace.load_testing.metadata[0].name} --replicas=" : "K6 not enabled"
    
    scale_artillery = var.enable_artillery ? "kubectl scale deployment ${kubernetes_deployment.artillery[0].metadata[0].name} -n ${kubernetes_namespace.load_testing.metadata[0].name} --replicas=" : "Artillery not enabled"
    
    scale_custom = var.enable_custom ? "kubectl scale deployment ${kubernetes_deployment.custom_load_generator[0].metadata[0].name} -n ${kubernetes_namespace.load_testing.metadata[0].name} --replicas=" : "Custom generator not enabled"
  }
}

# Monitoring Commands
output "monitoring_commands" {
  description = "Comandos para monitoramento dos testes"
  value = {
    view_k6_logs = var.enable_k6 ? "kubectl logs -f deployment/${kubernetes_deployment.k6[0].metadata[0].name} -n ${kubernetes_namespace.load_testing.metadata[0].name}" : "K6 not enabled"
    
    view_artillery_logs = var.enable_artillery ? "kubectl logs -f deployment/${kubernetes_deployment.artillery[0].metadata[0].name} -n ${kubernetes_namespace.load_testing.metadata[0].name}" : "Artillery not enabled"
    
    view_custom_logs = var.enable_custom ? "kubectl logs -f deployment/${kubernetes_deployment.custom_load_generator[0].metadata[0].name} -n ${kubernetes_namespace.load_testing.metadata[0].name}" : "Custom generator not enabled"
    
    view_all_pods = "kubectl get pods -n ${kubernetes_namespace.load_testing.metadata[0].name} -w"
    
    view_metrics = "kubectl port-forward svc/${kubernetes_service.load_test_metrics.metadata[0].name} 8080:8080 -n ${kubernetes_namespace.load_testing.metadata[0].name}"
  }
}

# Performance Tuning Information
output "performance_tuning" {
  description = "Informações para tuning de performance"
  value = {
    recommended_node_config = {
      vm_size = "Standard_D8s_v3 or higher"
      min_nodes = 10
      max_nodes = 50
      note = "Para 600k RPS, recomenda-se nodes com alta CPU e rede"
    }
    
    network_optimization = {
      enable_accelerated_networking = true
      use_premium_storage = true
      note = "Habilitar rede acelerada para melhor performance"
    }
    
    kubernetes_optimization = {
      max_pods_per_node = 250
      enable_cluster_autoscaler = true
      note = "Configurar autoscaler para lidar com picos de carga"
    }
  }
}

# Test Results Location
output "test_results_info" {
  description = "Informações sobre onde encontrar resultados dos testes"
  value = {
    k6_metrics = "Métricas enviadas para Prometheus via endpoint configurado"
    artillery_output = "Logs disponíveis via kubectl logs"
    custom_generator_output = "Logs detalhados com estatísticas em tempo real"
    prometheus_queries = [
      "rate(http_requests_total[5m]) - Taxa de requisições",
      "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) - P95 latência",
      "rate(http_requests_total{status!~\"2..\"}[5m]) - Taxa de erro"
    ]
  }
}
