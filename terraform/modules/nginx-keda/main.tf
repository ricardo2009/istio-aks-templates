# ===============================================================================
# NGINX INGRESS CONTROLLER & KEDA MODULE - MAIN CONFIGURATION
# ===============================================================================
# Módulo responsável por configurar NGINX Ingress Controller (não-gerenciado)
# e KEDA (gerenciado) para autoscaling avançado
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
  }
}

# ===============================================================================
# PROVIDER CONFIGURATION
# ===============================================================================

provider "kubernetes" {
  host                   = var.cluster.host
  client_certificate     = base64decode(var.cluster.client_certificate)
  client_key            = base64decode(var.cluster.client_key)
  cluster_ca_certificate = base64decode(var.cluster.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = var.cluster.host
    client_certificate     = base64decode(var.cluster.client_certificate)
    client_key            = base64decode(var.cluster.client_key)
    cluster_ca_certificate = base64decode(var.cluster.cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = var.cluster.host
  client_certificate     = base64decode(var.cluster.client_certificate)
  client_key            = base64decode(var.cluster.client_key)
  cluster_ca_certificate = base64decode(var.cluster.cluster_ca_certificate)
  load_config_file       = false
}

# ===============================================================================
# LOCAL VALUES
# ===============================================================================

locals {
  # Namespaces
  nginx_namespace = "nginx-ingress"
  keda_namespace  = "keda-system"
  
  # NGINX Ingress configuration
  nginx_config = {
    replica_count = var.nginx_replica_count
    node_selector = var.nginx_node_selector
    tolerations   = var.nginx_tolerations
    resources = {
      requests = {
        cpu    = var.nginx_resources.requests.cpu
        memory = var.nginx_resources.requests.memory
      }
      limits = {
        cpu    = var.nginx_resources.limits.cpu
        memory = var.nginx_resources.limits.memory
      }
    }
  }
  
  # KEDA configuration
  keda_config = {
    operator_replica_count      = var.keda_operator_replica_count
    metrics_server_replica_count = var.keda_metrics_server_replica_count
    webhooks_replica_count      = var.keda_webhooks_replica_count
  }
  
  # Common labels
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"   = "istio-aks-production"
  }
}

# ===============================================================================
# NAMESPACES
# ===============================================================================

resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = local.nginx_namespace
    labels = merge(local.common_labels, {
      "name" = local.nginx_namespace
      "istio-injection" = "disabled"  # Disable Istio injection for ingress
    })
  }
}

resource "kubernetes_namespace" "keda_system" {
  metadata {
    name = local.keda_namespace
    labels = merge(local.common_labels, {
      "name" = local.keda_namespace
      "istio-injection" = "disabled"  # Disable Istio injection for KEDA
    })
  }
}

# ===============================================================================
# NGINX INGRESS CONTROLLER
# ===============================================================================

# NGINX Ingress Controller Helm Chart
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.nginx_chart_version
  namespace  = kubernetes_namespace.nginx_ingress.metadata[0].name

  # High-performance configuration for 600k RPS
  values = [
    yamlencode({
      controller = {
        name = "controller"
        image = {
          registry = "registry.k8s.io"
          image    = "ingress-nginx/controller"
          tag      = var.nginx_image_tag
          digest   = ""
        }
        
        # Replica configuration
        replicaCount = local.nginx_config.replica_count
        minAvailable = max(1, local.nginx_config.replica_count - 1)
        
        # Resource configuration
        resources = local.nginx_config.resources
        
        # Node selection
        nodeSelector = local.nginx_config.node_selector
        tolerations  = local.nginx_config.tolerations
        
        # Affinity for high availability
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchExpressions = [
                      {
                        key      = "app.kubernetes.io/name"
                        operator = "In"
                        values   = ["ingress-nginx"]
                      }
                    ]
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
        
        # Service configuration
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/healthz"
            "service.beta.kubernetes.io/azure-load-balancer-internal"                  = "false"
            "service.beta.kubernetes.io/azure-pip-name"                               = var.public_ip_name
            "service.beta.kubernetes.io/azure-dns-label-name"                         = var.dns_label
          }
          externalTrafficPolicy = "Local"
          sessionAffinity      = "None"
        }
        
        # High-performance configuration
        config = {
          # Connection settings
          "keep-alive-requests"           = "10000"
          "upstream-keepalive-connections" = "320"
          "upstream-keepalive-requests"   = "10000"
          "upstream-keepalive-timeout"    = "60"
          
          # Buffer settings
          "proxy-buffer-size"         = "16k"
          "proxy-buffers-number"      = "8"
          "client-body-buffer-size"   = "16k"
          "client-header-buffer-size" = "64k"
          "large-client-header-buffers" = "4 64k"
          
          # Timeout settings
          "proxy-connect-timeout"      = "5"
          "proxy-send-timeout"         = "60"
          "proxy-read-timeout"         = "60"
          "client-body-timeout"        = "60"
          "client-header-timeout"      = "60"
          "keepalive-timeout"          = "75"
          
          # Performance optimizations
          "worker-processes"           = "auto"
          "worker-connections"         = "16384"
          "worker-cpu-affinity"        = "auto"
          "worker-shutdown-timeout"    = "240s"
          "max-worker-open-files"      = "65536"
          
          # Rate limiting
          "rate-limit-rps"             = "1000"
          "rate-limit-connections"     = "100"
          
          # Compression
          "enable-brotli"              = "true"
          "brotli-level"               = "6"
          "brotli-types"               = "text/xml image/svg+xml application/x-font-ttf image/vnd.microsoft.icon application/x-font-opentype application/json font/eot application/vnd.ms-fontobject application/javascript font/otf application/xml application/xhtml+xml text/javascript application/x-javascript text/plain application/x-font-truetype application/xml+rss image/x-icon font/opentype text/css image/x-win-bitmap"
          
          # SSL/TLS
          "ssl-protocols"              = "TLSv1.2 TLSv1.3"
          "ssl-ciphers"                = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
          "ssl-prefer-server-ciphers"  = "off"
          "ssl-session-cache"          = "shared:SSL:10m"
          "ssl-session-timeout"        = "10m"
          
          # Security headers
          "add-headers"                = "nginx-ingress/custom-headers"
          
          # Monitoring
          "enable-opentracing"         = "true"
          "jaeger-collector-host"      = var.jaeger_collector_host
          "jaeger-service-name"        = "nginx-ingress"
          
          # Custom error pages
          "custom-http-errors"         = "404,503"
        }
        
        # Metrics configuration
        metrics = {
          enabled = true
          service = {
            annotations = {
              "prometheus.io/scrape" = "true"
              "prometheus.io/port"   = "10254"
            }
          }
          serviceMonitor = {
            enabled = var.enable_prometheus_monitoring
          }
        }
        
        # Health checks
        livenessProbe = {
          httpGet = {
            path   = "/healthz"
            port   = 10254
            scheme = "HTTP"
          }
          initialDelaySeconds = 10
          periodSeconds       = 10
          timeoutSeconds      = 1
          successThreshold    = 1
          failureThreshold    = 5
        }
        
        readinessProbe = {
          httpGet = {
            path   = "/healthz"
            port   = 10254
            scheme = "HTTP"
          }
          initialDelaySeconds = 10
          periodSeconds       = 1
          timeoutSeconds      = 1
          successThreshold    = 1
          failureThreshold    = 3
        }
        
        # Lifecycle hooks
        lifecycle = {
          preStop = {
            exec = {
              command = ["/wait-shutdown"]
            }
          }
        }
        
        # Admission webhooks
        admissionWebhooks = {
          enabled = true
          patch = {
            enabled = true
          }
        }
      }
      
      # Default backend
      defaultBackend = {
        enabled = true
        name    = "default-backend"
        image = {
          registry   = "registry.k8s.io"
          image      = "defaultbackend-amd64"
          tag        = "1.5"
        }
        replicaCount = 2
        resources = {
          requests = {
            cpu    = "10m"
            memory = "20Mi"
          }
          limits = {
            cpu    = "20m"
            memory = "30Mi"
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.nginx_ingress]
}

# Custom headers ConfigMap
resource "kubernetes_config_map" "custom_headers" {
  metadata {
    name      = "custom-headers"
    namespace = kubernetes_namespace.nginx_ingress.metadata[0].name
  }

  data = {
    "X-Frame-Options"           = "SAMEORIGIN"
    "X-Content-Type-Options"    = "nosniff"
    "X-XSS-Protection"          = "1; mode=block"
    "Referrer-Policy"           = "strict-origin-when-cross-origin"
    "Content-Security-Policy"   = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; media-src 'self'; object-src 'none'; child-src 'none'; frame-ancestors 'self'; base-uri 'self'; form-action 'self';"
    "Strict-Transport-Security" = "max-age=31536000; includeSubDomains; preload"
    "X-Robots-Tag"              = "noindex, nofollow"
  }

  depends_on = [kubernetes_namespace.nginx_ingress]
}

# ===============================================================================
# KEDA (Kubernetes Event-driven Autoscaling)
# ===============================================================================

# KEDA Helm Chart
resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_chart_version
  namespace  = kubernetes_namespace.keda_system.metadata[0].name

  values = [
    yamlencode({
      # Operator configuration
      operator = {
        name         = "keda-operator"
        replicaCount = local.keda_config.operator_replica_count
        
        resources = {
          requests = {
            cpu    = var.keda_operator_resources.requests.cpu
            memory = var.keda_operator_resources.requests.memory
          }
          limits = {
            cpu    = var.keda_operator_resources.limits.cpu
            memory = var.keda_operator_resources.limits.memory
          }
        }
        
        # Node selection
        nodeSelector = var.keda_node_selector
        tolerations  = var.keda_tolerations
        
        # Affinity
        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchExpressions = [
                      {
                        key      = "app"
                        operator = "In"
                        values   = ["keda-operator"]
                      }
                    ]
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }
      }
      
      # Metrics server configuration
      metricsServer = {
        replicaCount = local.keda_config.metrics_server_replica_count
        
        resources = {
          requests = {
            cpu    = var.keda_metrics_server_resources.requests.cpu
            memory = var.keda_metrics_server_resources.requests.memory
          }
          limits = {
            cpu    = var.keda_metrics_server_resources.limits.cpu
            memory = var.keda_metrics_server_resources.limits.memory
          }
        }
        
        # Node selection
        nodeSelector = var.keda_node_selector
        tolerations  = var.keda_tolerations
      }
      
      # Webhooks configuration
      webhooks = {
        enabled      = true
        replicaCount = local.keda_config.webhooks_replica_count
        
        resources = {
          requests = {
            cpu    = var.keda_webhooks_resources.requests.cpu
            memory = var.keda_webhooks_resources.requests.memory
          }
          limits = {
            cpu    = var.keda_webhooks_resources.limits.cpu
            memory = var.keda_webhooks_resources.limits.memory
          }
        }
        
        # Node selection
        nodeSelector = var.keda_node_selector
        tolerations  = var.keda_tolerations
      }
      
      # Prometheus metrics
      prometheus = {
        metricServer = {
          enabled = var.enable_prometheus_monitoring
          port    = 9022
        }
        operator = {
          enabled = var.enable_prometheus_monitoring
          port    = 8080
        }
        webhooks = {
          enabled = var.enable_prometheus_monitoring
          port    = 8080
        }
      }
      
      # Logging configuration
      logging = {
        operator = {
          level  = var.keda_log_level
          format = "json"
        }
        metricServer = {
          level = var.keda_log_level
        }
        webhooks = {
          level = var.keda_log_level
        }
      }
      
      # Security context
      securityContext = {
        operator = {
          runAsNonRoot = true
          runAsUser    = 1001
          capabilities = {
            drop = ["ALL"]
          }
        }
      }
      
      # Pod disruption budgets
      podDisruptionBudget = {
        operator = {
          enabled        = true
          minAvailable   = 1
          maxUnavailable = null
        }
        metricsServer = {
          enabled        = true
          minAvailable   = 1
          maxUnavailable = null
        }
        webhooks = {
          enabled        = true
          minAvailable   = 1
          maxUnavailable = null
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.keda_system]
}

# ===============================================================================
# KEDA SCALED OBJECTS FOR MICROSERVICES
# ===============================================================================

# ScaledObject for API Gateway
resource "kubectl_manifest" "api_gateway_scaled_object" {
  yaml_body = <<-YAML
    apiVersion: keda.sh/v1alpha1
    kind: ScaledObject
    metadata:
      name: api-gateway-scaler
      namespace: ${var.applications_namespace}
    spec:
      scaleTargetRef:
        name: api-gateway
      minReplicaCount: ${var.api_gateway_min_replicas}
      maxReplicaCount: ${var.api_gateway_max_replicas}
      pollingInterval: 15
      cooldownPeriod: 300
      idleReplicaCount: ${var.api_gateway_min_replicas}
      triggers:
      - type: prometheus
        metadata:
          serverAddress: ${var.prometheus_server_address}
          metricName: http_requests_per_second
          threshold: '100'
          query: sum(rate(http_requests_total{job="api-gateway"}[1m]))
      - type: prometheus
        metadata:
          serverAddress: ${var.prometheus_server_address}
          metricName: cpu_usage_percentage
          threshold: '70'
          query: avg(rate(container_cpu_usage_seconds_total{pod=~"api-gateway-.*"}[1m])) * 100
      - type: prometheus
        metadata:
          serverAddress: ${var.prometheus_server_address}
          metricName: memory_usage_percentage
          threshold: '80'
          query: avg(container_memory_working_set_bytes{pod=~"api-gateway-.*"} / container_spec_memory_limit_bytes{pod=~"api-gateway-.*"}) * 100
  YAML

  depends_on = [helm_release.keda]
}

# ScaledObject for User Service
resource "kubectl_manifest" "user_service_scaled_object" {
  yaml_body = <<-YAML
    apiVersion: keda.sh/v1alpha1
    kind: ScaledObject
    metadata:
      name: user-service-scaler
      namespace: ${var.applications_namespace}
    spec:
      scaleTargetRef:
        name: user-service
      minReplicaCount: ${var.user_service_min_replicas}
      maxReplicaCount: ${var.user_service_max_replicas}
      pollingInterval: 30
      cooldownPeriod: 600
      triggers:
      - type: prometheus
        metadata:
          serverAddress: ${var.prometheus_server_address}
          metricName: http_requests_per_second
          threshold: '50'
          query: sum(rate(http_requests_total{job="user-service"}[2m]))
      - type: prometheus
        metadata:
          serverAddress: ${var.prometheus_server_address}
          metricName: response_time_p95
          threshold: '500'
          query: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="user-service"}[2m])) by (le)) * 1000
  YAML

  depends_on = [helm_release.keda]
}

# ScaledObject for Product Service
resource "kubectl_manifest" "product_service_scaled_object" {
  yaml_body = <<-YAML
    apiVersion: keda.sh/v1alpha1
    kind: ScaledObject
    metadata:
      name: product-service-scaler
      namespace: ${var.applications_namespace}
    spec:
      scaleTargetRef:
        name: product-service
      minReplicaCount: ${var.product_service_min_replicas}
      maxReplicaCount: ${var.product_service_max_replicas}
      pollingInterval: 15
      cooldownPeriod: 300
      triggers:
      - type: prometheus
        metadata:
          serverAddress: ${var.prometheus_server_address}
          metricName: http_requests_per_second
          threshold: '200'
          query: sum(rate(http_requests_total{job="product-service"}[1m]))
      - type: redis
        metadata:
          address: ${var.redis_address}
          listName: product_search_queue
          listLength: '10'
  YAML

  depends_on = [helm_release.keda]
}

# ScaledObject for Order Service
resource "kubectl_manifest" "order_service_scaled_object" {
  yaml_body = <<-YAML
    apiVersion: keda.sh/v1alpha1
    kind: ScaledObject
    metadata:
      name: order-service-scaler
      namespace: ${var.applications_namespace}
    spec:
      scaleTargetRef:
        name: order-service
      minReplicaCount: ${var.order_service_min_replicas}
      maxReplicaCount: ${var.order_service_max_replicas}
      pollingInterval: 10
      cooldownPeriod: 180
      triggers:
      - type: prometheus
        metadata:
          serverAddress: ${var.prometheus_server_address}
          metricName: pending_orders
          threshold: '20'
          query: sum(pending_orders_total{job="order-service"})
      - type: azure-servicebus
        metadata:
          connectionFromEnv: SERVICEBUS_CONNECTION_STRING
          queueName: order-processing-queue
          messageCount: '5'
  YAML

  depends_on = [helm_release.keda]
}

# ScaledObject for Payment Service
resource "kubectl_manifest" "payment_service_scaled_object" {
  yaml_body = <<-YAML
    apiVersion: keda.sh/v1alpha1
    kind: ScaledObject
    metadata:
      name: payment-service-scaler
      namespace: ${var.applications_namespace}
    spec:
      scaleTargetRef:
        name: payment-service
      minReplicaCount: ${var.payment_service_min_replicas}
      maxReplicaCount: ${var.payment_service_max_replicas}
      pollingInterval: 5
      cooldownPeriod: 120
      triggers:
      - type: prometheus
        metadata:
          serverAddress: ${var.prometheus_server_address}
          metricName: payment_queue_length
          threshold: '10'
          query: sum(payment_queue_length{job="payment-service"})
      - type: prometheus
        metadata:
          serverAddress: ${var.prometheus_server_address}
          metricName: payment_processing_time
          threshold: '2000'
          query: avg(payment_processing_duration_seconds{job="payment-service"}) * 1000
  YAML

  depends_on = [helm_release.keda]
}

# ===============================================================================
# HORIZONTAL POD AUTOSCALER BACKUP
# ===============================================================================

# Backup HPA for critical services (in case KEDA fails)
resource "kubernetes_horizontal_pod_autoscaler_v2" "api_gateway_hpa_backup" {
  metadata {
    name      = "api-gateway-hpa-backup"
    namespace = var.applications_namespace
    labels = {
      "backup-hpa" = "true"
    }
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "api-gateway"
    }

    min_replicas = var.api_gateway_min_replicas
    max_replicas = var.api_gateway_max_replicas

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 60
        select_policy               = "Max"
        policy {
          type          = "Percent"
          value         = 100
          period_seconds = 15
        }
        policy {
          type          = "Pods"
          value         = 4
          period_seconds = 60
        }
      }

      scale_down {
        stabilization_window_seconds = 300
        select_policy               = "Min"
        policy {
          type          = "Percent"
          value         = 10
          period_seconds = 60
        }
      }
    }
  }
}
