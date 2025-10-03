# ===============================================================================
# MONITORING & OBSERVABILITY MODULE - MAIN CONFIGURATION
# ===============================================================================
# Módulo responsável por implementar monitoramento completo e observabilidade
# para a solução Istio on AKS com Prometheus, Grafana, Jaeger e alertas
# ===============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

# ===============================================================================
# LOCAL VALUES
# ===============================================================================

locals {
  # Namespaces
  monitoring_namespace = "monitoring"
  istio_namespace     = "istio-system"
  
  # Common labels
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"   = "istio-monitoring"
  }
  
  # Grafana dashboards
  grafana_dashboards = {
    istio_mesh         = file("${path.module}/dashboards/istio-mesh-dashboard.json")
    istio_service      = file("${path.module}/dashboards/istio-service-dashboard.json")
    istio_workload     = file("${path.module}/dashboards/istio-workload-dashboard.json")
    istio_performance  = file("${path.module}/dashboards/istio-performance-dashboard.json")
    cross_cluster      = file("${path.module}/dashboards/cross-cluster-dashboard.json")
    load_testing       = file("${path.module}/dashboards/load-testing-dashboard.json")
    infrastructure     = file("${path.module}/dashboards/infrastructure-dashboard.json")
    business_metrics   = file("${path.module}/dashboards/business-metrics-dashboard.json")
  }
}

# ===============================================================================
# NAMESPACES
# ===============================================================================

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = local.monitoring_namespace
    labels = merge(local.common_labels, {
      "name" = local.monitoring_namespace
      "istio-injection" = "enabled"
    })
  }
}

# ===============================================================================
# AZURE MONITOR WORKSPACE (MANAGED PROMETHEUS)
# ===============================================================================

# Azure Monitor Workspace for Managed Prometheus
resource "azurerm_monitor_workspace" "prometheus" {
  name                = "${var.project_name}-prometheus-${var.environment}"
  resource_group_name = var.resource_group_name
  location           = var.location
  
  tags = merge(var.tags, {
    Component = "Monitoring"
    Service   = "Prometheus"
  })
}

# Data Collection Endpoint
resource "azurerm_monitor_data_collection_endpoint" "prometheus" {
  name                = "${var.project_name}-prometheus-dce-${var.environment}"
  resource_group_name = var.resource_group_name
  location           = var.location
  kind               = "Linux"
  
  tags = merge(var.tags, {
    Component = "Monitoring"
    Service   = "DataCollection"
  })
}

# Data Collection Rule for Prometheus
resource "azurerm_monitor_data_collection_rule" "prometheus" {
  name                        = "${var.project_name}-prometheus-dcr-${var.environment}"
  resource_group_name         = var.resource_group_name
  location                   = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prometheus.id
  kind                       = "Linux"
  
  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.prometheus.id
      name              = "MonitoringAccount1"
    }
  }
  
  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }
  
  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }
  
  tags = merge(var.tags, {
    Component = "Monitoring"
    Service   = "DataCollection"
  })
}

# ===============================================================================
# PROMETHEUS CONFIGURATION
# ===============================================================================

# Prometheus configuration for Istio metrics
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = local.monitoring_namespace
    labels    = local.common_labels
  }
  
  data = {
    "prometheus.yml" = templatefile("${path.module}/configs/prometheus.yml", {
      cluster_name = var.cluster_name
      environment  = var.environment
    })
    "istio-scrape-configs.yml" = file("${path.module}/configs/istio-scrape-configs.yml")
    "recording-rules.yml" = file("${path.module}/configs/recording-rules.yml")
    "alerting-rules.yml" = file("${path.module}/configs/alerting-rules.yml")
  }
}

# ServiceMonitor for Istio components
resource "kubectl_manifest" "istio_service_monitors" {
  for_each = toset([
    "istiod",
    "istio-proxy",
    "istio-gateway"
  ])
  
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: ${each.value}
      namespace: ${local.monitoring_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      selector:
        matchLabels:
          app: ${each.value}
      endpoints:
      - port: http-monitoring
        interval: 15s
        path: /metrics
        relabelings:
        - sourceLabels: [__meta_kubernetes_pod_name]
          targetLabel: pod
        - sourceLabels: [__meta_kubernetes_pod_label_version]
          targetLabel: version
        - sourceLabels: [__meta_kubernetes_namespace]
          targetLabel: namespace
        - targetLabel: cluster
          replacement: ${var.cluster_name}
      namespaceSelector:
        matchNames:
        - ${local.istio_namespace}
        - ${local.monitoring_namespace}
  YAML
}

# ===============================================================================
# GRAFANA DEPLOYMENT
# ===============================================================================

# Grafana Helm Chart
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.grafana_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  
  values = [
    yamlencode({
      # Admin configuration
      adminUser     = var.grafana_admin_user
      adminPassword = var.grafana_admin_password
      
      # Persistence
      persistence = {
        enabled      = true
        type        = "pvc"
        size        = "10Gi"
        storageClassName = "managed-premium"
      }
      
      # Resources
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
      
      # Service configuration
      service = {
        type = "ClusterIP"
        port = 80
      }
      
      # Ingress configuration
      ingress = {
        enabled = true
        annotations = {
          "kubernetes.io/ingress.class"                = "nginx"
          "nginx.ingress.kubernetes.io/ssl-redirect"   = "true"
          "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
          "cert-manager.io/cluster-issuer"            = "letsencrypt-prod"
        }
        hosts = [
          {
            host = var.grafana_hostname
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
              }
            ]
          }
        ]
        tls = [
          {
            secretName = "grafana-tls"
            hosts      = [var.grafana_hostname]
          }
        ]
      }
      
      # Grafana configuration
      "grafana.ini" = {
        server = {
          root_url = "https://${var.grafana_hostname}"
        }
        security = {
          admin_user     = var.grafana_admin_user
          admin_password = var.grafana_admin_password
        }
        auth = {
          disable_login_form = false
        }
        "auth.anonymous" = {
          enabled = false
        }
        analytics = {
          reporting_enabled = false
        }
        log = {
          mode  = "console"
          level = "info"
        }
        metrics = {
          enabled = true
        }
      }
      
      # Datasources
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-server.${local.monitoring_namespace}.svc.cluster.local"
              access    = "proxy"
              isDefault = true
            },
            {
              name   = "Azure Monitor Prometheus"
              type   = "prometheus"
              url    = azurerm_monitor_workspace.prometheus.query_endpoint
              access = "proxy"
              jsonData = {
                httpMethod = "POST"
                azureAuth = {
                  authType = "msi"
                }
              }
            },
            {
              name   = "Jaeger"
              type   = "jaeger"
              url    = "http://jaeger-query.${local.monitoring_namespace}.svc.cluster.local:16686"
              access = "proxy"
            }
          ]
        }
      }
      
      # Dashboard providers
      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "istio-dashboards"
              orgId           = 1
              folder          = "Istio"
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/istio"
              }
            },
            {
              name            = "infrastructure-dashboards"
              orgId           = 1
              folder          = "Infrastructure"
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/infrastructure"
              }
            }
          ]
        }
      }
      
      # Dashboards
      dashboards = {
        istio = local.grafana_dashboards
      }
      
      # Sidecar for dashboard discovery
      sidecar = {
        dashboards = {
          enabled = true
          label   = "grafana_dashboard"
        }
        datasources = {
          enabled = true
          label   = "grafana_datasource"
        }
      }
      
      # Security context
      securityContext = {
        runAsUser  = 472
        runAsGroup = 472
        fsGroup    = 472
      }
      
      # Node selector and tolerations
      nodeSelector = var.monitoring_node_selector
      tolerations  = var.monitoring_tolerations
    })
  ]
  
  depends_on = [kubernetes_namespace.monitoring]
}

# ===============================================================================
# JAEGER TRACING
# ===============================================================================

# Jaeger Operator
resource "helm_release" "jaeger_operator" {
  name       = "jaeger-operator"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger-operator"
  version    = var.jaeger_operator_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  
  values = [
    yamlencode({
      jaeger = {
        create = false
      }
      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
      }
    })
  ]
}

# Jaeger instance
resource "kubectl_manifest" "jaeger_instance" {
  yaml_body = <<-YAML
    apiVersion: jaegertracing.io/v1
    kind: Jaeger
    metadata:
      name: jaeger
      namespace: ${local.monitoring_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      strategy: production
      storage:
        type: elasticsearch
        elasticsearch:
          nodeCount: 3
          redundancyPolicy: SingleRedundancy
          resources:
            requests:
              cpu: 200m
              memory: 1Gi
            limits:
              cpu: 1000m
              memory: 2Gi
          storage:
            storageClassName: managed-premium
            size: 50Gi
      collector:
        replicas: 3
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        config:
          span-storage-type: elasticsearch
      query:
        replicas: 2
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        ingress:
          enabled: true
          annotations:
            kubernetes.io/ingress.class: nginx
            nginx.ingress.kubernetes.io/ssl-redirect: "true"
            cert-manager.io/cluster-issuer: letsencrypt-prod
          hosts:
          - ${var.jaeger_hostname}
          tls:
          - secretName: jaeger-tls
            hosts:
            - ${var.jaeger_hostname}
      agent:
        strategy: DaemonSet
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
  YAML
  
  depends_on = [helm_release.jaeger_operator]
}

# ===============================================================================
# KIALI SERVICE MESH OBSERVABILITY
# ===============================================================================

# Kiali Operator
resource "helm_release" "kiali_operator" {
  name       = "kiali-operator"
  repository = "https://kiali.org/helm-charts"
  chart      = "kiali-operator"
  version    = var.kiali_operator_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  
  values = [
    yamlencode({
      cr = {
        create = false
      }
    })
  ]
}

# Kiali instance
resource "kubectl_manifest" "kiali_instance" {
  yaml_body = <<-YAML
    apiVersion: kiali.io/v1alpha1
    kind: Kiali
    metadata:
      name: kiali
      namespace: ${local.monitoring_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      installation_tag: "v1.73.0"
      istio_namespace: ${local.istio_namespace}
      
      auth:
        strategy: anonymous
      
      deployment:
        accessible_namespaces:
        - "**"
        image_name: quay.io/kiali/kiali
        image_version: v1.73
        ingress:
          enabled: true
          class_name: nginx
          override_yaml:
            metadata:
              annotations:
                nginx.ingress.kubernetes.io/ssl-redirect: "true"
                cert-manager.io/cluster-issuer: letsencrypt-prod
            spec:
              rules:
              - host: ${var.kiali_hostname}
                http:
                  paths:
                  - path: /
                    pathType: Prefix
                    backend:
                      service:
                        name: kiali
                        port:
                          number: 20001
              tls:
              - secretName: kiali-tls
                hosts:
                - ${var.kiali_hostname}
        namespace: ${local.monitoring_namespace}
        replicas: 2
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 1Gi
        
      external_services:
        prometheus:
          url: http://prometheus-server.${local.monitoring_namespace}.svc.cluster.local
        grafana:
          enabled: true
          in_cluster_url: http://grafana.${local.monitoring_namespace}.svc.cluster.local
          url: https://${var.grafana_hostname}
        jaeger:
          enabled: true
          in_cluster_url: http://jaeger-query.${local.monitoring_namespace}.svc.cluster.local:16686
          url: https://${var.jaeger_hostname}
        
      server:
        port: 20001
        web_root: /kiali
  YAML
  
  depends_on = [helm_release.kiali_operator]
}

# ===============================================================================
# ALERTMANAGER CONFIGURATION
# ===============================================================================

# AlertManager configuration
resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "alertmanager-config"
    namespace = local.monitoring_namespace
    labels    = local.common_labels
  }
  
  data = {
    "alertmanager.yml" = templatefile("${path.module}/configs/alertmanager.yml", {
      slack_webhook_url = var.slack_webhook_url
      email_to         = var.alert_email_to
      email_from       = var.alert_email_from
      smtp_host        = var.smtp_host
      smtp_port        = var.smtp_port
    })
  }
}

# AlertManager Helm Chart
resource "helm_release" "alertmanager" {
  name       = "alertmanager"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "alertmanager"
  version    = var.alertmanager_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  
  values = [
    yamlencode({
      replicaCount = 2
      
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
      
      persistence = {
        enabled      = true
        size        = "5Gi"
        storageClass = "managed-premium"
      }
      
      config = {
        global = {
          smtp_smarthost = "${var.smtp_host}:${var.smtp_port}"
          smtp_from      = var.alert_email_from
        }
        route = {
          group_by        = ["alertname", "cluster", "service"]
          group_wait      = "10s"
          group_interval  = "10s"
          repeat_interval = "1h"
          receiver        = "web.hook"
        }
        receivers = [
          {
            name = "web.hook"
            slack_configs = [
              {
                api_url     = var.slack_webhook_url
                channel     = "#alerts"
                title       = "Istio AKS Alert"
                text        = "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}{{ end }}"
                send_resolved = true
              }
            ]
            email_configs = [
              {
                to      = var.alert_email_to
                subject = "Istio AKS Alert: {{ .GroupLabels.alertname }}"
                body    = "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}{{ end }}"
              }
            ]
          }
        ]
      }
      
      ingress = {
        enabled = true
        annotations = {
          "kubernetes.io/ingress.class" = "nginx"
          "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        hosts = [
          {
            host = var.alertmanager_hostname
            paths = ["/"]
          }
        ]
        tls = [
          {
            secretName = "alertmanager-tls"
            hosts      = [var.alertmanager_hostname]
          }
        ]
      }
      
      nodeSelector = var.monitoring_node_selector
      tolerations  = var.monitoring_tolerations
    })
  ]
  
  depends_on = [kubernetes_config_map.alertmanager_config]
}

# ===============================================================================
# PROMETHEUS RULES AND ALERTS
# ===============================================================================

# PrometheusRule for Istio alerts
resource "kubectl_manifest" "istio_prometheus_rules" {
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: PrometheusRule
    metadata:
      name: istio-alerts
      namespace: ${local.monitoring_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      groups:
      - name: istio.rules
        interval: 30s
        rules:
        # Recording rules
        - record: istio:request_total_rate5m
          expr: sum(rate(istio_requests_total[5m])) by (source_app, destination_service_name, destination_service_namespace)
        
        - record: istio:request_duration_milliseconds_p99
          expr: histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (source_app, destination_service_name, le))
        
        - record: istio:request_success_rate
          expr: sum(rate(istio_requests_total{response_code!~"5.."}[5m])) by (source_app, destination_service_name) / sum(rate(istio_requests_total[5m])) by (source_app, destination_service_name)
        
        # Alert rules
        - alert: IstioHighRequestLatency
          expr: histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (destination_service_name, destination_service_namespace, le)) > 1000
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "High request latency on {{ $labels.destination_service_name }}"
            description: "{{ $labels.destination_service_name }} has a 99th percentile latency of {{ $value }}ms"
        
        - alert: IstioHighErrorRate
          expr: sum(rate(istio_requests_total{response_code=~"5.."}[5m])) by (destination_service_name, destination_service_namespace) / sum(rate(istio_requests_total[5m])) by (destination_service_name, destination_service_namespace) > 0.01
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "High error rate on {{ $labels.destination_service_name }}"
            description: "{{ $labels.destination_service_name }} has an error rate of {{ $value | humanizePercentage }}"
        
        - alert: IstioLowSuccessRate
          expr: sum(rate(istio_requests_total{response_code!~"5.."}[5m])) by (destination_service_name, destination_service_namespace) / sum(rate(istio_requests_total[5m])) by (destination_service_name, destination_service_namespace) < 0.95
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "Low success rate on {{ $labels.destination_service_name }}"
            description: "{{ $labels.destination_service_name }} has a success rate of {{ $value | humanizePercentage }}"
        
        - alert: IstioGatewayDown
          expr: up{job="istio-mesh",app="istio-ingressgateway"} == 0
          for: 30s
          labels:
            severity: critical
          annotations:
            summary: "Istio Gateway is down"
            description: "Istio Ingress Gateway has been down for more than 30 seconds"
        
        - alert: IstiodDown
          expr: up{job="istio-mesh",app="istiod"} == 0
          for: 30s
          labels:
            severity: critical
          annotations:
            summary: "Istiod is down"
            description: "Istiod control plane has been down for more than 30 seconds"
  YAML
}

# ===============================================================================
# CUSTOM METRICS AND DASHBOARDS
# ===============================================================================

# Custom metrics for business KPIs
resource "kubectl_manifest" "business_metrics_config" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: business-metrics-config
      namespace: ${local.monitoring_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    data:
      business-metrics.yml: |
        metrics:
          - name: ecommerce_orders_total
            help: Total number of orders processed
            type: counter
            labels: [status, payment_method, region]
          
          - name: ecommerce_revenue_total
            help: Total revenue generated
            type: counter
            labels: [currency, region, product_category]
          
          - name: ecommerce_cart_abandonment_rate
            help: Cart abandonment rate
            type: gauge
            labels: [region, user_segment]
          
          - name: ecommerce_user_sessions_active
            help: Number of active user sessions
            type: gauge
            labels: [region, device_type]
          
          - name: ecommerce_product_views_total
            help: Total product views
            type: counter
            labels: [product_id, category, region]
          
          - name: ecommerce_search_queries_total
            help: Total search queries
            type: counter
            labels: [query_type, results_count, region]
  YAML
}

# ===============================================================================
# LOG AGGREGATION
# ===============================================================================

# Fluent Bit for log collection
resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = var.fluent_bit_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  
  values = [
    yamlencode({
      config = {
        service = "[SERVICE]\n    Daemon Off\n    Flush 1\n    Log_Level info\n    Parsers_File parsers.conf\n    Parsers_File custom_parsers.conf\n    HTTP_Server On\n    HTTP_Listen 0.0.0.0\n    HTTP_Port 2020\n    Health_Check On"
        
        inputs = "[INPUT]\n    Name tail\n    Path /var/log/containers/*.log\n    multiline.parser docker, cri\n    Tag kube.*\n    Mem_Buf_Limit 50MB\n    Skip_Long_Lines On\n\n[INPUT]\n    Name systemd\n    Tag host.*\n    Systemd_Filter _SYSTEMD_UNIT=kubelet.service\n    Read_From_Tail On"
        
        filters = "[FILTER]\n    Name kubernetes\n    Match kube.*\n    Kube_URL https://kubernetes.default.svc:443\n    Kube_CA_File /var/run/secrets/kubernetes.io/serviceaccount/ca.crt\n    Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token\n    Kube_Tag_Prefix kube.var.log.containers.\n    Merge_Log On\n    Keep_Log Off\n    K8S-Logging.Parser On\n    K8S-Logging.Exclude On\n\n[FILTER]\n    Name nest\n    Match kube.*\n    Operation lift\n    Nested_under kubernetes\n    Add_prefix kubernetes_"
        
        outputs = "[OUTPUT]\n    Name azure_logs_ingestion\n    Match kube.*\n    Customer_ID ${var.log_analytics_workspace_id}\n    Shared_Key ${var.log_analytics_primary_key}\n    Log_Type FluentBitLogs\n    Time_Key @timestamp\n    Time_Generated On"
      }
      
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
      
      nodeSelector = var.monitoring_node_selector
      tolerations = concat(var.monitoring_tolerations, [
        {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ])
    })
  ]
}

# ===============================================================================
# PERFORMANCE MONITORING
# ===============================================================================

# Node Exporter for infrastructure metrics
resource "helm_release" "node_exporter" {
  name       = "node-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-node-exporter"
  version    = var.node_exporter_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  
  values = [
    yamlencode({
      service = {
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9100"
        }
      }
      
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "128Mi"
        }
      }
      
      nodeSelector = var.monitoring_node_selector
      tolerations = concat(var.monitoring_tolerations, [
        {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ])
    })
  ]
}

# ===============================================================================
# SYNTHETIC MONITORING
# ===============================================================================

# Blackbox Exporter for synthetic monitoring
resource "helm_release" "blackbox_exporter" {
  name       = "blackbox-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  version    = var.blackbox_exporter_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  
  values = [
    yamlencode({
      config = {
        modules = {
          http_2xx = {
            prober = "http"
            timeout = "5s"
            http = {
              valid_http_versions = ["HTTP/1.1", "HTTP/2.0"]
              valid_status_codes = []
              method = "GET"
              follow_redirects = true
              preferred_ip_protocol = "ip4"
            }
          }
          http_post_2xx = {
            prober = "http"
            timeout = "5s"
            http = {
              valid_http_versions = ["HTTP/1.1", "HTTP/2.0"]
              method = "POST"
              headers = {
                "Content-Type" = "application/json"
              }
              body = "{\"health\":\"check\"}"
            }
          }
          tcp_connect = {
            prober = "tcp"
            timeout = "5s"
          }
        }
      }
      
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "128Mi"
        }
      }
      
      nodeSelector = var.monitoring_node_selector
      tolerations  = var.monitoring_tolerations
    })
  ]
}
