# ===============================================================================
# CROSS-CLUSTER COMMUNICATION MODULE - MAIN CONFIGURATION
# ===============================================================================
# Módulo responsável por configurar comunicação segura entre clusters AKS
# com Istio Service Mesh, incluindo service discovery automático e mTLS
# ===============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
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
  # Cluster configurations
  clusters = {
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
  
  # Istio configuration
  istio_namespace = "istio-system"
  
  # Common labels
  common_labels = {
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/part-of"   = "istio-cross-cluster"
    "istio.io/rev"                = var.istio_revision
  }
  
  # Cross-cluster endpoints
  cross_cluster_endpoints = {
    for cluster_name, cluster in local.clusters : cluster_name => {
      discovery_address = "${cluster.name}-istio-discovery.${cluster.region}.cloudapp.azure.com"
      eastwest_gateway  = "${cluster.name}-eastwest-gateway.${cluster.region}.cloudapp.azure.com"
    }
  }
}

# ===============================================================================
# ISTIO MULTI-CLUSTER CONFIGURATION
# ===============================================================================

# Configure Istio for multi-cluster mesh
resource "kubectl_manifest" "istio_multicluster_config" {
  for_each = local.clusters
  
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: istio-multicluster-config
      namespace: ${local.istio_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    data:
      mesh: |
        defaultConfig:
          meshId: ${each.value.mesh_id}
          cluster: ${each.key}
        trustDomain: cluster.local
        defaultProviders:
          metrics:
          - prometheus
        extensionProviders:
        - name: prometheus
          prometheus:
            configOverride:
              metric_relabeling_configs:
              - source_labels: [__name__]
                regex: 'istio_.*'
                target_label: cluster
                replacement: ${each.key}
        - name: jaeger
          envoyExtAuthzHttp:
            service: jaeger-collector.istio-system.svc.cluster.local
            port: 14268
      networks: |
        networks:
          ${each.value.network}:
            endpoints:
            - fromRegistry: ${each.key}
            gateways:
            - registryServiceName: istio-eastwestgateway.istio-system.svc.cluster.local
              port: 15443
  YAML
}

# ===============================================================================
# EAST-WEST GATEWAY CONFIGURATION
# ===============================================================================

# East-West Gateway for cross-cluster communication
resource "kubectl_manifest" "eastwest_gateway" {
  for_each = local.clusters
  
  yaml_body = <<-YAML
    apiVersion: install.istio.io/v1alpha1
    kind: IstioOperator
    metadata:
      name: eastwest-gateway-${each.key}
      namespace: ${local.istio_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      revision: ${var.istio_revision}
      components:
        ingressGateways:
        - name: istio-eastwestgateway
          label:
            istio: eastwestgateway
            app: istio-eastwestgateway
          enabled: true
          k8s:
            service:
              type: LoadBalancer
              annotations:
                service.beta.kubernetes.io/azure-load-balancer-internal: "false"
                service.beta.kubernetes.io/azure-dns-label-name: ${each.value.name}-eastwest
                service.beta.kubernetes.io/azure-pip-name: ${each.value.name}-eastwest-pip
              ports:
              - port: 15021
                targetPort: 15021
                name: status-port
                protocol: TCP
              - port: 15443
                targetPort: 15443
                name: tls
                protocol: TCP
            resources:
              requests:
                cpu: 500m
                memory: 512Mi
              limits:
                cpu: 2000m
                memory: 2Gi
            hpaSpec:
              minReplicas: 2
              maxReplicas: 10
              metrics:
              - type: Resource
                resource:
                  name: cpu
                  target:
                    type: Utilization
                    averageUtilization: 70
            nodeSelector:
              kubernetes.io/os: linux
            tolerations:
            - key: CriticalAddonsOnly
              operator: Exists
            affinity:
              podAntiAffinity:
                preferredDuringSchedulingIgnoredDuringExecution:
                - weight: 100
                  podAffinityTerm:
                    labelSelector:
                      matchLabels:
                        app: istio-eastwestgateway
                    topologyKey: kubernetes.io/hostname
      values:
        gateways:
          istio-eastwestgateway:
            injectionTemplate: gateway
        global:
          meshID: ${each.value.mesh_id}
          cluster: ${each.key}
          network: ${each.value.network}
  YAML
}

# Gateway configuration for cross-cluster traffic
resource "kubectl_manifest" "cross_cluster_gateway" {
  for_each = local.clusters
  
  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: Gateway
    metadata:
      name: cross-network-gateway
      namespace: ${local.istio_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      selector:
        istio: eastwestgateway
      servers:
      - port:
          number: 15443
          name: tls
          protocol: TLS
        tls:
          mode: ISTIO_MUTUAL
        hosts:
        - "*.local"
  YAML
  
  depends_on = [kubectl_manifest.eastwest_gateway]
}

# ===============================================================================
# SERVICE DISCOVERY CONFIGURATION
# ===============================================================================

# Expose Istio control plane for cross-cluster discovery
resource "kubectl_manifest" "istiod_service_exposure" {
  for_each = local.clusters
  
  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: Gateway
    metadata:
      name: istiod-gateway
      namespace: ${local.istio_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      selector:
        istio: eastwestgateway
      servers:
      - port:
          number: 15012
          name: tls-istiod
          protocol: TLS
        tls:
          mode: PASSTHROUGH
        hosts:
        - istiod.${local.istio_namespace}.svc.cluster.local
  YAML
  
  depends_on = [kubectl_manifest.cross_cluster_gateway]
}

# VirtualService for istiod exposure
resource "kubectl_manifest" "istiod_virtualservice" {
  for_each = local.clusters
  
  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: VirtualService
    metadata:
      name: istiod-vs
      namespace: ${local.istio_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      hosts:
      - istiod.${local.istio_namespace}.svc.cluster.local
      gateways:
      - istiod-gateway
      tls:
      - match:
        - port: 15012
          sniHosts:
          - istiod.${local.istio_namespace}.svc.cluster.local
        route:
        - destination:
            host: istiod.${local.istio_namespace}.svc.cluster.local
            port:
              number: 15012
  YAML
  
  depends_on = [kubectl_manifest.istiod_service_exposure]
}

# ===============================================================================
# CLUSTER SECRETS FOR CROSS-CLUSTER ACCESS
# ===============================================================================

# Create secrets for remote cluster access
resource "kubectl_manifest" "remote_cluster_secret" {
  for_each = {
    for pair in setproduct(keys(local.clusters), keys(local.clusters)) :
    "${pair[0]}-to-${pair[1]}" => {
      source_cluster = pair[0]
      target_cluster = pair[1]
    }
    if pair[0] != pair[1]
  }
  
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Secret
    metadata:
      name: istio-remote-secret-${each.value.target_cluster}
      namespace: ${local.istio_namespace}
      labels:
        istio/cluster: ${each.value.target_cluster}
        ${yamlencode(local.common_labels)}
      annotations:
        networking.istio.io/cluster: ${each.value.target_cluster}
    type: Opaque
    data:
      ${each.value.target_cluster}: ${base64encode(templatefile("${path.module}/templates/kubeconfig.yaml", {
        cluster_name = local.clusters[each.value.target_cluster].cluster_name
        server_url   = "https://${local.cross_cluster_endpoints[each.value.target_cluster].discovery_address}:15012"
        ca_data      = var.cluster_ca_certificates[each.value.target_cluster]
        token        = var.cluster_tokens[each.value.target_cluster]
      }))}
  YAML
}

# ===============================================================================
# CROSS-CLUSTER SERVICE ENTRIES
# ===============================================================================

# Service entries for cross-cluster service discovery
resource "kubectl_manifest" "cross_cluster_service_entries" {
  for_each = var.cross_cluster_services
  
  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: ServiceEntry
    metadata:
      name: ${each.key}-cross-cluster
      namespace: ${each.value.namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      hosts:
      - ${each.value.service_name}.${each.value.namespace}.global
      location: MESH_EXTERNAL
      ports:
      - number: ${each.value.port}
        name: ${each.value.protocol}
        protocol: ${upper(each.value.protocol)}
      resolution: DNS
      addresses:
      - 240.0.0.${each.value.address_suffix}
      endpoints:
      ${yamlencode([
        for cluster in each.value.clusters : {
          address = "${each.value.service_name}.${each.value.namespace}.svc.cluster.local"
          network = local.clusters[cluster].network
          ports   = {
            (each.value.protocol) = each.value.port
          }
        }
      ])}
  YAML
}

# ===============================================================================
# DESTINATION RULES FOR CROSS-CLUSTER TRAFFIC
# ===============================================================================

# Destination rules for cross-cluster mTLS
resource "kubectl_manifest" "cross_cluster_destination_rules" {
  for_each = var.cross_cluster_services
  
  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: DestinationRule
    metadata:
      name: ${each.key}-cross-cluster-dr
      namespace: ${each.value.namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      host: ${each.value.service_name}.${each.value.namespace}.global
      trafficPolicy:
        tls:
          mode: ISTIO_MUTUAL
        connectionPool:
          tcp:
            maxConnections: 100
            connectTimeout: 30s
            keepAlive:
              time: 7200s
              interval: 75s
          http:
            http1MaxPendingRequests: 100
            http2MaxRequests: 1000
            maxRequestsPerConnection: 10
            maxRetries: 3
            consecutiveGatewayErrors: 5
            interval: 30s
            baseEjectionTime: 30s
            maxEjectionPercent: 50
        outlierDetection:
          consecutiveGatewayErrors: 5
          interval: 30s
          baseEjectionTime: 30s
          maxEjectionPercent: 50
          minHealthPercent: 50
      ${length(each.value.clusters) > 1 ? yamlencode({
        subsets = [
          for cluster in each.value.clusters : {
            name = cluster
            labels = {
              cluster = cluster
            }
            trafficPolicy = {
              tls = {
                mode = "ISTIO_MUTUAL"
              }
            }
          }
        ]
      }) : ""}
  YAML
}

# ===============================================================================
# VIRTUAL SERVICES FOR CROSS-CLUSTER ROUTING
# ===============================================================================

# Virtual services for intelligent cross-cluster routing
resource "kubectl_manifest" "cross_cluster_virtual_services" {
  for_each = var.cross_cluster_services
  
  yaml_body = <<-YAML
    apiVersion: networking.istio.io/v1beta1
    kind: VirtualService
    metadata:
      name: ${each.key}-cross-cluster-vs
      namespace: ${each.value.namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      hosts:
      - ${each.value.service_name}.${each.value.namespace}.global
      http:
      - match:
        - headers:
            cluster-preference:
              exact: local
        route:
        - destination:
            host: ${each.value.service_name}.${each.value.namespace}.global
            subset: ${var.primary_cluster.name}
          weight: 100
        fault:
          delay:
            percentage:
              value: 0.1
            fixedDelay: 5ms
      - match:
        - headers:
            cluster-preference:
              exact: remote
        route:
        - destination:
            host: ${each.value.service_name}.${each.value.namespace}.global
            subset: ${var.secondary_cluster.name}
          weight: 100
      - route:
        ${yamlencode([
          for i, cluster in each.value.clusters : {
            destination = {
              host   = "${each.value.service_name}.${each.value.namespace}.global"
              subset = cluster
            }
            weight = each.value.traffic_distribution[i]
          }
        ])}
        timeout: 30s
        retries:
          attempts: 3
          perTryTimeout: 10s
          retryOn: gateway-error,connect-failure,refused-stream
          retryRemoteLocalities: true
  YAML
  
  depends_on = [kubectl_manifest.cross_cluster_destination_rules]
}

# ===============================================================================
# PEER AUTHENTICATION FOR CROSS-CLUSTER mTLS
# ===============================================================================

# Peer authentication for strict mTLS
resource "kubectl_manifest" "cross_cluster_peer_authentication" {
  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1beta1
    kind: PeerAuthentication
    metadata:
      name: cross-cluster-mtls
      namespace: ${local.istio_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      mtls:
        mode: STRICT
  YAML
}

# Namespace-specific peer authentication
resource "kubectl_manifest" "namespace_peer_authentication" {
  for_each = toset(var.cross_cluster_namespaces)
  
  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1beta1
    kind: PeerAuthentication
    metadata:
      name: cross-cluster-mtls
      namespace: ${each.value}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      mtls:
        mode: STRICT
  YAML
}

# ===============================================================================
# AUTHORIZATION POLICIES FOR CROSS-CLUSTER ACCESS
# ===============================================================================

# Authorization policy for cross-cluster communication
resource "kubectl_manifest" "cross_cluster_authorization" {
  for_each = var.cross_cluster_services
  
  yaml_body = <<-YAML
    apiVersion: security.istio.io/v1beta1
    kind: AuthorizationPolicy
    metadata:
      name: ${each.key}-cross-cluster-authz
      namespace: ${each.value.namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      selector:
        matchLabels:
          app: ${each.value.service_name}
      rules:
      - from:
        - source:
            principals:
            ${yamlencode([
              for cluster in each.value.clusters :
              "cluster.local/ns/${each.value.namespace}/sa/${each.value.service_account}"
            ])}
        - source:
            namespaces:
            - ${each.value.namespace}
        to:
        - operation:
            methods: ${jsonencode(each.value.allowed_methods)}
        when:
        - key: source.cluster
          values: ${jsonencode(each.value.clusters)}
  YAML
}

# ===============================================================================
# TELEMETRY CONFIGURATION FOR CROSS-CLUSTER OBSERVABILITY
# ===============================================================================

# Telemetry configuration for cross-cluster metrics
resource "kubectl_manifest" "cross_cluster_telemetry" {
  yaml_body = <<-YAML
    apiVersion: telemetry.istio.io/v1alpha1
    kind: Telemetry
    metadata:
      name: cross-cluster-metrics
      namespace: ${local.istio_namespace}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      metrics:
      - providers:
        - name: prometheus
      - overrides:
        - match:
            metric: ALL_METRICS
          tagOverrides:
            source_cluster:
              value: "${var.primary_cluster_name}"
            destination_cluster:
              value: "${var.secondary_cluster_name}"
      tracing:
      - providers:
        - name: jaeger
      accessLogging:
      - providers:
        - name: otel
  YAML
}

# ===============================================================================
# NETWORK POLICIES FOR ADDITIONAL SECURITY
# ===============================================================================

# Network policy for cross-cluster communication
resource "kubectl_manifest" "cross_cluster_network_policy" {
  for_each = toset(var.cross_cluster_namespaces)
  
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: cross-cluster-network-policy
      namespace: ${each.value}
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      podSelector: {}
      policyTypes:
      - Ingress
      - Egress
      ingress:
      - from:
        - namespaceSelector:
            matchLabels:
              name: ${local.istio_namespace}
        - namespaceSelector:
            matchLabels:
              name: ${each.value}
        - podSelector:
            matchLabels:
              app: istio-proxy
      egress:
      - to:
        - namespaceSelector:
            matchLabels:
              name: ${local.istio_namespace}
        - namespaceSelector:
            matchLabels:
              name: ${each.value}
      - to: []
        ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 15443
        - protocol: TCP
          port: 15012
  YAML
}

# ===============================================================================
# MONITORING AND ALERTING
# ===============================================================================

# ServiceMonitor for cross-cluster metrics
resource "kubectl_manifest" "cross_cluster_service_monitor" {
  count = var.enable_prometheus_monitoring ? 1 : 0
  
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: cross-cluster-metrics
      namespace: monitoring
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      selector:
        matchLabels:
          app: istio-proxy
      endpoints:
      - port: http-monitoring
        interval: 15s
        path: /stats/prometheus
        relabelings:
        - sourceLabels: [__meta_kubernetes_pod_label_cluster]
          targetLabel: cluster
        - sourceLabels: [__meta_kubernetes_pod_label_region]
          targetLabel: region
  YAML
}

# PrometheusRule for cross-cluster alerts
resource "kubectl_manifest" "cross_cluster_prometheus_rules" {
  count = var.enable_prometheus_monitoring ? 1 : 0
  
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: PrometheusRule
    metadata:
      name: cross-cluster-alerts
      namespace: monitoring
      labels:
        ${yamlencode(local.common_labels)}
    spec:
      groups:
      - name: cross-cluster.rules
        rules:
        - alert: CrossClusterHighLatency
          expr: histogram_quantile(0.95, sum(rate(istio_request_duration_milliseconds_bucket{source_cluster!=destination_cluster}[5m])) by (le, source_cluster, destination_cluster)) > 100
          for: 2m
          labels:
            severity: warning
          annotations:
            summary: "High cross-cluster latency detected"
            description: "Cross-cluster communication latency is above 100ms between {{ $labels.source_cluster }} and {{ $labels.destination_cluster }}"
        
        - alert: CrossClusterHighErrorRate
          expr: sum(rate(istio_requests_total{source_cluster!=destination_cluster,response_code!~"2.."}[5m])) by (source_cluster, destination_cluster) / sum(rate(istio_requests_total{source_cluster!=destination_cluster}[5m])) by (source_cluster, destination_cluster) > 0.01
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "High cross-cluster error rate detected"
            description: "Cross-cluster error rate is above 1% between {{ $labels.source_cluster }} and {{ $labels.destination_cluster }}"
        
        - alert: CrossClusterConnectivityLoss
          expr: up{job="istio-mesh"} == 0
          for: 30s
          labels:
            severity: critical
          annotations:
            summary: "Cross-cluster connectivity lost"
            description: "Istio mesh connectivity lost for cluster {{ $labels.cluster }}"
  YAML
}
