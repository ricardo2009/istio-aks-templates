# Scaling Strategy - From Zero to 600k RPS

## Overview

This document describes the comprehensive scaling strategy to achieve 600,000 requests per second with optimal cost-efficiency.

## Scaling Dimensions

### 1. Horizontal Pod Autoscaling (HPA)
### 2. Cluster Autoscaling (Node Pools)
### 3. KEDA Event-Driven Autoscaling
### 4. Istio Traffic Management
### 5. Database Scaling (Cosmos DB RU/s)

## Target Performance

**Production Environment:**
- **Total RPS:** 600,000 requests/second
- **P50 Latency:** < 50ms
- **P95 Latency:** < 100ms
- **P99 Latency:** < 200ms
- **Error Rate:** < 0.01%
- **Availability:** 99.99%

## Capacity Planning

### Per-Service RPS Targets

| Service | Target RPS | Instances | RPS/Instance |
|---------|-----------|-----------|--------------|
| Frontend | 100,000 | 20 | 5,000 |
| API Gateway | 200,000 | 20 | 10,000 |
| Product Service | 150,000 | 30 | 5,000 |
| User Service | 80,000 | 16 | 5,000 |
| Order Service | 50,000 | 25 | 2,000 |
| Payment Service | 20,000 | 15 | 1,333 |

**Total Capacity:** 600,000 RPS with 20% headroom

### Node Sizing

**Production Cluster:**
- **VM Size:** Standard_D8s_v3 (8 vCPUs, 32 GB RAM)
- **Nodes per Pool:** 6-30 (autoscaling)
- **Pods per Node:** ~30 (with system overhead)
- **Total Capacity:** 30 nodes × 30 pods = 900 pods max

## Horizontal Pod Autoscaling

### 1. Default HPA Configuration

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: product-service-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: product-service
  minReplicas: 3
  maxReplicas: 30
  metrics:
  # CPU-based scaling
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  # Memory-based scaling
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  # Custom metric - requests per second
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "5000"  # Scale when > 5000 RPS per pod
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 minutes before scaling down
      policies:
      - type: Percent
        value: 50  # Scale down max 50% at a time
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0  # Scale up immediately
      policies:
      - type: Percent
        value: 100  # Double instances if needed
        periodSeconds: 30
      - type: Pods
        value: 5  # Or add 5 pods
        periodSeconds: 30
      selectPolicy: Max
```

### 2. Service-Specific HPA Strategies

**Frontend (User-Facing):**
- Quick scale-up (0s stabilization)
- Slow scale-down (5min stabilization)
- Metrics: RPS, CPU

**API Gateway (High Throughput):**
- Very quick scale-up (0s stabilization)
- Moderate scale-down (3min stabilization)
- Metrics: RPS, latency, CPU

**Payment Service (Critical):**
- Conservative scaling
- Longer stabilization (10min)
- Higher minimum replicas (3)
- Metrics: Queue depth, CPU

## KEDA Event-Driven Autoscaling

### When to Use KEDA vs HPA

**Use KEDA for:**
- Event-driven workloads (queues, topics)
- Scale to zero scenarios
- External metrics (Cosmos DB, Azure Monitor)
- Business hours scaling (cron)

**Use HPA for:**
- Request-driven workloads
- Steady-state traffic
- CPU/Memory scaling

**Use Both:**
- KEDA for proactive scaling (queue depth)
- HPA for reactive scaling (CPU spikes)

### KEDA Scaling Patterns

**1. Queue-Based Scaling:**
```yaml
triggers:
- type: azure-queue
  metadata:
    queueName: orders-processing
    queueLength: "10"  # 10 messages per instance
```

**2. Scheduled Scaling:**
```yaml
triggers:
- type: cron
  metadata:
    timezone: America/New_York
    start: 0 8 * * 1-5  # Scale up at 8 AM weekdays
    end: 0 18 * * 1-5   # Scale down at 6 PM
    desiredReplicas: "10"
```

**3. Composite Scaling:**
```yaml
triggers:
- type: prometheus
  metadata:
    query: "sum(rate(requests_total[1m]))"
    threshold: "1000"
- type: azure-queue
  metadata:
    queueLength: "50"
# Scales based on EITHER metric exceeding threshold
```

## Cluster Autoscaling

### Node Pool Configuration

**Production:**
```hcl
# System Node Pool (non-autoscaling)
node_pool_system = {
  name       = "system"
  vm_size    = "Standard_D4s_v3"
  node_count = 3
  min_count  = 3
  max_count  = 3
  zones      = [1, 2, 3]
  labels = {
    workload = "system"
  }
  taints = [
    "CriticalAddonsOnly=true:NoSchedule"
  ]
}

# User Node Pool (autoscaling)
node_pool_user = {
  name       = "user"
  vm_size    = "Standard_D8s_v3"
  min_count  = 6
  max_count  = 30
  zones      = [1, 2, 3]
  labels = {
    workload = "user"
  }
}

# Ingress Node Pool (autoscaling)
node_pool_ingress = {
  name       = "ingress"
  vm_size    = "Standard_D4s_v3"
  min_count  = 3
  max_count  = 10
  zones      = [1, 2, 3]
  labels = {
    workload = "ingress"
  }
  taints = [
    "workload=ingress:NoSchedule"
  ]
}
```

### Cluster Autoscaler Settings

```yaml
cluster-autoscaler:
  scaleDownDelayAfterAdd: 10m
  scaleDownUnneededTime: 10m
  scaleDownUtilizationThreshold: 0.5  # Scale down if node < 50% utilized
  maxNodeProvisionTime: 15m
  skipNodesWithSystemPods: true
  skipNodesWithLocalStorage: true
```

## Istio Traffic Management for Performance

### 1. Connection Pooling

```yaml
spec:
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1000  # Max concurrent connections
        connectTimeout: 3s
      http:
        http1MaxPendingRequests: 1024
        http2MaxRequests: 1024
        maxRequestsPerConnection: 100  # Connection reuse
        idleTimeout: 3600s
        h2UpgradePolicy: UPGRADE  # Use HTTP/2 when possible
```

**Benefits:**
- Reduced connection overhead
- Better resource utilization
- Lower latency

### 2. Load Balancing Algorithms

**LEAST_REQUEST (Default):**
```yaml
loadBalancer:
  simple: LEAST_REQUEST
```
- Best for varying request times
- Prevents hot spotting

**CONSISTENT_HASH (Caching):**
```yaml
loadBalancer:
  consistentHash:
    httpHeaderName: "x-user-id"
```
- Session affinity
- Better cache hit rates

### 3. Locality-Aware Routing

```yaml
trafficPolicy:
  loadBalancer:
    localityLbSetting:
      enabled: true
      distribute:
      - from: "us-east-2/us-east-2a/*"
        to:
          "us-east-2/us-east-2a/*": 80  # Prefer same zone
          "us-east-2/us-east-2b/*": 15
          "us-east-2/us-east-2c/*": 5
```

**Benefits:**
- Reduced cross-AZ latency (~1-2ms)
- Lower data transfer costs
- Better availability during AZ failures

### 4. Circuit Breaking

```yaml
outlierDetection:
  consecutive5xxErrors: 5
  interval: 30s
  baseEjectionTime: 30s
  maxEjectionPercent: 50
```

**Prevents:**
- Cascade failures
- Wasted resources on unhealthy instances

## Cosmos DB Autoscaling

### 1. Autoscale RU/s Configuration

**Production Database:**
```hcl
cosmosdb_max_throughput = 100000  # Max 100k RU/s

cosmosdb_databases = {
  ecommerce = {
    containers = {
      products = {
        partition_key_path = "/categoryId"
        throughput        = 20000  # Dedicated throughput
      }
      orders = {
        partition_key_path = "/customerId"
        # Inherits database-level autoscale
      }
    }
  }
}
```

### 2. Partition Strategy

**Hot Partitions to Avoid:**
```javascript
// BAD: Single partition key
{ "partitionKey": "global" }

// GOOD: Distributed partition key
{ "partitionKey": "category-electronics" }
{ "partitionKey": "category-clothing" }
```

**Optimal Partition Size:**
- Max 20 GB per partition
- Even distribution of requests
- Low cardinality keys (10-100 unique values)

### 3. RU Consumption Optimization

**Indexing Policy:**
```json
{
  "indexingMode": "consistent",
  "includedPaths": [
    { "path": "/categoryId/*" },
    { "path": "/price/*" },
    { "path": "/createdAt/*" }
  ],
  "excludedPaths": [
    { "path": "/description/*" },
    { "path": "/images/*" }
  ]
}
```

**Query Optimization:**
```sql
-- BAD: Cross-partition query
SELECT * FROM c WHERE c.name = "Product A"

-- GOOD: Single-partition query
SELECT * FROM c 
WHERE c.categoryId = "electronics" 
AND c.name = "Product A"
```

## Performance Testing

### Load Testing Strategy

**1. Baseline Test (Current Capacity):**
```bash
k6 run --vus 100 --duration 10m baseline-test.js
```

**2. Stress Test (Find Breaking Point):**
```bash
k6 run --vus 1000 --duration 30m stress-test.js
```

**3. Spike Test (Sudden Traffic Surge):**
```bash
k6 run --stage 0s:1000 --stage 5m:1000 --stage 0s:0 spike-test.js
```

**4. Soak Test (Long-Running Stability):**
```bash
k6 run --vus 500 --duration 4h soak-test.js
```

### Target Metrics During Testing

| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| P95 Latency | < 100ms | > 200ms |
| P99 Latency | < 200ms | > 500ms |
| Error Rate | < 0.1% | > 1% |
| RPS | 600,000 | N/A |
| CPU Utilization | < 70% | > 85% |
| Memory Utilization | < 80% | > 90% |

## Scaling Checklist

### Pre-Production
- [ ] Load test at 50% target (300k RPS)
- [ ] Load test at 100% target (600k RPS)
- [ ] Load test at 150% target (900k RPS)
- [ ] Verify autoscaling works (pods and nodes)
- [ ] Verify circuit breakers work (kill pods)
- [ ] Verify multi-region failover
- [ ] Optimize queries (< 10 RU/s per query)
- [ ] Review and tune HPA/KEDA settings

### During Scaling Event
- [ ] Monitor Golden Signals dashboard
- [ ] Watch for pod scheduling failures
- [ ] Watch for Cosmos DB throttling (429s)
- [ ] Monitor cross-AZ traffic costs
- [ ] Check for hot partitions
- [ ] Verify mTLS overhead is acceptable

### Post-Scaling
- [ ] Review cost vs performance
- [ ] Identify optimization opportunities
- [ ] Update capacity plans
- [ ] Document lessons learned

## Cost Optimization

### 1. Right-Sizing

**Identify Oversized Pods:**
```promql
# CPU request vs actual usage
avg_over_time(container_cpu_usage_seconds_total[24h])
/
kube_pod_container_resource_requests{resource="cpu"}
< 0.5  # Using < 50% of requested CPU
```

**Identify Undersized Pods:**
```promql
# Pods hitting CPU limits
rate(container_cpu_cfs_throttled_seconds_total[5m]) > 0
```

### 2. Spot Instances for Non-Critical Workloads

```hcl
node_pool_batch = {
  name       = "batch"
  vm_size    = "Standard_D8s_v3"
  priority   = "Spot"
  min_count  = 0
  max_count  = 10
  eviction_policy = "Delete"
  spot_max_price = -1  # Pay up to on-demand price
  labels = {
    workload = "batch"
  }
  taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]
}
```

### 3. Reserved Instances

**1-Year Savings:** ~40% discount
**3-Year Savings:** ~60% discount

**Production Recommendation:**
- Reserve 50% of max capacity (15 nodes × D8s_v3)
- Use on-demand for burst capacity

## Troubleshooting Scaling Issues

### Pods Not Scaling

**1. Check HPA Status:**
```bash
kubectl get hpa -n production
kubectl describe hpa product-service-hpa -n production
```

**2. Check Metrics:**
```bash
kubectl top pods -n production
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/production/pods
```

**3. Check KEDA:**
```bash
kubectl get scaledobjects -n production
kubectl describe scaledobject product-service-scaler -n production
```

### Nodes Not Scaling

**1. Check Cluster Autoscaler:**
```bash
kubectl logs -n kube-system -l app=cluster-autoscaler
```

**2. Check Node Pool Limits:**
```bash
az aks nodepool show \
  --resource-group rg-istio-aks-prd \
  --cluster-name aks-primary \
  --name user
```

### High Latency Despite Scaling

**1. Check for Outliers:**
```promql
# Identify slow instances
topk(5, 
  histogram_quantile(0.99,
    rate(istio_request_duration_milliseconds_bucket[5m])
  ) by (pod)
)
```

**2. Check Circuit Breakers:**
```promql
# Ejected instances
sum(envoy_cluster_outlier_detection_ejections_active) by (cluster)
```

**3. Check Connection Pool Saturation:**
```promql
# Connection pool utilization
envoy_cluster_upstream_cx_active 
/ 
envoy_cluster_circuit_breakers_default_cx_limit * 100
```

## Next Steps

- Review [Architecture](./architecture.md)
- Review [Observability](./observability.md)
- Review [Runbooks](./runbooks/)
