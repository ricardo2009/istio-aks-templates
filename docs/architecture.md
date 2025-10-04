# Enterprise Istio on AKS - Architecture Documentation

## Overview

This document describes the enterprise-grade architecture for the Istio on AKS platform, designed to support 600,000+ requests per second with full observability, security, and progressive delivery capabilities.

## Architecture Principles

1. **100% Parameterized Infrastructure** - All configuration via `*.tfvars`, zero hardcoded values
2. **Security by Default** - mTLS STRICT, default deny policies, private clusters
3. **Multi-Region Resilience** - Active-active across regions with automatic failover
4. **Progressive Delivery** - Canary, Blue-Green, A/B testing with automatic rollback
5. **360° Observability** - Distributed tracing, metrics, logs, and SLOs

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure Front Door / CDN                        │
└────────────────────────┬─────────────────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────────────────┐
│                    Azure API Management (APIM)                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ Rate Limiting │ JWT Validation │ Caching │ API Versioning   │   │
│  └──────────────────────────────────────────────────────────────┘   │
└────────────────────────┬─────────────────────────────────────────────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
┌─────────▼──────────┐       ┌──────────▼─────────┐
│  AKS Cluster 1     │       │  AKS Cluster 2     │
│  (East US 2)       │       │  (West US 2)       │
│  ┌──────────────┐  │       │  ┌──────────────┐  │
│  │ Istio Ingress│  │       │  │ Istio Ingress│  │
│  │   Gateway    │  │       │  │   Gateway    │  │
│  └──────┬───────┘  │       │  └──────┬───────┘  │
│         │          │       │         │          │
│  ┌──────▼───────┐  │       │  ┌──────▼───────┐  │
│  │    NGINX     │  │       │  │    NGINX     │  │
│  │   Ingress    │  │       │  │   Ingress    │  │
│  └──────┬───────┘  │       │  └──────┬───────┘  │
│         │          │       │         │          │
│  ┌──────▼───────────────────────────────────────┐
│  │         Istio Service Mesh                   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  │ Frontend │  │  API GW  │  │ Services │   │
│  │  │  Service │  │  Service │  │   Pool   │   │
│  │  └──────────┘  └──────────┘  └──────────┘   │
│  │                                              │
│  │  Features:                                   │
│  │  - mTLS STRICT                              │
│  │  - Authorization Policies                   │
│  │  - Traffic Management                       │
│  │  - Circuit Breaking                         │
│  │  - Retries & Timeouts                       │
│  └──────────────────────────────────────────────┘
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  KEDA (Event-Driven Autoscaling)         │   │
│  │  - Prometheus Scaler                     │   │
│  │  - Queue Scaler                          │   │
│  │  - HTTP Scaler                           │   │
│  └──────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        Data Layer                                    │
│  ┌──────────────┐          ┌──────────────┐     ┌──────────────┐   │
│  │ Cosmos DB    │          │ Key Vault    │     │     ACR      │   │
│  │ Multi-Region │◄─────────┤   Secrets    │     │   Registry   │   │
│  │ Multi-Master │          │  Certificates│     │              │   │
│  └──────────────┘          └──────────────┘     └──────────────┘   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    Observability Stack                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │   Managed    │  │   Managed    │  │ Application  │              │
│  │  Prometheus  │  │   Grafana    │  │   Insights   │              │
│  └──────────────┘  └──────────────┘  └──────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. AKS Clusters

**Configuration:**
- **Network Plugin:** Azure CNI (advanced networking)
- **Network Policy:** Azure Network Policy
- **Identity:** Workload Identity + OIDC Issuer
- **Security:** Private clusters with API server VNet integration
- **Availability:** Multi-zone deployment across 3 availability zones
- **Node Pools:**
  - System pool: Dedicated for system components
  - User pool: Application workloads
  - Ingress pool: NGINX Ingress Controllers (tainted)
  - Jobs pool: Batch and background jobs

**Security Features:**
- Pod Security Admission (Baseline/Restricted)
- ResourceQuota and LimitRange per namespace
- Network Policies for micro-segmentation
- Azure Defender for Containers
- Image scanning with Trivy
- RBAC with Azure AD integration

### 2. Istio Service Mesh (Managed Add-on)

**Configuration:**
- **Revision:** asm-1-20 (managed by Azure)
- **mTLS Mode:** STRICT (enforced cluster-wide)
- **Telemetry:** v2 with OpenTelemetry integration
- **Ingress/Egress:** Dedicated gateways

**Security:**
- **PeerAuthentication:** STRICT mTLS for all services
- **AuthorizationPolicy:** Default deny + explicit allow rules
- **RequestAuthentication:** JWT/OIDC integration with Azure AD
- **Sidecar Configuration:** REGISTRY_ONLY outbound traffic policy
- **ServiceEntry:** Explicit whitelist for external services

**Traffic Management:**
- **VirtualService:** Advanced routing (canary, header-based, etc.)
- **DestinationRule:** Circuit breaking, connection pooling, outlier detection
- **Load Balancing:** LEAST_REQUEST, CONSISTENT_HASH
- **Retries & Timeouts:** Configured per service/route
- **Fault Injection:** For chaos engineering

**Observability:**
- **Metrics:** Envoy metrics exported to Prometheus
- **Tracing:** Distributed tracing to Application Insights
- **Access Logs:** Structured JSON logs
- **Service Graph:** Real-time topology via Kiali

### 3. NGINX Ingress Controller (Community)

**Why NGINX + Istio?**
- **NGINX:** Entry point for external traffic, TLS termination, L7 routing
- **Istio:** Internal service mesh, mTLS, advanced traffic management

**Features:**
- **High Availability:** 6+ replicas in production
- **Autoscaling:** HPA based on CPU/Memory/Request rate
- **Security Headers:** HSTS, CSP, X-Frame-Options, X-XSS-Protection
- **Rate Limiting:** Per IP/User/API key
- **Timeouts & Buffers:** Optimized for high throughput
- **TLS:** cert-manager integration with automatic renewal

### 4. KEDA (Managed Add-on)

**Scalers:**
- **Prometheus:** Scale based on custom metrics (latency, queue depth)
- **Azure Queue Storage:** Event-driven scaling for async workloads
- **HTTP:** Scale based on incoming HTTP requests
- **Cosmos DB:** Scale based on RU consumption

**Configuration:**
- Min/Max replicas per service
- Cooldown periods to prevent flapping
- SLO-aligned scaling triggers

### 5. Progressive Delivery with Flagger

**Deployment Strategies:**
1. **Canary:**
   - Progressive traffic shifting (10% → 25% → 50% → 100%)
   - SLO validation at each step (error rate < 1%, P95 latency < target)
   - Automatic rollback on SLO violation
   
2. **Blue-Green:**
   - Instant traffic switch
   - Pre-production validation
   - Quick rollback capability
   
3. **A/B Testing:**
   - Header/Cookie-based routing
   - Controlled experiments
   - Statistical significance validation

**Metrics & SLOs:**
- Error rate (< 1%)
- P95 latency (< service-specific target)
- Throughput (RPS within expected range)
- Custom business metrics

### 6. Azure API Management

**Features:**
- **Authentication:** OAuth 2.0, JWT validation
- **Rate Limiting:** Per subscription, IP, user
- **Caching:** Response caching to reduce backend load
- **API Versioning:** Multiple versions with routing
- **Transformation:** Request/Response manipulation
- **Private VNet Integration:** Internal-only APIs

### 7. Cosmos DB

**Configuration:**
- **Consistency Level:** Bounded Staleness (production), Session (dev/staging)
- **Multi-Region:** 3 regions in production
- **Multi-Master:** Write to any region
- **Autoscale RU/s:** Dynamic scaling based on load
- **Partition Strategy:** Optimized for access patterns
- **Indexing:** Custom indexes, TTL policies

**Monitoring:**
- 429 throttling alerts
- RU consumption trends
- Failover automation
- Cross-region replication lag

### 8. Azure Key Vault

**Features:**
- **RBAC:** Granular access control via Azure AD
- **Secrets:** Connection strings, API keys
- **Certificates:** TLS certs with automatic rotation
- **Keys:** Encryption keys for data at rest
- **CSI Driver:** Direct injection into pods
- **Rotation:** Automated with alerts before expiration

### 9. Observability Stack

**Managed Prometheus:**
- Metrics collection from Istio, NGINX, KEDA, apps
- Long-term retention (1 year in production)
- High-cardinality support
- PromQL queries

**Managed Grafana:**
- Pre-built dashboards (Istio, NGINX, AKS, Cosmos DB)
- Custom dashboards per service
- SLO tracking dashboards
- Real-time alerting

**Application Insights:**
- End-to-end distributed tracing
- Application performance monitoring
- Log aggregation and search
- Custom telemetry

**Log Analytics:**
- Centralized logging
- Query with KQL
- Compliance and audit logs
- Cost optimization via retention policies

## Network Architecture

### Network Segmentation

```
VNet: 10.0.0.0/16

├── AKS Primary Subnet: 10.0.1.0/24
│   └── System + User + Ingress node pools
│
├── AKS Secondary Subnet: 10.0.2.0/24
│   └── System + User + Ingress node pools
│
├── AKS LoadTest Subnet: 10.0.3.0/24
│   └── Load testing cluster
│
├── APIM Subnet: 10.0.4.0/24
│   └── APIM internal VNet integration
│
└── Private Endpoints Subnet: 10.0.5.0/24
    ├── Cosmos DB
    ├── Key Vault
    ├── ACR
    └── Storage Account
```

### Network Policies

1. **Default Deny:** All ingress/egress denied by default
2. **Explicit Allow:** Per-service network policies
3. **Namespace Isolation:** Cross-namespace communication controlled
4. **Egress Control:** Whitelist external endpoints

### Outbound Traffic

- **Production:** User-Defined Routing (UDR) through Azure Firewall
- **Non-Production:** Load Balancer

## Security Architecture

### Defense in Depth

1. **Network Layer:**
   - Private AKS clusters
   - NSGs on all subnets
   - Azure Firewall for egress
   - DDoS Protection

2. **Identity & Access:**
   - Azure AD integration
   - Workload Identity
   - RBAC (cluster + namespace level)
   - Service accounts per application

3. **Application Layer:**
   - Istio mTLS STRICT
   - Authorization policies
   - JWT validation
   - Secret management via Key Vault

4. **Data Layer:**
   - Encryption at rest (all services)
   - Encryption in transit (TLS 1.2+)
   - Private endpoints
   - RBAC on data stores

### Compliance & Governance

- **Azure Policy:** Enforce organizational standards
- **Defender for Cloud:** Security posture management
- **Audit Logs:** Centralized in Log Analytics
- **Compliance Standards:** SOC 2, PCI-DSS ready

## Disaster Recovery

### RTO/RPO Targets

- **RTO (Recovery Time Objective):** < 30 seconds
- **RPO (Recovery Point Objective):** < 1 second

### Failover Strategy

1. **AKS Cluster Failure:**
   - Traffic Manager routes to healthy cluster
   - Automatic with health probes
   
2. **Region Failure:**
   - DNS failover to secondary region
   - Cosmos DB automatic multi-region failover
   
3. **Application Failure:**
   - Istio circuit breakers prevent cascade
   - KEDA scales down failed pods
   - Flagger rolls back bad deployments

### Backup & Restore

- **Cosmos DB:** Continuous backup with point-in-time restore
- **Key Vault:** Soft delete + purge protection
- **AKS:** GitOps - cluster state in Git
- **Configuration:** All IaC in version control

## Performance Targets

### Target: 600,000 RPS

**Capacity Planning:**
- **AKS:** 30 nodes × 20,000 RPS/node = 600k RPS
- **NGINX:** 30 replicas × 20,000 RPS/replica = 600k RPS
- **Cosmos DB:** 100,000 RU/s autoscale
- **APIM:** Premium tier with autoscaling

**Latency Targets:**
- P50: < 50ms
- P95: < 100ms
- P99: < 200ms

**Availability:**
- Target: 99.99% (4.38 minutes downtime/month)
- Multi-region active-active
- Automated failover

## Cost Optimization

### Strategies

1. **Right-Sizing:**
   - Node pool sizing based on actual usage
   - Autoscaling min/max tuned per environment
   
2. **Reserved Instances:**
   - 1-year or 3-year reservations for production
   
3. **Spot Instances:**
   - For non-critical workloads (batch jobs)
   
4. **Resource Quotas:**
   - Prevent overprovisioning
   - Cost allocation per team/service
   
5. **Monitoring:**
   - Cost alerts
   - Showback/Chargeback via tags
   - Unused resource detection

## Next Steps

1. Review [Traffic Management](./traffic-management.md)
2. Review [Observability](./observability.md)
3. Review [Scaling Strategy](./scaling.md)
4. Review [Runbooks](./runbooks/)
