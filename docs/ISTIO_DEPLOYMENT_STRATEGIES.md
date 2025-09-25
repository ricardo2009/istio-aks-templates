# Istio Service Mesh: Estratégias de Implantação Completas

## 📋 Índice
1. [Introdução ao Istio](#introdução-ao-istio)
2. [Arquitetura Visual do Istio](#arquitetura-visual-do-istio)
3. [Configuração de Roteamento de Tráfego](#configuração-de-roteamento-de-tráfego)
4. [Estratégias de Escalonamento](#estratégias-de-escalonamento)
5. [Segurança mTLS](#segurança-mtls)
6. [Deployments Blue/Green](#deployments-bluegreen)
7. [Deployments Canary](#deployments-canary)
8. [Políticas de Autorização](#políticas-de-autorização)
9. [Monitoramento e Observabilidade](#monitoramento-e-observabilidade)
10. [Cenários Práticos de Uso](#cenários-práticos-de-uso)

---

## 🎯 Introdução ao Istio

O **Istio** é uma malha de serviços (service mesh) que fornece uma camada de infraestrutura dedicada para facilitar as comunicações entre serviços. No Azure Kubernetes Service (AKS), utilizamos o **add-on gerenciado do Istio**, que simplifica a instalação e manutenção.

### Principais Componentes

```
┌─────────────────────────────────────────────────────────────┐
│                    ISTIO CONTROL PLANE                     │
│                  (aks-istio-system)                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │   PILOT     │  │   CITADEL   │  │   GALLEY    │       │
│  │(Configuração│  │ (Segurança) │  │(Validação)  │       │
│  │ & Descoberta│  │             │  │             │       │
│  └─────────────┘  └─────────────┘  └─────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DATA PLANE                              │
│                  (Envoy Proxies)                           │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │   Pod A     │  │   Pod B     │  │   Pod C     │       │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │       │
│  │ │ Envoy   │ │  │ │ Envoy   │ │  │ │ Envoy   │ │       │
│  │ │ Proxy   │ │  │ │ Proxy   │ │  │ │ Proxy   │ │       │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │       │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │       │
│  │ │   App   │ │  │ │   App   │ │  │ │   App   │ │       │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │       │
│  └─────────────┘  └─────────────┘  └─────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Vantagens do AKS Istio Add-on
- ✅ **Gerenciamento simplificado**: Microsoft cuida da instalação e atualizações
- ✅ **Integração nativa**: Configuração automática com AKS
- ✅ **Suporte oficial**: Suporte empresarial da Microsoft
- ✅ **Segurança**: Configurações de segurança otimizadas

---

## 🏗️ Arquitetura Visual do Istio

### Fluxo de Tráfego Completo

```
Internet/Usuário
        │
        ▼
┌─────────────────┐
│  Load Balancer  │ ← Azure Load Balancer
│   (Azure LB)    │
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ Ingress Gateway │ ← Istio Ingress Gateway
│     (Envoy)     │   (aks-istio-ingressgateway-external)
└─────────────────┘
        │
        ▼
┌─────────────────┐
│  Virtual Service│ ← Regras de roteamento
│   (Routing)     │   Weight-based, Header-based
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ Destination Rule│ ← Políticas de tráfego
│  (Load Balance) │   Subsets, Circuit Breaker
└─────────────────┘
        │
        ▼
┌─────────────────┐
│   Service Mesh  │ ← Comunicação entre pods
│   (mTLS + Auth) │   com Envoy Proxies
└─────────────────┘
```

---

## 🚦 Configuração de Roteamento de Tráfego

### Gateway Configuration

O **Gateway** define como o tráfego externo entra no mesh:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: api-gateway
  namespace: default
spec:
  selector:
    istio: aks-istio-ingressgateway-external  # Seletor específico do AKS
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: api-tls-secret
    hosts:
    - api.exemplo.com
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - api.exemplo.com
    tls:
      httpsRedirect: true  # Redireciona HTTP para HTTPS
```

### Virtual Service: Roteamento Inteligente

O **VirtualService** define como o tráfego é roteado dentro do mesh:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-virtualservice
spec:
  hosts:
  - api.exemplo.com
  gateways:
  - api-gateway
  http:
  # Roteamento baseado em cabeçalhos (para usuários beta)
  - match:
    - headers:
        x-user-type:
          exact: "beta"
    route:
    - destination:
        host: api-service
        subset: v2-beta
      weight: 100
  
  # Roteamento por peso (Canary deployment)
  - match:
    - uri:
        prefix: "/api/v1"
    route:
    - destination:
        host: api-service
        subset: stable
      weight: 90  # 90% para versão estável
    - destination:
        host: api-service
        subset: canary
      weight: 10  # 10% para versão canary
  
  # Roteamento baseado em path
  - match:
    - uri:
        prefix: "/api/admin"
    route:
    - destination:
        host: admin-service
        subset: stable
```

### Destination Rule: Políticas de Tráfego

O **DestinationRule** define como o tráfego se comporta após o roteamento:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-service-destination
spec:
  host: api-service
  trafficPolicy:
    loadBalancer:
      simple: LEAST_CONN  # Algoritmo de balanceamento
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 10
    circuitBreaker:
      consecutiveGatewayErrors: 5
      interval: 30s
      baseEjectionTime: 30s
  subsets:
  - name: stable
    labels:
      version: v1
    trafficPolicy:
      portLevelSettings:
      - port:
          number: 8080
        loadBalancer:
          simple: ROUND_ROBIN
  - name: canary
    labels:
      version: v2
  - name: v2-beta
    labels:
      version: v2-beta
```

---

## 📈 Estratégias de Escalonamento

### 1. Escalonamento Horizontal (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
  minReplicas: 3
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100  # Dobra o número de pods
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10   # Remove 10% dos pods por vez
        periodSeconds: 60
```

### 2. Escalonamento com base em métricas customizadas

```yaml
# Usando métricas do Istio/Envoy
- type: Pods
  pods:
    metric:
      name: istio_requests_per_second
    target:
      type: AverageValue
      averageValue: "100"
```

### Visualização do Escalonamento

```
Estado Inicial (3 réplicas):
┌─────┐ ┌─────┐ ┌─────┐
│ Pod │ │ Pod │ │ Pod │
│  1  │ │  2  │ │  3  │
└─────┘ └─────┘ └─────┘
   │       │       │
   └───────┼───────┘
           │
    ┌─────────────┐
    │ Load Balancer│
    └─────────────┘

Sob carga alta (CPU > 70%):
┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
│ Pod │ │ Pod │ │ Pod │ │ Pod │ │ Pod │ │ Pod │
│  1  │ │  2  │ │  3  │ │  4  │ │  5  │ │  6  │
└─────┘ └─────┘ └─────┘ └─────┘ └─────┘ └─────┘
   │       │       │       │       │       │
   └───────┼───────┼───────┼───────┼───────┘
           │       │       │       │
    ┌─────────────────────────────────┐
    │        Load Balancer            │
    └─────────────────────────────────┘
```

---

## 🔒 Segurança mTLS

### Mutual TLS (mTLS) Explained

O mTLS garante que todas as comunicações no mesh sejam criptografadas e autenticadas:

```
Serviço A          Istio Control Plane          Serviço B
    │                       │                       │
    ├─[1] Solicita cert ────┤                       │
    │                       │                       │
    │←─[2] Recebe cert A ───┤                       │
    │                       │                       │
    │                       ├─[3] Solicita cert ────┤
    │                       │                       │
    │                       │←─[4] Recebe cert B ───┤
    │                       │                       │
    ├─[5] mTLS handshake ───┼───────────────────────┤
    │   (cert A + cert B)   │                       │
    │                       │                       │
    │←─[6] Conexão segura ──┼───────────────────────┤
    │                       │                       │
```

### Configuração PeerAuthentication

```yaml
# Política mesh-wide (aplicada a todos os serviços)
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: mesh-wide-mtls
  namespace: aks-istio-system  # Namespace do Istio no AKS
spec:
  mtls:
    mode: STRICT  # Apenas tráfego mTLS permitido

---
# Política específica para um serviço
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: api-service-mtls
  namespace: default
spec:
  selector:
    matchLabels:
      app: api-service
  mtls:
    mode: STRICT
  portLevelMtls:
    8080:
      mode: STRICT    # Porto da aplicação
    8443:
      mode: STRICT    # Porto HTTPS
```

### Modos de mTLS

| Modo | Descrição | Uso Recomendado |
|------|-----------|-----------------|
| `STRICT` | Apenas mTLS | Produção |
| `PERMISSIVE` | mTLS + plaintext | Migração gradual |
| `DISABLE` | Sem mTLS | Desenvolvimento/Debug |

### Visualização do mTLS

```
Sem mTLS (DISABLE):
Service A ──── HTTP ──── Service B
   │                        │
   └─── Texto claro ────────┘

Com mTLS (STRICT):
Service A ──── mTLS ──── Service B
   │                        │
   ├─ Certificado A         │
   │                        ├─ Certificado B
   └─ Criptografia TLS ─────┘
        (Mutual Auth)
```

---

## 🔵 Deployments Blue/Green

### Conceito Blue/Green

O deployment Blue/Green mantém duas versões completas do aplicativo, alternando o tráfego entre elas:

```
Estado Inicial (Blue ativo):
┌─────────────────┐    100%    ┌─────────────────┐
│   BLUE (v1.0)   │ ←─────── │  Load Balancer  │
│   3 réplicas    │          └─────────────────┘
└─────────────────┘
┌─────────────────┐      0%
│  GREEN (v2.0)   │
│   3 réplicas    │
└─────────────────┘

Durante o Switch:
┌─────────────────┐      0%    ┌─────────────────┐
│   BLUE (v1.0)   │           │  Load Balancer  │
│   3 réplicas    │           └─────────────────┘
└─────────────────┘                    │
┌─────────────────┐    100%           ▼
│  GREEN (v2.0)   │ ←──────────────────┘
│   3 réplicas    │
└─────────────────┘
```

### Implementação com Istio

#### 1. Deployment das duas versões

```yaml
# Blue deployment (versão atual)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-service
      version: blue
  template:
    metadata:
      labels:
        app: api-service
        version: blue
    spec:
      containers:
      - name: api
        image: api-service:v1.0
        ports:
        - containerPort: 8080

---
# Green deployment (nova versão)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-service
      version: green
  template:
    metadata:
      labels:
        app: api-service
        version: green
    spec:
      containers:
      - name: api
        image: api-service:v2.0
        ports:
        - containerPort: 8080
```

#### 2. VirtualService para Blue/Green

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-service-bluegreen
spec:
  hosts:
  - api-service
  http:
  - match:
    - headers:
        x-deployment-version:
          exact: "green"
    route:
    - destination:
        host: api-service
        subset: green
      weight: 100
  
  # Tráfego padrão vai para blue
  - route:
    - destination:
        host: api-service
        subset: blue
      weight: 100  # Inicialmente 100% blue
```

#### 3. Script de Switch Blue/Green

```bash
#!/bin/bash
# switch-bluegreen.sh

CURRENT_VERSION=$(kubectl get virtualservice api-service-bluegreen -o jsonpath='{.spec.http[1].route[0].destination.subset}')

if [ "$CURRENT_VERSION" = "blue" ]; then
    NEW_VERSION="green"
    echo "Switching from BLUE to GREEN"
else
    NEW_VERSION="blue"
    echo "Switching from GREEN to BLUE"
fi

# Atualiza o VirtualService
kubectl patch virtualservice api-service-bluegreen --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/http/1/route/0/destination/subset",
    "value": "'$NEW_VERSION'"
  }
]'

echo "Traffic switched to $NEW_VERSION"

# Verifica o health da nova versão
kubectl wait --for=condition=ready pod -l version=$NEW_VERSION --timeout=300s
```

### Vantagens e Desvantagens

**✅ Vantagens:**
- Switch instantâneo
- Rollback rápido
- Zero downtime garantido
- Testes em produção com tráfego real

**❌ Desvantagens:**
- Dobra o uso de recursos
- Complexidade na gestão de dados
- Não adequado para mudanças de schema

---

## 🕯️ Deployments Canary

### Conceito Canary

O deployment Canary direciona uma pequena porcentagem do tráfego para a nova versão:

```
Fase 1 (5% Canary):
┌─────────────────┐     95%    ┌─────────────────┐
│  STABLE (v1.0)  │ ←─────── │  Load Balancer  │
│   10 réplicas   │          └─────────────────┘
└─────────────────┘                   │
┌─────────────────┐      5%           ▼
│  CANARY (v2.0)  │ ←──────────────────┘
│    1 réplica    │
└─────────────────┘

Fase 2 (50% Canary):
┌─────────────────┐     50%    ┌─────────────────┐
│  STABLE (v1.0)  │ ←─────── │  Load Balancer  │
│    5 réplicas   │          └─────────────────┘
└─────────────────┘                   │
┌─────────────────┐     50%           ▼
│  CANARY (v2.0)  │ ←──────────────────┘
│    5 réplicas   │
└─────────────────┘

Fase 3 (100% Canary):
┌─────────────────┐      0%    ┌─────────────────┐
│  STABLE (v1.0)  │           │  Load Balancer  │
│    0 réplicas   │           └─────────────────┘
└─────────────────┘                   │
┌─────────────────┐    100%           ▼
│  CANARY (v2.0)  │ ←──────────────────┘
│   10 réplicas   │
└─────────────────┘
```

### Implementação Canary Avançada

#### 1. VirtualService com múltiplas estratégias

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-service-canary
spec:
  hosts:
  - api-service
  http:
  # Rota 1: Usuários beta sempre para canary
  - match:
    - headers:
        x-user-type:
          exact: "beta"
    route:
    - destination:
        host: api-service
        subset: canary
      weight: 100
  
  # Rota 2: Canary baseado em geolocalização
  - match:
    - headers:
        x-user-country:
          exact: "BR"
    route:
    - destination:
        host: api-service
        subset: stable
      weight: 80
    - destination:
        host: api-service
        subset: canary
      weight: 20  # 20% para usuários do Brasil
  
  # Rota 3: Canary geral (para outros países)
  - route:
    - destination:
        host: api-service
        subset: stable
      weight: 90
    - destination:
        host: api-service
        subset: canary
      weight: 10
```

#### 2. Flagger para Canary Automático

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: api-service-canary
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
  progressDeadlineSeconds: 60
  service:
    port: 8080
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      metadata:
        cmd: "hey -z 1m -q 10 -c 2 http://api-service.default:8080/"
```

#### 3. Script de promoção gradual

```bash
#!/bin/bash
# canary-promote.sh

WEIGHTS=(5 10 20 30 50 70 100)
CURRENT_WEIGHT=0

for weight in "${WEIGHTS[@]}"; do
    echo "Promoting canary to ${weight}%"
    
    # Atualiza o peso do canary
    kubectl patch virtualservice api-service-canary --type='json' -p='[
      {
        "op": "replace", 
        "path": "/spec/http/2/route/0/weight",
        "value": '$((100-weight))'
      },
      {
        "op": "replace",
        "path": "/spec/http/2/route/1/weight", 
        "value": '$weight'
      }
    ]'
    
    # Aguarda e verifica métricas
    sleep 300  # 5 minutos
    
    # Verifica taxa de erro
    ERROR_RATE=$(prometheus-query "error_rate")
    if (( $(echo "$ERROR_RATE > 1" | bc -l) )); then
        echo "High error rate detected: $ERROR_RATE%. Rolling back!"
        kubectl patch virtualservice api-service-canary --type='json' -p='[
          {
            "op": "replace",
            "path": "/spec/http/2/route/0/weight", 
            "value": 100
          },
          {
            "op": "replace",
            "path": "/spec/http/2/route/1/weight",
            "value": 0
          }
        ]'
        exit 1
    fi
    
    echo "Canary at ${weight}% is healthy"
done

echo "Canary promotion completed successfully!"
```

---

## 🛡️ Políticas de Autorização

### AuthorizationPolicy Avançado

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: api-service-rbac
spec:
  selector:
    matchLabels:
      app: api-service
  rules:
  # Regra 1: Admin access
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/admin-service"]
    to:
    - operation:
        methods: ["GET", "POST", "PUT", "DELETE"]
        paths: ["/api/admin/*"]
    when:
    - key: request.headers[x-admin-role]
      values: ["super-admin", "admin"]
  
  # Regra 2: User access (rate limited)
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/frontend-service"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/user/*"]
    when:
    - key: source.ip
      values: ["10.0.0.0/8"]  # Apenas IPs internos
    - key: request.headers[x-api-key]
      values: ["valid-api-key-*"]  # Wildcard match
  
  # Regra 3: Health checks (always allowed)
  - to:
    - operation:
        methods: ["GET"]
        paths: ["/health", "/ready", "/metrics"]
  
  # Regra 4: Rate limiting by JWT claims
  - from:
    - source:
        requestPrincipals: ["*"]
    to:
    - operation:
        methods: ["POST", "PUT", "DELETE"]
    when:
    - key: request.auth.claims[role]
      values: ["premium-user"]
    - key: request.auth.claims[rate_limit]
      values: ["1000"]  # 1000 requests per period
```

### Request Authentication (JWT)

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-authentication
spec:
  selector:
    matchLabels:
      app: api-service
  jwtRules:
  - issuer: "https://auth.exemplo.com"
    jwksUri: "https://auth.exemplo.com/.well-known/jwks.json"
    audiences: ["api-service"]
    forwardOriginalToken: true
  - issuer: "https://azure.microsoft.com/tenant-id"
    jwksUri: "https://login.microsoftonline.com/common/discovery/v2.0/keys"
    audiences: ["api://api-service"]
```

---

## 📊 Monitoramento e Observabilidade

### Métricas Istio Essenciais

#### 1. Métricas de Tráfego

```promql
# Taxa de requisições por segundo
sum(rate(istio_requests_total[1m])) by (destination_service_name)

# Taxa de erro por serviço
sum(rate(istio_requests_total{response_code!~"2.."}[1m])) 
  / sum(rate(istio_requests_total[1m])) by (destination_service_name)

# P99 de latência
histogram_quantile(0.99, 
  sum(rate(istio_request_duration_milliseconds_bucket[1m])) 
  by (destination_service_name, le))
```

#### 2. Dashboard Grafana

```json
{
  "dashboard": {
    "title": "Istio Service Mesh Overview",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "sum(rate(istio_requests_total[1m])) by (destination_service_name)"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "sum(rate(istio_requests_total{response_code!~\"2..\"}[1m])) / sum(rate(istio_requests_total[1m])) by (destination_service_name)"
          }
        ]
      }
    ]
  }
}
```

### Distributed Tracing

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio-tracing
data:
  mesh: |
    defaultConfig:
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*circuit_breakers.*"
        - ".*upstream_rq_retry.*"
        - ".*_cx_.*"
      tracing:
        sampling: 1.0  # 100% sampling para desenvolvimento
        custom_tags:
          environment:
            literal:
              value: "production"
          version:
            header:
              name: "x-app-version"
```

---

## 🎯 Cenários Práticos de Uso

### Cenário 1: E-commerce com Alta Disponibilidade

```yaml
# Configuração para um e-commerce que precisa de:
# - 99.99% uptime
# - Canary deployments seguros
# - Rate limiting para APIs
# - mTLS em todos os serviços

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ecommerce-api
spec:
  hosts:
  - shop.exemplo.com
  gateways:
  - shop-gateway
  http:
  # Checkout service (crítico) - sempre estável
  - match:
    - uri:
        prefix: "/api/checkout"
    route:
    - destination:
        host: checkout-service
        subset: stable
      weight: 100
    fault:
      delay:
        percentage:
          value: 0.1  # 0.1% de delay para testes
        fixedDelay: 5s
  
  # Product service - com canary
  - match:
    - uri:
        prefix: "/api/products"
    route:
    - destination:
        host: product-service
        subset: stable
      weight: 95
    - destination:
        host: product-service
        subset: canary
      weight: 5
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
```

### Cenário 2: Microserviços com Segregação de Ambientes

```yaml
# Configuração para desenvolvimento/staging/produção
# com isolamento completo e políticas específicas

apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: environment-isolation
spec:
  rules:
  # Desenvolvimento: acesso liberado
  - from:
    - source:
        namespaces: ["development"]
    when:
    - key: request.headers[x-environment]
      values: ["dev"]
  
  # Staging: apenas CI/CD e testers
  - from:
    - source:
        principals: 
        - "cluster.local/ns/cicd/sa/deployment-agent"
        - "cluster.local/ns/qa/sa/test-runner"
    when:
    - key: request.headers[x-environment] 
      values: ["staging"]
  
  # Produção: apenas tráfego autenticado
  - from:
    - source:
        requestPrincipals: ["*"]
    when:
    - key: request.headers[x-environment]
      values: ["prod"]
    - key: request.auth.claims[env_access]
      values: ["production"]
```

### Cenário 3: API Gateway com Rate Limiting

```yaml
apiVersion: networking.istio.io/v1beta1
kind: EnvoyFilter
metadata:
  name: rate-limit-filter
spec:
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.local_ratelimit
        typed_config:
          "@type": type.googleapis.com/udpa.type.v1.TypedStruct
          type_url: type.googleapis.com/envoy.extensions.filters.http.local_ratelimit.v3.LocalRateLimit
          value:
            stat_prefix: local_rate_limiter
            token_bucket:
              max_tokens: 100
              tokens_per_fill: 100
              fill_interval: 60s
            filter_enabled:
              runtime_key: local_rate_limit_enabled
              default_value:
                numerator: 100
                denominator: HUNDRED
            filter_enforced:
              runtime_key: local_rate_limit_enforced
              default_value:
                numerator: 100
                denominator: HUNDRED
```

---

## 📝 Resumo de Boas Práticas

### ✅ Do's (Faça)

1. **Segurança First**
   - Sempre use mTLS STRICT em produção
   - Implemente AuthorizationPolicy restritiva
   - Valide certificados e tokens JWT

2. **Observabilidade**
   - Configure distributed tracing
   - Monitore métricas de golden signals
   - Implemente alertas proativos

3. **Deployment Strategy**
   - Use Canary para releases críticas
   - Implemente health checks robustos
   - Tenha planos de rollback automatizados

4. **Performance**
   - Configure circuit breakers
   - Implemente timeout e retries adequados
   - Use connection pooling

### ❌ Don'ts (Não faça)

1. **Nunca em Produção**
   - mTLS em modo PERMISSIVE
   - AuthorizationPolicy sem regras
   - 100% de sampling de traces

2. **Evite**
   - Blue/Green para mudanças de schema
   - Canary sem métricas de validação
   - Rate limiting muito restritivo

---

## 🔗 Recursos Adicionais

- [Documentação Oficial do Istio](https://istio.io/docs/)
- [AKS Istio Add-on](https://docs.microsoft.com/azure/aks/istio-about)
- [Istio Security Best Practices](https://istio.io/docs/ops/best-practices/security/)
- [Flagger para Canary Deployments](https://flagger.app/)

---

*Este documento foi criado para fornecer uma visão abrangente das estratégias de deployment com Istio, com foco em implementações práticas e accessibility para desenvolvedores neurodivergentes. Cada seção inclui exemplos visuais e explicações detalhadas para facilitar a compreensão.*