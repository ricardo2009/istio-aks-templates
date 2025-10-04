# Microsoft-First AKS + Istio Add-on Solution

Este projeto implementa uma arquitetura empresarial Microsoft-first usando:

- **AKS** com Istio add-on (managed)
- **Azure API Management** como ponte entre clusters
- **Cosmos DB** multi-região com Session consistency
- **Bicep** para infraestrutura como código
- **GitHub Actions** com OIDC para CI/CD
- **`az acr build`** para build remoto de imagens
- **`az aks command invoke`** para deploy sem kubectl local

## Arquitetura

```
┌─────────────────────────────────────────────────────┐
│           Azure API Management (APIM)               │
│         (Ponte entre Clusters A e B)                │
└────────────┬──────────────────────┬─────────────────┘
             │                      │
    ┌────────▼────────┐    ┌───────▼─────────┐
    │  AKS Cluster A  │    │  AKS Cluster B  │
    │  (East US)      │    │  (West US)      │
    │                 │    │                 │
    │  Orders Service │    │ Payments Service│
    │  + Istio add-on │    │  + Istio add-on │
    └────────┬────────┘    └────────┬────────┘
             │                      │
             └──────────┬───────────┘
                        │
              ┌─────────▼──────────┐
              │   Cosmos DB        │
              │   (Multi-region)   │
              └────────────────────┘
```

## Componentes Principais

- **2 Clusters AKS** com Istio add-on, CNI Cilium (Overlay), NetworkPolicy Cilium
- **APIM** para comunicação inter-cluster (A ↔ B sempre via APIM)
- **Cosmos DB** com Session consistency, Unique Keys, multi-região
- **Managed Prometheus & Grafana** para observabilidade
- **Service Bus** para Change Feed do Cosmos
- **Key Vault** com CSI driver e Workload Identity
- **mTLS STRICT** + AuthorizationPolicy default-deny

## Estrutura do Repositório

```
├── infra/
│   └── bicep/
│       ├── main.bicep           # Orquestração principal
│       ├── rg-core/             # APIM, ACR, Cosmos, Logs
│       └── aks/                 # Clusters AKS + Istio
├── apps/
│   ├── orders/                  # Serviço Orders (Go)
│   │   ├── Dockerfile
│   │   ├── k8s/                 # Kubernetes manifests
│   │   └── istio/               # Istio configs
│   └── payments/                # Serviço Payments (Python)
│       ├── Dockerfile
│       ├── k8s/
│       └── istio/
├── observability/
│   ├── prometheus/rules/        # Recording/Alert rules
│   └── grafana/dashboards/      # Dashboards
├── tests/
│   ├── k6/                      # Performance tests
│   ├── chaos/                   # Chaos engineering
│   └── policy/                  # Policy tests
├── docs/
│   ├── Architecture.md
│   ├── SLOs.md
│   └── Runbooks/
├── prompts/
│   └── ci-lab-system-prompt.md
└── .github/workflows/
    └── ci-cd.yaml               # Pipeline principal
```

## Deployment

### Pré-requisitos

1. Azure Subscription com permissões de Owner
2. Service Principal com OIDC configurado
3. GitHub Secrets configurados:
   - `AZURE_SUBSCRIPTION_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID`

### Deploy via GitHub Actions

O workflow executa automaticamente:

1. **Provision Infrastructure** - Deploy Bicep (APIM, ACR, Cosmos, AKS)
2. **Build Images** - `az acr build` para orders e payments
3. **Deploy Orders** - `az aks command invoke` no Cluster A
4. **Deploy Payments** - `az aks command invoke` no Cluster B
5. **Validate** - Health checks e rollout status

### Deploy Manual

```bash
# 1. Login Azure com OIDC
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --tenant $AZURE_TENANT_ID \
  --federated-token $(cat token.txt)

# 2. Deploy Bicep
az deployment sub create \
  --location eastus \
  --template-file infra/bicep/main.bicep \
  --parameters environment=dev location=eastus

# 3. Build images
az acr build --registry <acr-name> \
  --image shop/orders:latest \
  --file apps/orders/Dockerfile \
  apps/orders

# 4. Deploy com command invoke
az aks command invoke \
  --resource-group <rg-name> \
  --name <aks-name> \
  --command "kubectl apply -f -" \
  --file apps/orders/k8s/deployment.yaml
```

## Princípios Microsoft-First

- ✅ Bicep (não Terraform)
- ✅ `az acr build` (sem Docker local)
- ✅ `az aks command invoke` (sem kubectl local)
- ✅ Istio add-on (não instalação manual)
- ✅ APIM para inter-cluster (não Istio multi-cluster)
- ✅ Managed Prometheus/Grafana
- ✅ Workload Identity + Key Vault CSI
- ✅ GitHub Actions com OIDC

## Segurança

- mTLS STRICT em todos os namespaces
- AuthorizationPolicy default-deny
- Egress restrito apenas a APIM
- Workload Identity para acesso a recursos Azure
- Key Vault CSI para secrets
- NetworkPolicy Cilium

## Observabilidade

- Managed Prometheus com recording rules
- Grafana com dashboards pré-configurados
- SLOs definidos (p95/p99 latency, error rate)
- Azure Monitor para logs e métricas
- Distributed tracing (via Istio)

## Testes

- **k6** para performance (latência, throughput)
- **Chaos Engineering** para resiliência
- **Cosmos DB idempotency** para duplicate detection
- **APIM routing** para validação A ↔ B

## Licença

MIT
