# ===============================================================================
# ISTIO AKS PRODUCTION ENVIRONMENT - OUTPUTS
# ===============================================================================
# Outputs principais para integração e acesso aos recursos
# ===============================================================================

# ===============================================================================
# INFRASTRUCTURE OUTPUTS
# ===============================================================================

output "resource_group_name" {
  description = "Nome do Resource Group principal"
  value       = module.azure_infrastructure.resource_group_name
}

output "location" {
  description = "Localização dos recursos"
  value       = var.location
}

output "vnet_id" {
  description = "ID da Virtual Network principal"
  value       = module.azure_infrastructure.vnet_id
}

output "vnet_name" {
  description = "Nome da Virtual Network principal"
  value       = module.azure_infrastructure.vnet_name
}

# ===============================================================================
# AKS CLUSTERS OUTPUTS
# ===============================================================================

output "clusters" {
  description = "Informações dos clusters AKS"
  value = {
    primary = {
      name                = module.azure_infrastructure.clusters.primary.name
      id                  = module.azure_infrastructure.clusters.primary.id
      fqdn               = module.azure_infrastructure.clusters.primary.fqdn
      kubernetes_version = module.azure_infrastructure.clusters.primary.kubernetes_version
      node_resource_group = module.azure_infrastructure.clusters.primary.node_resource_group_name
    }
    secondary = {
      name                = module.azure_infrastructure.clusters.secondary.name
      id                  = module.azure_infrastructure.clusters.secondary.id
      fqdn               = module.azure_infrastructure.clusters.secondary.fqdn
      kubernetes_version = module.azure_infrastructure.clusters.secondary.kubernetes_version
      node_resource_group = module.azure_infrastructure.clusters.secondary.node_resource_group_name
    }
    loadtest = {
      name                = module.azure_infrastructure.clusters.loadtest.name
      id                  = module.azure_infrastructure.clusters.loadtest.id
      fqdn               = module.azure_infrastructure.clusters.loadtest.fqdn
      kubernetes_version = module.azure_infrastructure.clusters.loadtest.kubernetes_version
      node_resource_group = module.azure_infrastructure.clusters.loadtest.node_resource_group_name
    }
  }
  sensitive = false
}

output "kubeconfig_commands" {
  description = "Comandos para configurar kubectl"
  value = {
    primary   = "az aks get-credentials --resource-group ${module.azure_infrastructure.resource_group_name} --name ${module.azure_infrastructure.clusters.primary.name} --context primary"
    secondary = "az aks get-credentials --resource-group ${module.azure_infrastructure.resource_group_name} --name ${module.azure_infrastructure.clusters.secondary.name} --context secondary"
    loadtest  = "az aks get-credentials --resource-group ${module.azure_infrastructure.resource_group_name} --name ${module.azure_infrastructure.clusters.loadtest.name} --context loadtest"
  }
}

# ===============================================================================
# SECURITY OUTPUTS
# ===============================================================================

output "key_vault" {
  description = "Informações do Azure Key Vault"
  value = {
    id   = module.security.key_vault_id
    name = module.security.key_vault_name
    uri  = module.security.key_vault_uri
  }
  sensitive = false
}

output "certificates" {
  description = "Certificados criados no Key Vault"
  value = {
    root_ca      = module.security.root_ca_certificate_name
    intermediate = module.security.intermediate_ca_certificate_name
    application  = module.security.application_certificate_name
    gateway_tls  = module.security.gateway_tls_certificate_name
  }
  sensitive = false
}

# ===============================================================================
# APIM OUTPUTS
# ===============================================================================

output "apim" {
  description = "Informações do Azure API Management"
  value = {
    name        = module.apim.name
    gateway_url = module.apim.gateway_url
    portal_url  = module.apim.portal_url
    management_api_url = module.apim.management_api_url
    public_ip_addresses = module.apim.public_ip_addresses
  }
  sensitive = false
}

output "apim_apis" {
  description = "APIs configuradas no APIM"
  value = module.apim.configured_apis
  sensitive = false
}

# ===============================================================================
# COSMOSDB OUTPUTS
# ===============================================================================

output "cosmosdb" {
  description = "Informações do CosmosDB"
  value = {
    name     = module.cosmosdb.name
    endpoint = module.cosmosdb.endpoint
    id       = module.cosmosdb.id
    databases = module.cosmosdb.databases
  }
  sensitive = false
}

output "cosmosdb_connection_strings" {
  description = "Strings de conexão do CosmosDB (sensível)"
  value = {
    primary_readonly   = module.cosmosdb.primary_readonly_connection_string
    secondary_readonly = module.cosmosdb.secondary_readonly_connection_string
  }
  sensitive = true
}

# ===============================================================================
# NGINX INGRESS OUTPUTS
# ===============================================================================

output "nginx_ingress" {
  description = "Informações do NGINX Ingress Controller"
  value = {
    primary_external_ip   = module.nginx_ingress.primary_external_ip
    secondary_external_ip = module.nginx_ingress.secondary_external_ip
    primary_internal_ip   = module.nginx_ingress.primary_internal_ip
    secondary_internal_ip = module.nginx_ingress.secondary_internal_ip
  }
  sensitive = false
}

# ===============================================================================
# APPLICATIONS OUTPUTS
# ===============================================================================

output "applications" {
  description = "Informações das aplicações deployadas"
  value = {
    deployed_apps = module.applications.deployed_applications
    namespaces   = module.applications.created_namespaces
    services     = module.applications.service_endpoints
  }
  sensitive = false
}

output "application_urls" {
  description = "URLs de acesso às aplicações"
  value = {
    frontend_url     = "https://${module.nginx_ingress.primary_external_ip}"
    api_gateway_url  = "https://${module.nginx_ingress.primary_external_ip}/api"
    apim_gateway_url = module.apim.gateway_url
  }
  sensitive = false
}

# ===============================================================================
# OBSERVABILITY OUTPUTS
# ===============================================================================

output "observability" {
  description = "Informações da stack de observabilidade"
  value = {
    log_analytics_workspace_id = module.azure_infrastructure.log_analytics_workspace_id
    prometheus_endpoint       = module.observability.prometheus_endpoint
    grafana_url              = module.observability.grafana_url
    application_insights_key = module.observability.application_insights_instrumentation_key
  }
  sensitive = false
}

output "monitoring_dashboards" {
  description = "URLs dos dashboards de monitoramento"
  value = {
    grafana_url           = module.observability.grafana_url
    azure_monitor_url     = "https://portal.azure.com/#@${data.azurerm_client_config.current.tenant_id}/resource${module.azure_infrastructure.log_analytics_workspace_id}/overview"
    application_insights_url = module.observability.application_insights_url
  }
  sensitive = false
}

# ===============================================================================
# LOAD TESTING OUTPUTS
# ===============================================================================

output "load_testing" {
  description = "Informações do ambiente de load testing"
  value = {
    cluster_name     = module.azure_infrastructure.clusters.loadtest.name
    target_rps       = var.load_test_target_rps
    test_duration    = var.load_test_duration
    available_tools  = module.load_testing.available_tools
    test_endpoints   = module.load_testing.test_endpoints
  }
  sensitive = false
}

# ===============================================================================
# NETWORK OUTPUTS
# ===============================================================================

output "network_configuration" {
  description = "Configuração de rede"
  value = {
    vnet_address_space = module.azure_infrastructure.vnet_address_space
    subnet_cidrs = {
      primary   = module.azure_infrastructure.primary_subnet_cidr
      secondary = module.azure_infrastructure.secondary_subnet_cidr
      loadtest  = module.azure_infrastructure.loadtest_subnet_cidr
      apim      = module.azure_infrastructure.apim_subnet_cidr
    }
    private_dns_zones = module.azure_infrastructure.private_dns_zones
  }
  sensitive = false
}

# ===============================================================================
# QUICK ACCESS COMMANDS
# ===============================================================================

output "quick_access_commands" {
  description = "Comandos para acesso rápido aos recursos"
  value = {
    connect_to_clusters = {
      primary   = "az aks get-credentials --resource-group ${module.azure_infrastructure.resource_group_name} --name ${module.azure_infrastructure.clusters.primary.name} --context primary"
      secondary = "az aks get-credentials --resource-group ${module.azure_infrastructure.resource_group_name} --name ${module.azure_infrastructure.clusters.secondary.name} --context secondary"
      loadtest  = "az aks get-credentials --resource-group ${module.azure_infrastructure.resource_group_name} --name ${module.azure_infrastructure.clusters.loadtest.name} --context loadtest"
    }
    view_applications = {
      primary_pods   = "kubectl get pods -n ecommerce --context=primary"
      secondary_pods = "kubectl get pods -n ecommerce --context=secondary"
      all_services   = "kubectl get svc -A --context=primary"
    }
    monitoring = {
      grafana_login    = "kubectl get secret grafana-admin-credentials -n monitoring --context=primary -o jsonpath='{.data.admin-password}' | base64 -d"
      prometheus_port  = "kubectl port-forward svc/prometheus-server 9090:80 -n monitoring --context=primary"
      view_istio_config = "kubectl get gateway,virtualservice,destinationrule -A --context=primary"
    }
    load_testing = {
      run_basic_test   = "kubectl apply -f load-test-basic.yaml --context=loadtest"
      run_600k_test    = "kubectl apply -f load-test-600k.yaml --context=loadtest"
      view_test_results = "kubectl logs -l app=load-test -n load-testing --context=loadtest"
    }
  }
}

# ===============================================================================
# DEPLOYMENT SUMMARY
# ===============================================================================

output "deployment_summary" {
  description = "Resumo do deployment"
  value = {
    environment           = "production"
    total_clusters        = 3
    total_applications    = length(var.applications)
    apim_enabled         = true
    cosmosdb_enabled     = true
    load_testing_enabled = true
    target_rps           = var.load_test_target_rps
    istio_version        = "managed"
    nginx_ingress        = "non-managed"
    keda_enabled         = var.enable_auto_scaling
    mtls_enabled         = var.enable_mtls_strict
    monitoring_enabled   = var.enable_advanced_monitoring
    deployment_time      = timestamp()
  }
}

# ===============================================================================
# COST ESTIMATION
# ===============================================================================

output "estimated_monthly_cost" {
  description = "Estimativa de custo mensal (USD)"
  value = {
    aks_clusters = {
      primary   = "~$400-600/month (5 nodes Standard_D4s_v3)"
      secondary = "~$320-480/month (4 nodes Standard_D4s_v3)"
      loadtest  = "~$480-720/month (6 nodes Standard_D8s_v3)"
    }
    apim         = "~$2,000-3,000/month (Premium_1 with 2 units)"
    cosmosdb     = "~$200-500/month (depends on throughput and storage)"
    monitoring   = "~$100-300/month (Log Analytics + Application Insights)"
    networking   = "~$50-150/month (Load Balancers + Data Transfer)"
    storage      = "~$50-100/month (Persistent Volumes + Backups)"
    total_estimated = "~$3,600-5,950/month"
    note = "Custos podem variar baseado no uso real, região e descontos aplicáveis"
  }
}

# ===============================================================================
# NEXT STEPS
# ===============================================================================

output "next_steps" {
  description = "Próximos passos após o deployment"
  value = [
    "1. Configure kubectl contexts: terraform output -raw kubeconfig_commands",
    "2. Acesse Grafana: terraform output -raw monitoring_dashboards",
    "3. Teste as aplicações: terraform output -raw application_urls",
    "4. Execute load testing: terraform output -raw load_testing",
    "5. Configure domínio customizado se necessário",
    "6. Configure backup e disaster recovery",
    "7. Configure alertas e notificações",
    "8. Execute testes de segurança e penetração",
    "9. Configure CI/CD pipelines",
    "10. Documente procedimentos operacionais"
  ]
}
