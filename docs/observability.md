# Observability Strategy - 360° Monitoring

## Overview

This document describes the comprehensive observability strategy using Managed Prometheus, Managed Grafana, Application Insights, and Log Analytics.

## Observability Pillars

### 1. Metrics (Prometheus)
### 2. Logs (Log Analytics + Application Insights)
### 3. Traces (Application Insights)
### 4. Service Mesh Telemetry (Istio)

## Managed Prometheus Configuration

### Data Collection

**Sources:**
- Istio sidecar proxies (Envoy metrics)
- NGINX Ingress Controller
- KEDA operators
- Application custom metrics
- Kubernetes cluster metrics
- Azure Monitor integration

**Retention:**
- Development: 30 days
- Staging: 90 days
- Production: 365 days

### Key Metrics

#### 1. Golden Signals (SRE)

**Latency:**
```promql
# P50 Latency
histogram_quantile(0.50,
  sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service)
)

# P95 Latency
histogram_quantile(0.95,
  sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service)
)

# P99 Latency
histogram_quantile(0.99,
  sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service)
)
```

**Traffic (RPS):**
```promql
# Total requests per second
sum(rate(istio_requests_total[5m])) by (destination_service)

# Requests by response code
sum(rate(istio_requests_total[5m])) by (destination_service, response_code)

# Requests by source service
sum(rate(istio_requests_total[5m])) by (source_service, destination_service)
```

**Errors:**
```promql
# Error rate (%)
sum(rate(istio_requests_total{response_code=~"5.."}[5m])) 
/ 
sum(rate(istio_requests_total[5m])) * 100

# Error count by service
sum(rate(istio_requests_total{response_code=~"5.."}[5m])) by (destination_service)

# 4xx vs 5xx errors
sum(rate(istio_requests_total{response_code=~"4.."}[5m])) by (destination_service) # Client errors
sum(rate(istio_requests_total{response_code=~"5.."}[5m])) by (destination_service) # Server errors
```

**Saturation:**
```promql
# CPU utilization
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod, namespace) 
/ 
sum(container_spec_cpu_quota / container_spec_cpu_period) by (pod, namespace) * 100

# Memory utilization
sum(container_memory_working_set_bytes) by (pod, namespace)
/
sum(container_spec_memory_limit_bytes) by (pod, namespace) * 100

# Connection pool utilization
envoy_cluster_upstream_cx_active / envoy_cluster_circuit_breakers_default_cx_limit * 100
```

#### 2. Istio Service Mesh Metrics

**Request Metrics:**
```promql
# Request duration by percentile
histogram_quantile(0.95,
  sum(rate(istio_request_duration_milliseconds_bucket{
    reporter="destination"
  }[5m])) by (le, destination_workload, destination_service_name)
)

# Request size
histogram_quantile(0.95,
  sum(rate(istio_request_bytes_bucket[5m])) by (le, destination_service)
)

# Response size
histogram_quantile(0.95,
  sum(rate(istio_response_bytes_bucket[5m])) by (le, destination_service)
)
```

**TCP Metrics:**
```promql
# TCP connections
sum(istio_tcp_connections_opened_total) by (destination_service)
sum(istio_tcp_connections_closed_total) by (destination_service)

# TCP bytes sent/received
sum(rate(istio_tcp_sent_bytes_total[5m])) by (destination_service)
sum(rate(istio_tcp_received_bytes_total[5m])) by (destination_service)
```

**mTLS Metrics:**
```promql
# mTLS usage
sum(istio_requests_total{security_policy="mutual_tls"}) 
/ 
sum(istio_requests_total) * 100

# Non-mTLS requests (should be 0 in STRICT mode)
sum(istio_requests_total{security_policy!="mutual_tls"})
```

#### 3. NGINX Ingress Metrics

```promql
# Request rate
sum(rate(nginx_ingress_controller_requests[5m])) by (ingress, status)

# Request duration
histogram_quantile(0.95,
  sum(rate(nginx_ingress_controller_request_duration_seconds_bucket[5m])) by (le, ingress)
)

# Upstream response time
histogram_quantile(0.95,
  sum(rate(nginx_ingress_controller_response_duration_seconds_bucket[5m])) by (le, ingress)
)

# SSL certificate expiry
nginx_ingress_controller_ssl_expire_time_seconds - time()
```

#### 4. KEDA Metrics

```promql
# Scaler errors
sum(rate(keda_scaler_errors_total[5m])) by (scaledObject, scaler)

# Scaler metrics value
keda_scaler_metrics_value by (scaledObject, scaler, metric)

# Active scalers
count(keda_scaler_active) by (namespace)
```

#### 5. Application Metrics

```promql
# Custom business metrics
product_service_cache_hit_rate
order_service_checkout_duration_seconds
payment_service_transaction_total
user_service_login_attempts_total

# Database metrics
cosmosdb_consumed_rus
cosmosdb_throttled_requests_total
cosmosdb_request_duration_seconds
```

## Managed Grafana Dashboards

### 1. Platform Overview Dashboard

**Panels:**
- Cluster health (node status, pod count)
- Overall RPS and latency
- Error rate across all services
- Resource utilization (CPU, Memory, Disk)
- Active alerts

### 2. Istio Service Mesh Dashboard

**Sections:**
- **Global Traffic:** Total RPS, success rate, P95 latency
- **Service Graph:** Visual topology with traffic flow
- **Workload Metrics:** Per-service RPS, latency, errors
- **mTLS Status:** Encrypted vs plaintext traffic
- **Circuit Breakers:** Ejected instances, open circuits

**Example Panel Queries:**
```json
{
  "title": "Service Request Rate",
  "targets": [
    {
      "expr": "sum(rate(istio_requests_total{reporter=\"destination\"}[5m])) by (destination_service)",
      "legendFormat": "{{destination_service}}"
    }
  ]
}
```

### 3. NGINX Ingress Dashboard

**Panels:**
- Request rate by ingress
- Success rate (2xx, 3xx, 4xx, 5xx)
- P50/P95/P99 latency
- Upstream health
- SSL certificate expiration
- Rate limiting status

### 4. KEDA Autoscaling Dashboard

**Panels:**
- Current replica count by deployment
- Scaler metric values
- Scaling events timeline
- Queue depth (for queue-based scalers)
- HPA target utilization

### 5. Application-Specific Dashboards

**Product Service:**
- Catalog queries per second
- Cache hit rate
- Search latency
- Inventory updates

**Order Service:**
- Orders per minute
- Checkout success rate
- Payment processing time
- Order status distribution

**User Service:**
- Login attempts
- Registration rate
- Session duration
- Authentication failures

### 6. Cosmos DB Dashboard

**Panels:**
- RU consumption
- Throttled requests (429s)
- Request latency by operation
- Storage usage
- Replication lag (multi-region)
- Failover events

### 7. SLO Dashboard

**SLIs (Service Level Indicators):**
- Availability (%)
- Error rate (%)
- Latency (P95, P99)

**SLO Targets:**
- Availability: 99.9% (dev), 99.95% (staging), 99.99% (production)
- Error rate: < 1%
- P95 latency: < 100ms (most services)
- P99 latency: < 200ms (most services)

**Example SLO Panel:**
```promql
# Availability SLO (99.99%)
(
  sum(rate(istio_requests_total{response_code!~"5.."}[30d]))
  /
  sum(rate(istio_requests_total[30d]))
) * 100
```

**Error Budget:**
```promql
# Remaining error budget (basis points)
(
  1 - (
    sum(rate(istio_requests_total{response_code=~"5.."}[30d]))
    /
    sum(rate(istio_requests_total[30d]))
  )
) * 10000 - (10000 - 99.99 * 100)
```

## Application Insights Integration

### 1. Distributed Tracing

**Automatic Instrumentation:**
- OpenTelemetry in application code
- Istio trace headers propagation
- End-to-end trace correlation

**Trace Data:**
- Request path across services
- Latency breakdown per service
- Dependencies and external calls
- Errors and exceptions

**Example Trace Query (KQL):**
```kusto
requests
| where timestamp > ago(1h)
| where resultCode >= 500
| join kind=inner (
    dependencies
) on operation_Id
| project timestamp, name, resultCode, duration, dependency.name, dependency.duration
| order by timestamp desc
```

### 2. Application Performance Monitoring

**Metrics:**
- Request count
- Response time
- Failure rate
- Dependency calls
- Exception rate

**Custom Events:**
```javascript
// Track custom business events
appInsights.trackEvent({
  name: "CheckoutCompleted",
  properties: {
    orderId: order.id,
    totalAmount: order.total,
    paymentMethod: order.payment.method
  }
});
```

### 3. Availability Tests

**Synthetic Monitoring:**
- HTTP ping tests (every 5 minutes)
- Multi-step web tests
- Alerts on failures

**Locations:**
- East US 2
- West US 2
- Central US
- North Europe
- Southeast Asia

## Log Analytics

### 1. Container Logs

**Query Examples:**

**Error Logs:**
```kusto
ContainerLog
| where LogEntry contains "error" or LogEntry contains "exception"
| where TimeGenerated > ago(1h)
| project TimeGenerated, Computer, ContainerID, LogEntry
| order by TimeGenerated desc
```

**Application Logs by Service:**
```kusto
ContainerLog
| where ContainerName contains "product-service"
| where TimeGenerated > ago(15m)
| project TimeGenerated, LogEntry
| order by TimeGenerated desc
```

### 2. Kubernetes Events

```kusto
KubeEvents
| where TimeGenerated > ago(1h)
| where Reason in ("Failed", "BackOff", "Unhealthy")
| project TimeGenerated, Namespace, Name, Reason, Message
| order by TimeGenerated desc
```

### 3. Istio Access Logs

```kusto
ContainerLog
| where ContainerName contains "istio-proxy"
| where LogEntry contains "response_code"
| extend ParsedLog = parse_json(LogEntry)
| project 
    TimeGenerated,
    method = ParsedLog.method,
    path = ParsedLog.path,
    response_code = ParsedLog.response_code,
    duration = ParsedLog.duration,
    source_service = ParsedLog.source_workload,
    destination_service = ParsedLog.destination_workload
| where response_code >= 500
| order by TimeGenerated desc
```

### 4. Security Audit Logs

```kusto
AzureActivity
| where TimeGenerated > ago(24h)
| where OperationNameValue contains "Microsoft.ContainerService"
| project TimeGenerated, Caller, OperationNameValue, ActivityStatusValue, Properties
| order by TimeGenerated desc
```

## Alerting Strategy

### 1. Critical Alerts (Page On-Call)

**High Error Rate:**
```promql
expr: |
  sum(rate(istio_requests_total{response_code=~"5.."}[5m])) 
  / 
  sum(rate(istio_requests_total[5m])) * 100 > 5
for: 5m
labels:
  severity: critical
annotations:
  summary: "High error rate detected"
  description: "Error rate is {{ $value }}% (threshold: 5%)"
```

**Service Down:**
```promql
expr: |
  up{job="kubernetes-pods"} == 0
for: 2m
labels:
  severity: critical
```

**High Latency:**
```promql
expr: |
  histogram_quantile(0.95,
    sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (le, destination_service)
  ) > 1000
for: 10m
labels:
  severity: critical
annotations:
  summary: "High latency on {{ $labels.destination_service }}"
  description: "P95 latency is {{ $value }}ms (threshold: 1000ms)"
```

### 2. Warning Alerts (Slack/Email)

**Moderate Error Rate:**
```promql
expr: |
  sum(rate(istio_requests_total{response_code=~"5.."}[10m])) 
  / 
  sum(rate(istio_requests_total[10m])) * 100 > 1
for: 10m
labels:
  severity: warning
```

**High CPU Usage:**
```promql
expr: |
  sum(rate(container_cpu_usage_seconds_total[5m])) by (pod, namespace)
  /
  sum(container_spec_cpu_quota / container_spec_cpu_period) by (pod, namespace) * 100 > 80
for: 15m
labels:
  severity: warning
```

**Cosmos DB Throttling:**
```promql
expr: |
  sum(rate(cosmosdb_requests_total{status_code="429"}[5m])) > 10
for: 5m
labels:
  severity: warning
annotations:
  summary: "Cosmos DB throttling detected"
```

### 3. Info Alerts (Dashboard Only)

**Deployment in Progress:**
```promql
expr: |
  changes(kube_deployment_status_replicas_updated[5m]) > 0
labels:
  severity: info
```

**Certificate Expiring Soon:**
```promql
expr: |
  nginx_ingress_controller_ssl_expire_time_seconds - time() < 86400 * 30
labels:
  severity: info
annotations:
  summary: "SSL certificate expires in less than 30 days"
```

## Correlation and Root Cause Analysis

### 1. Service Map

Application Insights automatically builds a service dependency map showing:
- All service interactions
- Performance of each dependency
- Failure rates

### 2. Log Correlation

All logs include correlation IDs:
- `trace_id`: Distributed trace identifier
- `span_id`: Span within trace
- `operation_id`: Application Insights operation

**Query Across Logs and Traces:**
```kusto
union requests, dependencies, traces, exceptions
| where timestamp > ago(1h)
| where operation_Id == "<trace_id>"
| order by timestamp asc
```

### 3. Metric Correlation

Link metrics to logs and traces:
- High latency spike → Find traces with high duration
- Error rate increase → Find exception logs
- CPU spike → Find resource-intensive requests

## Performance Optimization

### 1. Query Optimization

- Use recording rules for frequently-used queries
- Pre-aggregate metrics where possible
- Limit cardinality (avoid high-cardinality labels)

### 2. Data Retention Strategy

**Prometheus:**
- Raw data: 15 days
- 5m aggregates: 90 days
- 1h aggregates: 365 days

**Log Analytics:**
- Hot tier (searchable): 30 days (dev), 90 days (prd)
- Archive tier: 365 days

### 3. Cost Management

- Alert on unexpected cost increases
- Review retention policies quarterly
- Disable unused metrics
- Optimize query efficiency

## Visualization Best Practices

1. **Use Consistent Time Ranges:** 15m, 1h, 6h, 24h, 7d
2. **Show Context:** Include baselines and thresholds
3. **Highlight Anomalies:** Use alerts and annotations
4. **Mobile-Friendly:** Design for on-call engineers
5. **Self-Service:** Enable teams to create their own dashboards

## Runbooks Integration

Link alerts to runbooks:
```yaml
annotations:
  summary: "High error rate on product-service"
  description: "Error rate is {{ $value }}%"
  runbook_url: "https://docs.example.com/runbooks/high-error-rate.md"
```

## Next Steps

- Review [Scaling Strategy](./scaling.md)
- Review [Runbooks](./runbooks/)
- Configure [Alerting Rules](./observability/alerting-rules.yaml)
