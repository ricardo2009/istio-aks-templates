# Traffic Management with Istio and Flagger

## Overview

This document describes the traffic management strategy using Istio Service Mesh and Flagger for progressive delivery.

## Traffic Flow

```
Internet → APIM → NGINX Ingress → Istio Ingress Gateway → VirtualService → DestinationRule → Service → Pod
```

## Istio Traffic Management Resources

### 1. Virtual Services

VirtualServices define routing rules to services within the mesh.

**Example: Canary Deployment**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-service
  namespace: production
spec:
  hosts:
  - product-service.production.svc.cluster.local
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: product-service.production.svc.cluster.local
        subset: canary
      weight: 100
  - route:
    - destination:
        host: product-service.production.svc.cluster.local
        subset: stable
      weight: 90
    - destination:
        host: product-service.production.svc.cluster.local
        subset: canary
      weight: 10
    timeout: 5s
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: gateway-error,connect-failure,refused-stream
```

### 2. Destination Rules

DestinationRules configure traffic policies (load balancing, connection pooling, outlier detection).

**Example: Circuit Breaking & Connection Pooling**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: product-service
  namespace: production
spec:
  host: product-service.production.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      simple: LEAST_REQUEST  # or CONSISTENT_HASH for session affinity
    connectionPool:
      tcp:
        maxConnections: 1000
        connectTimeout: 3s
        tcpKeepalive:
          time: 7200s
          interval: 75s
      http:
        http1MaxPendingRequests: 1024
        http2MaxRequests: 1024
        maxRequestsPerConnection: 100
        maxRetries: 3
        idleTimeout: 3600s
        h2UpgradePolicy: UPGRADE  # Enable HTTP/2
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 50
  subsets:
  - name: stable
    labels:
      version: stable
  - name: canary
    labels:
      version: canary
    trafficPolicy:
      connectionPool:
        tcp:
          maxConnections: 500
        http:
          http1MaxPendingRequests: 512
```

### 3. Sidecar Configuration

Control egress traffic and resource usage.

**Example: Restrict Egress**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: production
spec:
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY  # Only allow traffic to registered services
  egress:
  - hosts:
    - "./*"  # Same namespace
    - "istio-system/*"  # System namespace
    - "*/product-service.production.svc.cluster.local"
```

### 4. Service Entry

Allow access to external services.

**Example: External API Access**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-api
  namespace: production
spec:
  hosts:
  - api.external-service.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: external-api
  namespace: production
spec:
  hosts:
  - api.external-service.com
  http:
  - timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
    route:
    - destination:
        host: api.external-service.com
```

## Progressive Delivery with Flagger

### Flagger Canary Resource

Flagger automates canary deployments with automatic rollback based on SLOs.

**Example: Canary with SLO-based Promotion**
```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: product-service
  namespace: production
spec:
  # Target Deployment
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: product-service
  
  # Service configuration
  service:
    port: 8080
    targetPort: 8080
    gateways:
    - istio-system/public-gateway
    hosts:
    - product-service.example.com
    trafficPolicy:
      tls:
        mode: ISTIO_MUTUAL
  
  # Progressive traffic shifting
  analysis:
    interval: 1m
    threshold: 5  # Number of failed checks before rollback
    maxWeight: 50  # Maximum traffic to canary
    stepWeight: 10  # Traffic increment per interval
    
    # SLO Metrics from Prometheus
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99  # At least 99% success rate
      interval: 1m
      query: |
        sum(
          rate(
            istio_requests_total{
              reporter="destination",
              destination_workload_namespace="production",
              destination_workload="product-service-canary"
            }[1m]
          )
        )
        /
        sum(
          rate(
            istio_requests_total{
              reporter="destination",
              destination_workload_namespace="production",
              destination_workload="product-service"
            }[1m]
          )
        ) * 100
    
    - name: request-duration-p95
      thresholdRange:
        max: 500  # P95 latency must be < 500ms
      interval: 1m
      query: |
        histogram_quantile(0.95,
          sum(
            rate(
              istio_request_duration_milliseconds_bucket{
                reporter="destination",
                destination_workload_namespace="production",
                destination_workload="product-service-canary"
              }[1m]
            )
          ) by (le)
        )
    
    - name: error-rate
      thresholdRange:
        max: 1  # Error rate must be < 1%
      interval: 1m
      query: |
        100 - sum(
          rate(
            istio_requests_total{
              reporter="destination",
              destination_workload_namespace="production",
              destination_workload="product-service-canary",
              response_code!~"5.."
            }[1m]
          )
        )
        /
        sum(
          rate(
            istio_requests_total{
              reporter="destination",
              destination_workload_namespace="production",
              destination_workload="product-service-canary"
            }[1m]
          )
        ) * 100
    
    # Webhook tests (optional)
    webhooks:
    - name: load-test
      type: pre-rollout
      url: http://flagger-loadtester.flagger-system/
      timeout: 15s
      metadata:
        type: cmd
        cmd: "hey -z 1m -q 10 -c 2 http://product-service-canary.production:8080/health"
    
    - name: integration-test
      type: rollout
      url: http://flagger-loadtester.flagger-system/
      timeout: 30s
      metadata:
        type: bash
        cmd: |
          curl -sd 'test' http://product-service-canary.production:8080/api/products | \
          jq -e '.products | length > 0'
  
  # Automatic rollback on failure
  skipAnalysis: false
  
  # Canary configuration
  canaryAnalysis:
    # Progressive traffic increase
    match:
    - headers:
        x-canary:
          exact: "true"
    
    # A/B Testing (optional)
    # match:
    # - headers:
    #     user-type:
    #       exact: "premium"
```

## Deployment Strategies

### 1. Canary Deployment

**Timeline:**
```
0min:  0% canary traffic (baseline metrics collected)
1min:  10% canary traffic (SLO check)
2min:  20% canary traffic (SLO check)
3min:  30% canary traffic (SLO check)
4min:  40% canary traffic (SLO check)
5min:  50% canary traffic (SLO check)
6min:  100% canary traffic (promotion complete)
```

**Rollback:** Automatic if any SLO check fails (5 consecutive failures)

### 2. Blue-Green Deployment

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: product-service-bluegreen
spec:
  # ... same as canary ...
  analysis:
    iterations: 10
    threshold: 2
    stepWeight: 100  # Instant switch
    stepWeightPromotion: 100
```

### 3. A/B Testing

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: product-service-ab
spec:
  # ... same as canary ...
  analysis:
    match:
    - headers:
        x-user-type:
          exact: "beta"  # Route beta users to canary
```

## Traffic Policies

### Timeouts & Retries

**Service-Level SLA Matrix:**

| Service | Timeout | Retries | Per-Try Timeout |
|---------|---------|---------|----------------|
| Frontend | 30s | 0 | - |
| API Gateway | 15s | 2 | 7s |
| Product Service | 5s | 3 | 1.5s |
| User Service | 3s | 3 | 1s |
| Payment Service | 10s | 2 | 4s |
| Order Service | 8s | 3 | 2.5s |

### Circuit Breaking

**Thresholds:**
- **Consecutive 5xx Errors:** 5 errors
- **Interval:** 30 seconds (check window)
- **Base Ejection Time:** 30 seconds (minimum)
- **Max Ejection Percent:** 50% (half of instances)
- **Min Health Percent:** 50% (minimum healthy)

### Connection Pooling

**TCP:**
- Max Connections: 1000 per instance
- Connect Timeout: 3s
- TCP Keepalive: 7200s (2 hours)

**HTTP:**
- HTTP/1.1 Max Pending Requests: 1024
- HTTP/2 Max Requests: 1024
- Max Requests Per Connection: 100
- Idle Timeout: 3600s (1 hour)

## Load Balancing Strategies

### 1. LEAST_REQUEST
Default for most services. Routes to instance with fewest active requests.

**Best for:** General purpose, varied request times

### 2. ROUND_ROBIN
Simple rotation through healthy instances.

**Best for:** Uniform request processing times

### 3. RANDOM
Random selection of healthy instances.

**Best for:** Stateless services, simple load distribution

### 4. CONSISTENT_HASH
Hash-based routing for session affinity.

**Best for:** Caching, stateful services

```yaml
trafficPolicy:
  loadBalancer:
    consistentHash:
      httpHeaderName: "x-user-id"  # Hash on user ID
```

## Locality-Aware Routing

Route traffic to instances in the same zone/region for reduced latency.

```yaml
trafficPolicy:
  loadBalancer:
    localityLbSetting:
      enabled: true
      distribute:
      - from: "us-east-2/us-east-2a/*"
        to:
          "us-east-2/us-east-2a/*": 70
          "us-east-2/us-east-2b/*": 20
          "us-east-2/us-east-2c/*": 10
  outlierDetection:
    consecutiveGatewayErrors: 5
    interval: 30s
    baseEjectionTime: 30s
```

## Fault Injection (for Testing)

### Delay Injection
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-service-chaos
spec:
  hosts:
  - product-service
  http:
  - fault:
      delay:
        percentage:
          value: 10  # 10% of requests
        fixedDelay: 5s  # 5 second delay
    route:
    - destination:
        host: product-service
```

### Abort Injection
```yaml
  - fault:
      abort:
        percentage:
          value: 5  # 5% of requests
        httpStatus: 503  # Service Unavailable
```

## mTLS Configuration

### Strict mTLS (Production)
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

### Permissive mTLS (Migration)
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: migration
spec:
  mtls:
    mode: PERMISSIVE  # Allow both mTLS and plaintext
```

## Monitoring Traffic

### Key Metrics

1. **Request Rate (RPS):**
   ```promql
   sum(rate(istio_requests_total[5m])) by (destination_service)
   ```

2. **Error Rate (%):**
   ```promql
   sum(rate(istio_requests_total{response_code=~"5.."}[5m])) 
   / 
   sum(rate(istio_requests_total[5m])) * 100
   ```

3. **Latency (P50/P95/P99):**
   ```promql
   histogram_quantile(0.95, 
     sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service)
   )
   ```

4. **Traffic Distribution (Canary):**
   ```promql
   sum(rate(istio_requests_total[5m])) by (destination_version)
   ```

## Best Practices

1. **Start Conservative:** Begin with small traffic percentages (5-10%)
2. **Monitor Closely:** Watch SLOs during rollout
3. **Test Thoroughly:** Use pre-rollout webhooks for smoke tests
4. **Plan Rollback:** Always have a rollback plan
5. **Document SLOs:** Clear SLO targets per service
6. **Use Stages:** Dev → Staging → Production progression
7. **Automate:** Let Flagger handle the heavy lifting

## Troubleshooting

See [Runbooks](./runbooks/) for detailed troubleshooting guides:
- [Rollback Procedures](./runbooks/rollback.md)
- [Traffic Not Routing](./runbooks/traffic-issues.md)
- [Performance Degradation](./runbooks/performance-issues.md)
