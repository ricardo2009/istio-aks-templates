# Rollback Procedures - Emergency Response

## Quick Reference

**When to Rollback:**
- Error rate > 5%
- P95 latency > 2x normal
- Availability < 99%
- Critical business functionality broken
- Security incident

**Rollback Methods:**
1. Flagger Automatic Rollback (preferred)
2. Manual Flagger Rollback
3. Manual Deployment Rollback
4. Traffic Rerouting (Istio)
5. Complete Environment Failover

## 1. Flagger Automatic Rollback

### How It Works

Flagger monitors SLOs during canary deployment:
- **Success Rate** must be > 99%
- **P95 Latency** must be < threshold
- **Error Rate** must be < 1%

If any metric fails for 5 consecutive checks (threshold), Flagger automatically rolls back.

### Verify Automatic Rollback

```bash
# Check canary status
kubectl get canary product-service -n production

# Expected output during rollback:
# NAME              STATUS        WEIGHT   LASTTRANSITIONTIME
# product-service   Failed        0        2024-01-15T10:30:00Z

# View canary events
kubectl describe canary product-service -n production

# Check rollback reason
kubectl get canary product-service -n production -o jsonpath='{.status.conditions[?(@.type=="Promoted")].message}'
```

### What Flagger Does

1. **Traffic Shift:** Routes 100% traffic back to stable version
2. **Scale Down:** Reduces canary deployment to 0 replicas
3. **Alert:** Sends webhook notification (if configured)
4. **Reset:** Marks deployment as failed

**Timeline:** 1-2 minutes total

## 2. Manual Flagger Rollback

### When to Use
- Automatic rollback not triggered but issues detected
- Proactive rollback before SLO breach

### Procedure

```bash
# Method 1: Skip canary analysis (immediate rollback)
kubectl patch canary product-service -n production \
  --type=json \
  -p='[{"op": "replace", "path": "/spec/skipAnalysis", "value": true}]'

# Method 2: Revert to previous deployment
kubectl rollout undo deployment/product-service -n production

# Method 3: Delete canary resource (stops progressive deployment)
kubectl delete canary product-service -n production

# Verify stable version is serving 100% traffic
kubectl get virtualservice product-service -n production -o yaml | grep weight
```

**Timeline:** 30 seconds - 2 minutes

## 3. Manual Deployment Rollback

### When to Use
- Flagger not in use
- Direct deployment issue
- Need to rollback multiple versions

### Check Deployment History

```bash
# List deployment revisions
kubectl rollout history deployment/product-service -n production

# Expected output:
# REVISION  CHANGE-CAUSE
# 1         Initial deployment
# 2         Update to v1.2.0
# 3         Update to v1.3.0 (current)

# Check specific revision
kubectl rollout history deployment/product-service -n production --revision=2
```

### Rollback to Previous Version

```bash
# Rollback to previous revision (v1.2.0)
kubectl rollout undo deployment/product-service -n production

# Rollback to specific revision
kubectl rollout undo deployment/product-service -n production --to-revision=2

# Watch rollback progress
kubectl rollout status deployment/product-service -n production
```

### Rollback Multiple Services

```bash
# Rollback all services in namespace
for deployment in $(kubectl get deployments -n production -o name); do
  echo "Rolling back $deployment"
  kubectl rollout undo $deployment -n production
done
```

**Timeline:** 1-3 minutes per deployment

## 4. Traffic Rerouting (Istio)

### When to Use
- Keep new version deployed but remove traffic
- A/B test gone wrong
- Gradual rollback (reduce traffic incrementally)

### Route All Traffic to Stable Version

```bash
# Edit VirtualService
kubectl edit virtualservice product-service -n production
```

**Change this:**
```yaml
spec:
  http:
  - route:
    - destination:
        host: product-service
        subset: stable
      weight: 50
    - destination:
        host: product-service
        subset: canary
      weight: 50
```

**To this:**
```yaml
spec:
  http:
  - route:
    - destination:
        host: product-service
        subset: stable
      weight: 100
    - destination:
        host: product-service
        subset: canary
      weight: 0
```

### Or Use kubectl patch

```bash
kubectl patch virtualservice product-service -n production \
  --type=json \
  -p='[
    {"op": "replace", "path": "/spec/http/0/route/0/weight", "value": 100},
    {"op": "replace", "path": "/spec/http/0/route/1/weight", "value": 0}
  ]'
```

**Timeline:** Immediate (< 10 seconds)

## 5. Complete Environment Failover

### When to Use
- Complete cluster failure
- Major infrastructure issue
- Multi-service cascading failure

### Regional Failover (AKS)

```bash
# 1. Update DNS/Traffic Manager to route to secondary region
az network traffic-manager endpoint update \
  --resource-group rg-istio-aks-prd \
  --profile-name tm-istio-aks \
  --name primary-endpoint \
  --endpoint-status Disabled

az network traffic-manager endpoint update \
  --resource-group rg-istio-aks-prd \
  --profile-name tm-istio-aks \
  --name secondary-endpoint \
  --endpoint-status Enabled

# 2. Verify traffic routing
nslookup istio-aks.trafficmanager.net

# 3. Trigger Cosmos DB manual failover (if needed)
az cosmosdb failover-priority-change \
  --resource-group rg-istio-aks-prd \
  --name cosmosdb-istio-aks-prd \
  --failover-policies "West US 2=0" "East US 2=1"
```

**Timeline:** 2-5 minutes for DNS propagation

## Post-Rollback Actions

### 1. Verify System Health

```bash
# Check all pods are running
kubectl get pods -n production

# Check error rates
kubectl logs -n production -l app=product-service --tail=100 | grep -i error

# Check metrics
curl http://prometheus.monitoring:9090/api/v1/query?query='rate(istio_requests_total{response_code=~"5.."}[5m])'
```

### 2. Monitor for 30 Minutes

Watch these dashboards:
- **Golden Signals:** Error rate, latency, throughput
- **Service Health:** Pod restarts, OOMKills
- **Business Metrics:** Orders/min, revenue, user sessions

### 3. Root Cause Analysis

```bash
# Get canary failure reason
kubectl get canary product-service -n production -o yaml

# Check application logs
kubectl logs -n production deployment/product-service-primary --previous

# Check Istio logs
kubectl logs -n istio-system -l app=istiod --tail=200

# Export metrics for analysis
kubectl get --raw /metrics | grep product_service > /tmp/metrics.txt
```

### 4. Document Incident

Create incident report:
- **Trigger:** What caused the rollback?
- **Timeline:** When did issues start? When was rollback initiated? When was service restored?
- **Impact:** How many users affected? Revenue impact?
- **Root Cause:** What was the underlying issue?
- **Action Items:** What needs to change to prevent recurrence?

### 5. Communication

**Internal:**
- Update status page
- Notify on-call team
- Post in incident channel

**External (if needed):**
- Customer notification
- Status page update
- Social media update

## Prevention Strategies

### 1. Strengthen Pre-Deployment Checks

**Add to Flagger webhooks:**
```yaml
webhooks:
- name: comprehensive-test
  type: pre-rollout
  url: http://test-runner/
  timeout: 300s
  metadata:
    test-suite: "integration,e2e,performance"
```

### 2. Improve SLO Thresholds

**Be more conservative:**
```yaml
metrics:
- name: request-success-rate
  thresholdRange:
    min: 99.5  # Was 99, now stricter
```

### 3. Gradual Rollout

**Smaller traffic increments:**
```yaml
analysis:
  stepWeight: 5  # Was 10, now more gradual
  maxWeight: 25  # Don't exceed 25% before full validation
```

### 4. Automated Testing

**Load test before promotion:**
```yaml
webhooks:
- name: load-test
  type: rollout
  url: http://loadtester/
  metadata:
    cmd: "k6 run --vus 1000 --duration 5m test.js"
```

## Rollback Decision Matrix

| Condition | Action | Timeline |
|-----------|--------|----------|
| Error rate 1-5% | Monitor closely, prepare rollback | 5 minutes |
| Error rate > 5% | **ROLLBACK IMMEDIATELY** | < 2 minutes |
| P95 latency 2-3x normal | Investigate, prepare rollback | 5 minutes |
| P95 latency > 3x normal | **ROLLBACK IMMEDIATELY** | < 2 minutes |
| Availability 99-99.9% | Monitor, prepare rollback | 10 minutes |
| Availability < 99% | **ROLLBACK IMMEDIATELY** | < 2 minutes |
| Memory leak detected | Monitor rate, rollback if growing | 15 minutes |
| Security vulnerability | **ROLLBACK + INCIDENT** | < 1 minute |
| Customer reports issues | Investigate + rollback if confirmed | 5 minutes |

## Quick Commands Reference

```bash
# === FLAGGER ===
# View canary status
kubectl get canary -n production

# Manual rollback
kubectl patch canary <name> -n production --type=json \
  -p='[{"op": "replace", "path": "/spec/skipAnalysis", "value": true}]'

# === DEPLOYMENT ===
# Rollback deployment
kubectl rollout undo deployment/<name> -n production

# Check rollback status
kubectl rollout status deployment/<name> -n production

# === ISTIO ===
# Route 100% to stable
kubectl patch virtualservice <name> -n production --type=json \
  -p='[{"op": "replace", "path": "/spec/http/0/route/0/weight", "value": 100}]'

# === MONITORING ===
# Check error rate
kubectl top pods -n production
kubectl logs -n production -l app=<name> --tail=100

# === FAILOVER ===
# Disable primary endpoint
az network traffic-manager endpoint update \
  --resource-group <rg> --profile-name <profile> \
  --name primary --endpoint-status Disabled
```

## Escalation Path

1. **L1 Engineer:** Detect issue, initiate automatic rollback
2. **L2 Engineer:** Manual rollback if automatic fails
3. **On-Call SRE:** Environment failover, infrastructure changes
4. **Engineering Manager:** Major incident coordination
5. **CTO/VP Engineering:** Customer communication, executive updates

## Contact Information

- **Slack Channel:** #incidents
- **PagerDuty:** istio-aks-production
- **Runbook Location:** https://docs.example.com/runbooks
- **Status Page:** https://status.example.com

## Related Runbooks

- [Failover Procedures](./failover-cosmos.md)
- [Incident Response](./incident.md)
- [On-Call Checklist](./oncall-checklist.md)
