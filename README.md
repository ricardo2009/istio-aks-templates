# 🚀 Istio Templates para AKS - Sistema Completamente Parametrizável

Este repositório contém templates Istio completamente parametrizáveis, projetados para máxima reutilização em múltiplas aplicações e esteiras de CI/CD no Azure Kubernetes Service (AKS) com Istio Add-on.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Pré-requisitos](#pré-requisitos)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Como Usar](#como-usar)
- [Configuração](#configuração)
- [Overlays de Ambiente](#overlays-de-ambiente)
- [Scripts de Deployment](#scripts-de-deployment)
- [Exemplos Práticos](#exemplos-práticos)
- [Troubleshooting](#troubleshooting)
- [Contribuição](#contribuição)

## 🌟 Visão Geral

### Por que Templates Parametrizáveis?

- **Reutilização Máxima**: Um conjunto de templates serve múltiplas aplicações
- **Padronização**: Configurações consistentes entre ambientes
- **Flexibilidade**: Adaptação fácil para diferentes cenários
- **CI/CD Friendly**: Integração simples em pipelines automatizados
- **AKS Optimized**: Configurado especificamente para AKS Istio Add-on

### Características Principais

✅ **100% Parametrizável**: Nenhum valor hardcoded nos templates  
✅ **Multi-ambiente**: Overlays específicos para dev/staging/prod  
✅ **AKS Native**: Usa namespaces e seletores específicos do AKS Istio  
✅ **Expert-level**: Configurações avançadas de tráfego, segurança e observabilidade  
✅ **CI/CD Ready**: Scripts automatizados para deployment  

## � Estrutura do Repositório

```
/
├── README.md                       # 📖 Documentação principal
├── values.yaml                     # ⚙️ Configuração base
├── schema.yaml                     # 📋 Schema de validação
├── .env.example                    # 📝 Template de configuração
├── .github/workflows/              # 🔄 GitHub Actions workflows
├── scripts/preprocess-templates.sh # 🛠️ Script de processamento
├── templates/                      # 📦 Templates Istio organizados
│   ├── traffic-management/         # 🔀 Gateway, VirtualService, etc.
│   ├── security/                   # 🔒 mTLS, Authorization, etc.
│   ├── observability/              # 📊 Telemetry, Monitoring
│   ├── resilience/                 # 🛡️ Circuit breaker, Retry
│   └── ...
├── overlays/                       # 🌍 Configurações por ambiente
│   ├── dev/values.yaml            # 🧪 Desenvolvimento
│   ├── staging/values.yaml        # 🚧 Staging
│   └── prod/values.yaml           # 🚀 Produção
├── docs/                          # 📚 Documentação adicional
└── examples/                      # 💡 Exemplos de uso
```

## �🔧 Pré-requisitos

### Ferramentas Necessárias

```bash
# Kubernetes CLI
kubectl version --client

# YAML processor
yq --version

# Environment substitution
envsubst --version

# Azure CLI (opcional, para gerenciar AKS)
az --version
```

### Cluster AKS com Istio

```bash
# Habilitar Istio Add-on no AKS
az aks mesh enable --resource-group <resource-group> --name <cluster-name>

# Verificar se Istio está instalado
kubectl get namespace aks-istio-system
kubectl get pods -n aks-istio-system
```

## 📁 Estrutura do Projeto

```
istio-templates/
├── 📁 traffic-management/          # Templates de gerenciamento de tráfego
│   ├── gateway.yaml               # Gateway parametrizável
│   ├── virtualservice.yaml        # VirtualService completo
│   └── destinationrule.yaml       # DestinationRule com circuit breakers
├── 📁 security/                   # Templates de segurança
│   ├── peer-authentication.yaml   # mTLS configuration
│   └── authorization-policy.yaml  # Políticas de autorização
├── 📁 observability/              # Templates de observabilidade
│   ├── telemetry.yaml            # Métricas e traces
│   └── access-logging.yaml       # Logs de acesso
├── 📁 resilience/                 # Templates de resilência
│   ├── service-entry.yaml        # Serviços externos
│   └── workload-entry.yaml       # Workloads externos
├── 📁 policies-governance/        # Políticas e governança
│   ├── request-authentication.yaml # Autenticação JWT
│   └── envoy-filter.yaml         # Filtros customizados
├── 📁 extensibility/              # Extensões avançadas
│   ├── wasm-plugin.yaml          # Plugins WASM
│   └── telemetry-v2.yaml         # Telemetria v2
├── 📁 additional-features/        # Recursos adicionais
│   ├── rate-limiting.yaml        # Rate limiting
│   └── circuit-breaker.yaml      # Circuit breakers
├── 📁 overlays/                   # Configurações por ambiente
│   ├── dev/values.yaml           # Desenvolvimento
│   ├── staging/values.yaml       # Homologação
│   └── prod/values.yaml          # Produção
├── values.yaml                   # Configuração principal
├── schema.yaml                   # Schema de validação
├── apply.sh                      # Script básico de aplicação
├── deploy-parametrized.sh        # Script avançado parametrizado
└── README.md                     # Esta documentação
```

## 🚀 Como Usar

### Método 1: Script Automatizado (Recomendado)

```bash
# Dar permissão de execução
chmod +x deploy-parametrized.sh

# Deploy para desenvolvimento
./deploy-parametrized.sh dev myapi myapi-dev

# Deploy para staging
./deploy-parametrized.sh staging frontend frontend-staging

# Deploy para produção  
./deploy-parametrized.sh prod backend backend-prod
```

### Método 2: Manual com envsubst

```bash
# 1. Definir variáveis de ambiente
export APP_NAME="myapi"
export ENVIRONMENT="prod"
export NAMESPACE="myapi-prod"
export SERVICE_HOST="api.company.com"
# ... outras variáveis

# 2. Processar templates
envsubst < traffic-management/gateway.yaml > processed-gateway.yaml
envsubst < traffic-management/virtualservice.yaml > processed-virtualservice.yaml

# 3. Aplicar no cluster
kubectl apply -f processed-gateway.yaml -n $NAMESPACE
kubectl apply -f processed-virtualservice.yaml -n $NAMESPACE
```

### Método 3: Integração CI/CD

```yaml
# Azure DevOps Pipeline Example
steps:
- task: Bash@3
  displayName: 'Deploy Istio Templates'
  inputs:
    targetType: 'inline'
    script: |
      # Baixar templates do repositório
      git clone https://github.com/company/istio-templates.git
      cd istio-templates
      
      # Executar deploy parametrizado
      ./deploy-parametrized.sh $(environment) $(appName) $(namespace)
  env:
    KUBECONFIG: $(kubeconfig)
```

## ⚙️ Configuração

### Arquivo values.yaml Principal

O arquivo `values.yaml` contém todas as configurações default:

```yaml
global:
  app: "myapp"
  version: "1.0.0"
  environment: "dev"

trafficManagement:
  gateway:
    enabled: true
    instances:
      main-gateway:
        hosts:
          - "app.example.com"
        tls:
          mode: "SIMPLE"
```

### Variáveis de Template

Os templates usam sintaxe `${VARIABLE_NAME}` para substituição:

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: ${GATEWAY_NAME}
  namespace: ${NAMESPACE}
spec:
  selector:
    istio: ${GATEWAY_SELECTOR}  # aks-istio-ingressgateway-external
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "${SERVICE_HOST}"
```

### Variáveis Principais Suportadas

| Categoria | Variável | Descrição | Exemplo |
|-----------|----------|-----------|---------|
| **Global** | `APP_NAME` | Nome da aplicação | `myapi` |
| | `VERSION` | Versão da aplicação | `1.0.0` |
| | `ENVIRONMENT` | Ambiente | `prod` |
| | `NAMESPACE` | Namespace K8s | `myapi-prod` |
| **Gateway** | `GATEWAY_SELECTOR` | Seletor do gateway | `aks-istio-ingressgateway-external` |
| | `SERVICE_HOST` | Host do serviço | `api.company.com` |
| **VirtualService** | `SERVICE_NAME` | Nome do serviço | `frontend-service` |
| | `SERVICE_PORT` | Porta do serviço | `8080` |
| | `WEIGHT_PRIMARY` | Peso do tráfego principal | `90` |
| | `WEIGHT_CANARY` | Peso do canary | `10` |

## 🌍 Overlays de Ambiente

### Desenvolvimento (dev)

```yaml
# overlays/dev/values.yaml
global:
  environment: "dev"
  debug: true

trafficManagement:
  virtualService:
    instances:
      main-vs:
        faultInjection:
          delay:
            percentage: 2.0  # Teste de latência
          abort:
            percentage: 0.5  # Teste de falhas
```

### Produção (prod)

```yaml
# overlays/prod/values.yaml
global:
  environment: "prod"
  debug: false

security:
  peerAuthentication:
    instances:
      default-pa:
        mtls:
          mode: "STRICT"  # mTLS obrigatório

trafficManagement:
  virtualService:
    instances:
      main-vs:
        faultInjection:
          delay:
            percentage: 0  # Sem fault injection
```

## 📜 Scripts de Deployment

### deploy-parametrized.sh

Script principal com funcionalidades completas:

- ✅ Validação de pré-requisitos
- ✅ Mesclagem de overlays de ambiente
- ✅ Substituição de variáveis
- ✅ Validação de manifests
- ✅ Deploy ordenado
- ✅ Status do deployment

```bash
# Uso completo
./deploy-parametrized.sh [environment] [app_name] [namespace]

# Exemplos
./deploy-parametrized.sh dev myapi myapi-dev
./deploy-parametrized.sh prod frontend frontend-prod
```

## 💡 Exemplos Práticos

### Exemplo 1: API Backend

```bash
# Configurar variáveis específicas
export APP_NAME="backend-api"
export SERVICE_HOST="api.company.com"
export SERVICE_NAME="backend-service" 
export SERVICE_PORT="8080"

# Deploy
./deploy-parametrized.sh prod backend-api backend-prod
```

### Exemplo 2: Frontend com Canary

```bash
# Configurar pesos de canary
export WEIGHT_PRIMARY="80"
export WEIGHT_CANARY="20"

# Deploy com canary deployment
./deploy-parametrized.sh staging frontend frontend-staging
```

### Exemplo 3: Microserviço com Rate Limiting

```bash
# Configurar rate limiting
export RATE_LIMIT_ENABLED="true"
export RATE_LIMIT_RPS="100"

# Deploy
./deploy-parametrized.sh prod user-service users-prod
```

## 🔍 Troubleshooting

### Problemas Comuns

#### 1. Gateway não está funcionando

```bash
# Verificar se Istio add-on está ativo
kubectl get pods -n aks-istio-system

# Verificar seletores corretos
kubectl get service -n aks-istio-ingress
```

#### 2. Variáveis não substituídas

```bash
# Verificar se todas as variáveis estão definidas
env | grep -E "(APP_NAME|SERVICE_HOST|NAMESPACE)"

# Testar substituição manual
envsubst < template.yaml
```

#### 3. Validação de manifests falha

```bash
# Validar YAML syntax
yq e '.' processed-manifest.yaml

# Validar com kubectl
kubectl --dry-run=client apply -f processed-manifest.yaml
```

### Logs e Debug

```bash
# Logs do gateway
kubectl logs -n aks-istio-system -l app=istiod

# Status dos recursos Istio
kubectl get gateway,virtualservice,destinationrule -A

# Debug do proxy sidecar
kubectl logs <pod-name> -c istio-proxy
```

## 🔐 Configurações de Segurança AKS

### mTLS Automático

O AKS Istio add-on configura mTLS automaticamente:

```yaml
# peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: ${PA_NAME}
  namespace: ${NAMESPACE}
spec:
  mtls:
    mode: ${MTLS_MODE}  # STRICT para prod, PERMISSIVE para dev
```

### Políticas de Autorização

```yaml
# authorization-policy.yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: ${AUTH_POLICY_NAME}
spec:
  action: ${AUTH_ACTION}  # ALLOW/DENY
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/${NAMESPACE}/sa/${SERVICE_ACCOUNT}"]
```

## 📊 Observabilidade

### Métricas Automáticas

```bash
# Verificar métricas do Prometheus
kubectl port-forward -n aks-istio-system svc/prometheus 9090:9090

# Grafana (se instalado)
kubectl port-forward -n aks-istio-system svc/grafana 3000:3000
```

### Tracing com Jaeger

```bash
# Acessar Jaeger UI
kubectl port-forward -n aks-istio-system svc/jaeger-query 16686:16686
```

## 🤝 Contribuição

### Como Contribuir

1. Fork do repositório
2. Criar branch para feature: `git checkout -b feature/nova-funcionalidade`
3. Commit das mudanças: `git commit -am 'Adiciona nova funcionalidade'`
4. Push para branch: `git push origin feature/nova-funcionalidade`
5. Abrir Pull Request

### Padrões de Código

- Templates devem ser 100% parametrizáveis
- Usar variáveis com nomes descritivos
- Documentar todas as variáveis no schema.yaml
- Incluir exemplos nos overlays
- Testar em múltiplos ambientes

### Adicionando Novos Templates

1. Criar template em diretório apropriado
2. Usar sintaxe `${VARIABLE_NAME}` para parametrização
3. Documentar variáveis em schema.yaml
4. Adicionar configuração em values.yaml
5. Criar testes nos overlays
6. Atualizar deploy-parametrized.sh se necessário

## 📚 Referências

- [Istio Documentation](https://istio.io/latest/docs/)
- [AKS Istio Add-on](https://docs.microsoft.com/en-us/azure/aks/istio-about)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/aks/)

## 📄 Licença

Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

---

## 🏷️ Tags

`istio` `aks` `kubernetes` `azure` `service-mesh` `templates` `ci-cd` `devops` `microservices` `parametrizable`

**Criado com ❤️ para máxima reutilização em múltiplas aplicações e esteiras de CI/CD**