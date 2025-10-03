# ===============================================================================
# CROSS-CLUSTER COMMUNICATION MODULE - OUTPUTS
# ===============================================================================

# ===============================================================================
# CLUSTER INFORMATION
# ===============================================================================

output "cluster_configuration" {
  description = "Configuração dos clusters no mesh"
  value = {
    primary = {
      name         = var.primary_cluster.name
      region       = var.primary_cluster.region
      network      = var.primary_cluster.network
      mesh_id      = var.primary_cluster.mesh_id
      cluster_name = var.primary_cluster.cluster_name
    }
    secondary = {
      name         = var.secondary_cluster.name
      region       = var.secondary_cluster.region
      network      = var.secondary_cluster.network
      mesh_id      = var.secondary_cluster.mesh_id
      cluster_name = var.secondary_cluster.cluster_name
    }
    loadtest = {
      name         = var.loadtest_cluster.name
      region       = var.loadtest_cluster.region
      network      = var.loadtest_cluster.network
      mesh_id      = var.loadtest_cluster.mesh_id
      cluster_name = var.loadtest_cluster.cluster_name
    }
  }
  sensitive = false
}

output "mesh_configuration" {
  description = "Configuração do Istio mesh"
  value = {
    mesh_id      = var.mesh_id
    trust_domain = var.trust_domain
    revision     = var.istio_revision
  }
  sensitive = false
}

# ===============================================================================
# GATEWAY INFORMATION
# ===============================================================================

output "eastwest_gateways" {
  description = "Informações dos East-West Gateways"
  value = {
    for cluster_name, cluster in {
      primary   = var.primary_cluster
      secondary = var.secondary_cluster
      loadtest  = var.loadtest_cluster
    } : cluster_name => {
      name         = "istio-eastwestgateway"
      namespace    = "istio-system"
      service_name = "istio-eastwestgateway"
      dns_name     = "${cluster.name}-eastwest.${cluster.region}.cloudapp.azure.com"
      ports = {
        status = 15021
        tls    = 15443
      }
    }
  }
  sensitive = false
}

output "cross_cluster_gateways" {
  description = "Gateways para comunicação cross-cluster"
  value = {
    cross_network_gateway = {
      name      = "cross-network-gateway"
      namespace = "istio-system"
      selector  = "istio=eastwestgateway"
      protocol  = "TLS"
      mode      = "ISTIO_MUTUAL"
    }
    istiod_gateway = {
      name      = "istiod-gateway"
      namespace = "istio-system"
      selector  = "istio=eastwestgateway"
      protocol  = "TLS"
      mode      = "PASSTHROUGH"
      port      = 15012
    }
  }
  sensitive = false
}

# ===============================================================================
# SERVICE DISCOVERY
# ===============================================================================

output "service_discovery" {
  description = "Configuração de service discovery cross-cluster"
  value = {
    remote_secrets = {
      for pair in setproduct(["primary", "secondary", "loadtest"], ["primary", "secondary", "loadtest"]) :
      "${pair[0]}-to-${pair[1]}" => {
        source_cluster = pair[0]
        target_cluster = pair[1]
        secret_name    = "istio-remote-secret-${pair[1]}"
        namespace      = "istio-system"
      }
      if pair[0] != pair[1]
    }
    cross_cluster_services = var.cross_cluster_services
  }
  sensitive = false
}

# ===============================================================================
# CROSS-CLUSTER SERVICES
# ===============================================================================

output "cross_cluster_services" {
  description = "Serviços configurados para comunicação cross-cluster"
  value = {
    for service_name, config in var.cross_cluster_services : service_name => {
      service_name         = config.service_name
      namespace           = config.namespace
      global_fqdn         = "${config.service_name}.${config.namespace}.global"
      port               = config.port
      protocol           = config.protocol
      clusters           = config.clusters
      traffic_distribution = config.traffic_distribution
      virtual_ip         = "240.0.0.${config.address_suffix}"
      service_account    = config.service_account
      allowed_methods    = config.allowed_methods
    }
  }
  sensitive = false
}

# ===============================================================================
# SECURITY CONFIGURATION
# ===============================================================================

output "security_configuration" {
  description = "Configuração de segurança cross-cluster"
  value = {
    mtls = {
      mode   = "STRICT"
      policy = "cross-cluster-mtls"
    }
    authorization = {
      enabled  = var.security_config.enable_authorization
      policies = [
        for service_name, config in var.cross_cluster_services : {
          name      = "${service_name}-cross-cluster-authz"
          namespace = config.namespace
          service   = config.service_name
        }
      ]
    }
    network_policies = {
      enabled = var.security_config.enable_network_policies
      namespaces = var.cross_cluster_namespaces
    }
  }
  sensitive = false
}

# ===============================================================================
# TRAFFIC MANAGEMENT
# ===============================================================================

output "traffic_management" {
  description = "Configuração de gerenciamento de tráfego"
  value = {
    destination_rules = {
      for service_name, config in var.cross_cluster_services : service_name => {
        name      = "${service_name}-cross-cluster-dr"
        namespace = config.namespace
        host      = "${config.service_name}.${config.namespace}.global"
        tls_mode  = "ISTIO_MUTUAL"
        subsets   = length(config.clusters) > 1 ? config.clusters : []
      }
    }
    virtual_services = {
      for service_name, config in var.cross_cluster_services : service_name => {
        name      = "${service_name}-cross-cluster-vs"
        namespace = config.namespace
        host      = "${config.service_name}.${config.namespace}.global"
        routes = [
          for i, cluster in config.clusters : {
            cluster = cluster
            weight  = config.traffic_distribution[i]
          }
        ]
      }
    }
    performance = var.performance_config
    load_balancing = var.load_balancing_config
  }
  sensitive = false
}

# ===============================================================================
# OBSERVABILITY
# ===============================================================================

output "observability_configuration" {
  description = "Configuração de observabilidade cross-cluster"
  value = {
    telemetry = {
      enabled = true
      metrics = {
        enabled  = var.enable_prometheus_monitoring
        interval = var.telemetry_config.metrics_interval
        labels = [
          "source_cluster",
          "destination_cluster",
          "source_workload",
          "destination_workload"
        ]
      }
      tracing = {
        enabled     = var.enable_jaeger_tracing
        sample_rate = var.telemetry_config.tracing_sample_rate
        provider    = "jaeger"
      }
      access_logging = {
        enabled = var.enable_access_logging
        format  = var.telemetry_config.access_log_format
      }
    }
    monitoring = {
      service_monitor = var.enable_prometheus_monitoring ? "cross-cluster-metrics" : null
      prometheus_rules = var.enable_prometheus_monitoring ? "cross-cluster-alerts" : null
      alerts = [
        "CrossClusterHighLatency",
        "CrossClusterHighErrorRate",
        "CrossClusterConnectivityLoss"
      ]
    }
  }
  sensitive = false
}

# ===============================================================================
# NETWORK CONFIGURATION
# ===============================================================================

output "network_configuration" {
  description = "Configuração de rede cross-cluster"
  value = {
    networks = {
      for cluster_name, cluster in {
        primary   = var.primary_cluster
        secondary = var.secondary_cluster
        loadtest  = var.loadtest_cluster
      } : cluster_name => {
        name    = cluster.network
        region  = cluster.region
        cluster = cluster_name
      }
    }
    endpoints = {
      for cluster_name, cluster in {
        primary   = var.primary_cluster
        secondary = var.secondary_cluster
        loadtest  = var.loadtest_cluster
      } : cluster_name => {
        discovery_address = "${cluster.name}-istio-discovery.${cluster.region}.cloudapp.azure.com"
        eastwest_gateway  = "${cluster.name}-eastwest-gateway.${cluster.region}.cloudapp.azure.com"
        api_server        = var.cluster_endpoints[cluster_name].api_server_url
      }
    }
    dns_config = {
      suffix = var.network_config.dns_suffix
      global_domain = "global"
    }
  }
  sensitive = false
}

# ===============================================================================
# DISASTER RECOVERY
# ===============================================================================

output "disaster_recovery" {
  description = "Configuração de disaster recovery"
  value = {
    failover = {
      enabled  = var.disaster_recovery_config.enable_failover
      timeout  = var.disaster_recovery_config.failover_timeout
      priority = var.disaster_recovery_config.backup_cluster_priority
    }
    auto_failback = var.disaster_recovery_config.auto_failback
    health_checks = {
      interval           = var.load_balancing_config.health_check_interval
      unhealthy_threshold = var.load_balancing_config.unhealthy_threshold
      healthy_threshold  = var.load_balancing_config.healthy_threshold
    }
  }
  sensitive = false
}

# ===============================================================================
# DEPLOYMENT STATUS
# ===============================================================================

output "deployment_status" {
  description = "Status do deployment cross-cluster"
  value = {
    istio_multicluster_config = "deployed"
    eastwest_gateways        = "deployed"
    cross_cluster_gateways   = "deployed"
    service_entries          = "deployed"
    destination_rules        = "deployed"
    virtual_services         = "deployed"
    peer_authentication      = "deployed"
    authorization_policies   = "deployed"
    telemetry_config        = "deployed"
    network_policies        = var.network_config.enable_network_policies ? "deployed" : "disabled"
    monitoring              = var.enable_prometheus_monitoring ? "deployed" : "disabled"
  }
  sensitive = false
}

# ===============================================================================
# CONNECTION INFORMATION
# ===============================================================================

output "connection_info" {
  description = "Informações de conexão para troubleshooting"
  value = {
    kubectl_commands = {
      check_mesh_status = "kubectl get pods -n istio-system"
      check_gateways   = "kubectl get gateway -A"
      check_services   = "kubectl get serviceentry -A"
      check_secrets    = "kubectl get secrets -n istio-system | grep istio-remote"
    }
    istioctl_commands = {
      proxy_config     = "istioctl proxy-config cluster <pod-name> -n <namespace>"
      proxy_status     = "istioctl proxy-status"
      analyze         = "istioctl analyze"
      describe_pod    = "istioctl describe pod <pod-name> -n <namespace>"
    }
    troubleshooting = {
      connectivity_test = "kubectl exec -n <namespace> <pod-name> -- curl -v <service>.<namespace>.global"
      mtls_check       = "istioctl authn tls-check <pod-name>.<namespace>"
      trace_requests   = "kubectl logs -n istio-system -l app=istiod --tail=100"
    }
  }
  sensitive = false
}

# ===============================================================================
# PERFORMANCE METRICS
# ===============================================================================

output "performance_targets" {
  description = "Metas de performance cross-cluster"
  value = {
    latency = {
      p50_target = "< 50ms"
      p95_target = "< 100ms"
      p99_target = "< 200ms"
    }
    throughput = {
      target_rps = "600,000 RPS total"
      cross_cluster_rps = "150,000 RPS"
    }
    availability = {
      target = "99.99%"
      mttr   = "< 30s"
    }
    error_rate = {
      target = "< 0.01%"
    }
  }
  sensitive = false
}
