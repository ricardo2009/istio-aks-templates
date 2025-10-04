# Architecture Documentation

## Overview

This solution implements a Microsoft-first architecture for running microservices on Azure Kubernetes Service (AKS) with Istio service mesh, using Azure API Management as a bridge between clusters.

## Key Components

### 1. AKS Clusters (2)

- **Cluster A (East US)**: Hosts Orders service
- **Cluster B (West US)**: Hosts Payments service
- **Istio Add-on**: Managed by Azure, provides service mesh capabilities
- **CNI**: Cilium Overlay mode
- **Network Policy**: Cilium
- **Workload Identity**: Enabled for secure access to Azure resources

### 2. Azure API Management (APIM)

- Acts as the **bridge** between Cluster A and Cluster B
- All inter-cluster communication goes through APIM
- Provides:
  - JWT validation
  - Rate limiting
  - Request/response transformation
  - API versioning
  - Caching

### 3. Cosmos DB

- **Multi-region**: Primary in East US, secondary in West US
- **Consistency**: Session level
- **Unique Keys**: Enforced on orderId and paymentId
- **Containers**: orders, payments
- **Partition Strategy**: customerId for orders, orderId for payments
- **Change Feed**: Connected to Service Bus for event streaming

### 4. Observability Stack

- **Managed Prometheus**: Metrics collection
- **Managed Grafana**: Visualization and dashboards
- **Azure Monitor**: Logs and diagnostics
- **Log Analytics**: Centralized logging
- **SLOs**: p95/p99 latency, error rate, availability

### 5. Security

- **mTLS STRICT**: Enforced in all namespaces
- **AuthorizationPolicy**: Default-deny, explicit allow rules
- **Egress Control**: Only APIM endpoints allowed
- **Workload Identity**: For Azure resource access
- **Key Vault CSI**: Secret management
- **Network Policies**: Cilium-based

## Data Flow

### Order Creation Flow

```
1. External request → APIM → Cluster A Ingress Gateway
2. Ingress Gateway → Orders Service (mTLS)
3. Orders Service → Cosmos DB (create order)
4. Orders Service → APIM → Cluster B Ingress Gateway (payment request)
5. Cluster B Ingress Gateway → Payments Service (mTLS)
6. Payments Service → Cosmos DB (create payment)
7. Response flows back through APIM
```

### Key Points

- All traffic within cluster: mTLS via Istio
- All traffic between clusters: HTTPS via APIM
- No direct cluster-to-cluster communication
- APIM provides observability, security, and resilience

## Network Architecture

```
┌─────────────────────────────────────────────┐
│          Azure Subscription                  │
│                                              │
│  ┌────────────────────────────────────┐     │
│  │  Resource Group: Core              │     │
│  │  - APIM                            │     │
│  │  - ACR                             │     │
│  │  - Cosmos DB                       │     │
│  │  - Key Vault                       │     │
│  │  - Log Analytics                   │     │
│  │  - Managed Prometheus              │     │
│  │  - Managed Grafana                 │     │
│  │  - Service Bus                     │     │
│  └────────────────────────────────────┘     │
│                                              │
│  ┌────────────────────────────────────┐     │
│  │  RG: AKS-A (East US)               │     │
│  │  VNet: 10.1.0.0/16                 │     │
│  │  - AKS Subnet: 10.1.0.0/20         │     │
│  │  - Istio Add-on enabled            │     │
│  │  - Orders Service                  │     │
│  └────────────────────────────────────┘     │
│                                              │
│  ┌────────────────────────────────────┐     │
│  │  RG: AKS-B (West US)               │     │
│  │  VNet: 10.2.0.0/16                 │     │
│  │  - AKS Subnet: 10.2.0.0/20         │     │
│  │  - Istio Add-on enabled            │     │
│  │  - Payments Service                │     │
│  └────────────────────────────────────┘     │
└─────────────────────────────────────────────┘
```

## Deployment Model

### Build Pipeline

- Uses `az acr build` for remote container builds
- No local Docker required
- Images tagged with Git SHA and latest

### Deployment Pipeline

- Uses `az aks command invoke` for kubectl operations
- No local kubectl required
- Runs commands inside AKS cluster
- Ensures rollout success with `kubectl rollout status`

### Infrastructure as Code

- Bicep modules for all resources
- Subscription-level deployment
- Modular structure:
  - `main.bicep`: Orchestration
  - `rg-core/main.bicep`: Shared resources
  - `aks/main.bicep`: AKS clusters

## High Availability & Disaster Recovery

- **Multi-region**: Clusters in different regions
- **APIM Failover**: Can route to healthy cluster
- **Cosmos DB Replication**: Automatic multi-region sync
- **Auto-scaling**: HPA enabled on deployments
- **Health Checks**: Liveness and readiness probes

## Limitations & Constraints

- Istio add-on doesn't support native multi-cluster mesh
- APIM used as workaround for inter-cluster communication
- Premium APIM required for VNet integration (using Developer for dev/test)
- CNI Cilium in Overlay mode (not direct routing)

## Future Enhancements

- When Istio add-on supports multi-cluster, migrate from APIM bridge
- Implement chaos engineering tests
- Add more SLO definitions
- Implement progressive delivery with Flagger
- Add distributed tracing dashboards
