# Service Level Objectives (SLOs)

## Overview

This document defines the SLOs for the Orders and Payments services running on AKS with Istio.

## SLO Definitions

### Orders Service

| Metric | Target | Measurement Window | Actions on Breach |
|--------|--------|-------------------|-------------------|
| Availability | 99.9% | 30 days | Page on-call, investigate |
| p95 Latency | < 200ms | 5 minutes | Alert, check logs |
| p99 Latency | < 500ms | 5 minutes | Alert, check logs |
| Error Rate | < 0.1% | 5 minutes | Alert, investigate |
| Request Success Rate | > 99.9% | 1 hour | Page on-call |

### Payments Service

| Metric | Target | Measurement Window | Actions on Breach |
|--------|--------|-------------------|-------------------|
| Availability | 99.95% | 30 days | Page on-call, investigate |
| p95 Latency | < 300ms | 5 minutes | Alert, check logs |
| p99 Latency | < 800ms | 5 minutes | Alert, check logs |
| Error Rate | < 0.05% | 5 minutes | Alert, investigate |
| Request Success Rate | > 99.95% | 1 hour | Page on-call |

### Cosmos DB

| Metric | Target | Measurement Window | Actions on Breach |
|--------|--------|-------------------|-------------------|
| 429 Rate | < 1% | 5 minutes | Scale RUs, optimize queries |
| Replication Lag | < 5 seconds | 1 minute | Check network, investigate |
| Availability | 99.99% | 30 days | Engage Azure support |

### APIM

| Metric | Target | Measurement Window | Actions on Breach |
|--------|--------|-------------------|-------------------|
| Gateway Availability | 99.95% | 30 days | Engage Azure support |
| p95 Latency | < 100ms | 5 minutes | Check policies, investigate |
| Rate Limit Hits | < 5% | 1 hour | Review limits, scale |

## Error Budgets

### Orders Service
- **Monthly Error Budget**: 43.2 minutes (99.9% availability)
- **Burn Rate Alert**: 10x (consuming budget 10x faster than allowed)

### Payments Service  
- **Monthly Error Budget**: 21.6 minutes (99.95% availability)
- **Burn Rate Alert**: 10x

## Prometheus Recording Rules

Recording rules are defined in `observability/prometheus/rules/slo-rules.yaml`:

```yaml
- record: http_request_duration_seconds:p95
  expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))

- record: http_request_duration_seconds:p99
  expr: histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))

- record: http_requests:error_rate
  expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service)
```

## Alert Rules

Alert rules are defined in `observability/prometheus/rules/alert-rules.yaml`:

```yaml
- alert: HighErrorRate
  expr: http_requests:error_rate > 0.001
  for: 5m
  annotations:
    summary: "High error rate detected"

- alert: HighLatency
  expr: http_request_duration_seconds:p95 > 0.2
  for: 5m
  annotations:
    summary: "High latency detected"
```

## Grafana Dashboards

Dashboards are available in `observability/grafana/dashboards/`:

1. **Service Overview**: Request rate, error rate, latency
2. **SLO Dashboard**: Burn rate, error budget consumption
3. **Istio Mesh**: Service topology, mTLS status
4. **Cosmos DB**: RU consumption, throttling, replication lag

## Monitoring and Alerting

- **Prometheus**: Collects metrics from Istio sidecars and applications
- **Grafana**: Visualizes metrics and SLO compliance
- **Azure Monitor**: Alerts routed to PagerDuty/Teams
- **Log Analytics**: Centralized logging for investigation

## SLO Review Process

1. **Weekly**: Review SLO compliance, burn rates
2. **Monthly**: Adjust SLOs based on business needs
3. **Quarterly**: Deep dive into patterns, optimize
4. **Post-Incident**: Review impact on error budget

## Best Practices

- Always measure from user perspective (APIM → service)
- Include inter-cluster latency in SLOs
- Set alerts before SLO breach (early warning)
- Monitor error budget consumption
- Use burn rate alerts for fast detection
- Review and adjust SLOs regularly
