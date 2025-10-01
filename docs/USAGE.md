# 📖 Guia de Uso Completo - Istio Demo Lab# 📖 Como Usar os Templates Istio



## 🎯 Visão Geral## 🎯 Visão Geral



Este laboratório demonstra **todas as capacidades principais do Istio Managed Add-on no AKS** em um único ambiente unificado chamado `demo`. O lab integra:Este repositório utiliza a **estratégia Helm sem Helm** - templates com sintaxe familiar `{{ .Values.xxx }}` processados por um renderizador Python customizado.



- **Segurança**: mTLS STRICT + JWT (Azure AD) + RBAC## 🚀 Uso Básico

- **Gerenciamento de Tráfego**: Canary + Blue-Green + A/B Testing simultaneamente

- **Observabilidade**: Telemetria + Tracing + Métricas customizadas### 1. **Renderizar Templates**

- **Controle de Egress**: ServiceEntry + Sidecar para APIs externas

```bash

---# Ambiente padrão

python scripts/helm_render.py -t templates -v templates/values.yaml -o manifests/default

## 🚀 Deployment Rápido

# Staging

### Pré-requisitospython scripts/helm_render.py -t templates -v templates/values-staging.yaml -o manifests/staging



- Cluster AKS com Istio Managed Add-on habilitado# Produção

- `kubectl` configurado para o clusterpython scripts/helm_render.py -t templates -v templates/values-production.yaml -o manifests/production

- Azure CLI autenticado (para TLS Key Vault sync)```

- Python 3.9+ com dependências instaladas

### 2. **Aplicar no Cluster**

### Passos Básicos

```bash

```bash# Aplicar manifests renderizados

# 1. Criar namespace com injeção Istiokubectl apply -f manifests/staging/

kubectl create namespace pets

kubectl label namespace pets istio.io/rev=asm-1-23# Verificar deployment

kubectl get gateway,virtualservice,destinationrule,peerauthentication -n pets-staging

# 2. Aplicar todos os manifestos demo```

kubectl apply -f manifests/demo/

## 📋 **Estrutura de Valores**

# 3. Verificar recursos

kubectl get gateway,virtualservice,destinationrule,peerauthentication -n pets### **values.yaml (Base)**

kubectl get requestauthentication,authorizationpolicy,serviceaccounts -n petsConfigurações padrão para desenvolvimento e testes locais.

kubectl get serviceentry,sidecar,telemetry -n pets

```### **values-staging.yaml**

- Namespace: `pets-staging`

---- mTLS: `PERMISSIVE`

- Routing: 90% primary, 10% canary

## 🔐 Segurança- Domínio: `pets-staging.contoso.com`



### mTLS STRICT### **values-production.yaml**

- Namespace: `pets-prod`

**Manifest**: `manifests/demo/peerauthentication.yaml`- mTLS: `STRICT`

- Routing: 95% primary, 5% canary

```yaml- Domínio: `pets.contoso.com`

# Força comunicação criptografada entre todos os serviços

spec:## 🔧 **Customização**

  mtls:

    mode: STRICT### **Adicionando Novos Templates**

```

1. Criar arquivo `.yaml` em `/templates`

**Validação**:2. Usar sintaxe Helm: `{{ .Values.app.name }}`

```bash3. Testar renderização:

# Verificar mTLS habilitado   ```bash

kubectl exec -n pets deploy/pets-primary -c istio-proxy -- \   python scripts/helm_render.py -t templates -v templates/values.yaml -o test-output

  curl -s http://localhost:15000/config_dump | grep -o '"mode":".*"'   ```

```

### **Criando Novos Ambientes**

### Autenticação JWT (Azure AD)

1. Copiar `values.yaml` → `values-AMBIENTE.yaml`

**Manifest**: `manifests/demo/requestauthentication.yaml`2. Modificar configurações específicas

3. Renderizar e testar

```yaml

# Valida tokens JWT do Azure AD## 🎨 **Exemplos de Uso**

spec:

  jwtRules:### **Template com Condicional**

  - issuer: "https://sts.windows.net/<TENANT_ID>/"```yaml

    jwksUri: "https://login.microsoftonline.com/<TENANT_ID>/discovery/v2.0/keys"{{- if .Values.security.mtls.enabled }}

    audiences:spec:

    - "api://pets-demo"  mtls:

    outputClaimToHeaders:    mode: {{ .Values.security.mtls.mode }}

    - header: "x-user-group"{{- end }}

      claim: "groups"```

```

### **Template com Loop**

**Teste**:```yaml

```bashhosts:

# Requisição com JWT válido{{- range .Values.network.gateway.hosts }}

TOKEN="<SEU_JWT_TOKEN>"- {{ . }}

curl -H "Authorization: Bearer $TOKEN" https://pets.contoso.com/api/pets{{- end }}

```

# Requisição sem token (falhará se AuthorizationPolicy estiver aplicada)

curl https://pets.contoso.com/api/pets  # 403 Forbidden### **Template com Função**

``````yaml

metadata:

### Autorização RBAC  name: {{ .Values.app.name }}-{{ .Values.metadata.labels.environment }}

```

**Manifest**: `manifests/demo/authorizationpolicy.yaml`

## 🔍 **Debugging**

```yaml

# Regra 1: JWT-based (grupos do Azure AD)### **Verificar Sintaxe**

rules:```bash

- from:python scripts/helm_render.py -t templates -v templates/values.yaml -o /tmp/debug

  - source:```

      requestPrincipals: ["*"]

  when:### **Validar YAML**

  - key: request.auth.claims[groups]```bash

    values: ["alpha-users", "beta-users", "ops-team"]yamllint templates/

kubectl apply --dry-run=client -f manifests/staging/

# Regra 2: ServiceAccount-based```

rules:

- from:### **Testar no Cluster**

  - source:```bash

      principals:kubectl apply -f manifests/staging/

      - "cluster.local/ns/pets/sa/pets-primary"kubectl describe gateway -n pets-staging

      - "cluster.local/ns/pets/sa/pets-canary"kubectl describe virtualservice -n pets-staging

      # ... (6 ServiceAccounts)```

```

## 📚 **Recursos Avançados**

**Validação**:

```bash- ✅ Sintaxe Helm completa

# Listar ServiceAccounts- ✅ Condicionais e loops

kubectl get serviceaccounts -n pets- ✅ Múltiplos ambientes

- ✅ Validação automática

# Verificar política aplicada- ✅ CI/CD integrado

kubectl describe authorizationpolicy pets-access-control -n pets- ✅ Zero dependência do Helm
```

---

## 🔄 Gerenciamento de Tráfego Unificado

### Arquitetura de Roteamento

O `VirtualService` unifica **3 estratégias** em um único recurso:

```yaml
# manifests/demo/virtualservice.yaml
http:
  # 1. A/B Testing (header-based)
  - name: ab-testing-variant-a
    match:
    - headers:
        X-User-Group:
          exact: "alpha"
    route:
    - destination:
        host: pets.pets.svc.cluster.local
        subset: variant-a

  - name: ab-testing-variant-b
    match:
    - headers:
        X-User-Group:
          exact: "beta"
    route:
    - destination:
        host: pets.pets.svc.cluster.local
        subset: variant-b

  # 2. Blue-Green (path-based)
  - name: blue-green-deployment
    match:
    - uri:
        prefix: "/bg"
    rewrite:
      uri: "/"
    route:
    - destination:
        host: pets.pets.svc.cluster.local
        subset: blue
      weight: 50
    - destination:
        host: pets.pets.svc.cluster.local
        subset: green
      weight: 50

  # 3. Canary (default - weight-based)
  - name: canary-deployment
    route:
    - destination:
        host: pets.pets.svc.cluster.local
        subset: primary
      weight: 90
    - destination:
        host: pets.pets.svc.cluster.local
        subset: canary
      weight: 10
```

### 1. Canary Deployment (90/10)

**Objetivo**: Liberar nova versão para 10% do tráfego.

**Teste**:
```bash
# Gerar 100 requisições e contar distribuição
for i in {1..100}; do
  curl -s https://pets.contoso.com/api/pets | jq -r '.version'
done | sort | uniq -c

# Esperado:
# 90 v1.0.0  (primary)
# 10 v1.1.0  (canary)
```

**Ajustar Pesos**:
```bash
# Aumentar canary para 50%
kubectl patch virtualservice pets-routes -n pets --type merge -p '
{
  "spec": {
    "http": [
      {
        "name": "canary-deployment",
        "route": [
          {"destination": {"host": "pets.pets.svc.cluster.local", "subset": "primary"}, "weight": 50},
          {"destination": {"host": "pets.pets.svc.cluster.local", "subset": "canary"}, "weight": 50}
        ]
      }
    ]
  }
}'
```

### 2. Blue-Green Deployment

**Objetivo**: Alternar entre duas versões estáveis via path.

**Teste**:
```bash
# Acessar via path /bg (50% blue, 50% green)
curl https://pets.contoso.com/bg/api/pets

# Alternar 100% para green
kubectl patch virtualservice pets-routes -n pets --type merge -p '
{
  "spec": {
    "http": [
      {
        "name": "blue-green-deployment",
        "match": [{"uri": {"prefix": "/bg"}}],
        "rewrite": {"uri": "/"},
        "route": [
          {"destination": {"host": "pets.pets.svc.cluster.local", "subset": "green"}, "weight": 100}
        ]
      }
    ]
  }
}'
```

### 3. A/B Testing (Header-Based)

**Objetivo**: Rotear usuários alpha/beta para variantes específicas.

**Teste**:
```bash
# Usuários alpha → variant-a
curl -H "X-User-Group: alpha" https://pets.contoso.com/api/pets

# Usuários beta → variant-b
curl -H "X-User-Group: beta" https://pets.contoso.com/api/pets

# Usuários sem header → canary default (90/10)
curl https://pets.contoso.com/api/pets
```

### Traffic Policies (DestinationRule)

**Manifest**: `manifests/demo/destinationrule.yaml`

```yaml
trafficPolicy:
  loadBalancer:
    simple: LEAST_REQUEST  # Distribui para pods com menos carga
  connectionPool:
    tcp:
      maxConnections: 100
    http:
      http1MaxPendingRequests: 50
      http2MaxRequests: 100
  outlierDetection:
    consecutiveErrors: 3
    interval: 30s
    baseEjectionTime: 30s
```

**Benefícios**:
- **Load Balancing**: Distribui carga eficientemente
- **Connection Pooling**: Limita conexões por destino
- **Circuit Breaking**: Remove pods com falhas temporariamente

---

## 📊 Observabilidade

### Telemetria e Tracing

**Manifest**: `manifests/demo/telemetry.yaml`

```yaml
spec:
  tracing:
  - providers:
    - name: "azure-monitor"
    randomSamplingPercentage: 10.0  # 10% das requisições
    customTags:
      user-group:
        header:
          name: "x-user-group"
      release-track:
        header:
          name: "x-release-track"
```

**Acesso ao Tracing**:
```bash
# Port-forward para Zipkin (se instalado)
kubectl port-forward -n aks-istio-system svc/zipkin 9411:9411

# Abrir http://localhost:9411 no navegador
```

### Métricas Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward -n aks-istio-system svc/prometheus 9090:9090

# Queries úteis:
# - istio_requests_total
# - istio_request_duration_milliseconds
# - istio_tcp_connections_opened_total
```

### Kiali (Visualização da Mesh)

```bash
# Port-forward Kiali
kubectl port-forward -n aks-istio-system svc/kiali 20001:20001

# Abrir http://localhost:20001
# Ver graph de tráfego, métricas por serviço, validação de configuração
```

---

## 🌐 Controle de Egress

### ServiceEntry para APIs Externas

**Manifest**: `manifests/demo/serviceentry.yaml`

```yaml
# Permite acesso a api.catfacts.ninja
spec:
  hosts:
  - api.catfacts.ninja
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

**Teste**:
```bash
# De dentro de um pod
kubectl exec -n pets deploy/pets-primary -c pets -- \
  curl -s https://api.catfacts.ninja/fact
```

### Sidecar para Egress Restrito

**Manifest**: `manifests/demo/sidecar.yaml`

```yaml
# Limita egress apenas para destinos autorizados
spec:
  workloadSelector:
    labels:
      app: pets
  egress:
  - hosts:
    - "./*"                    # Próprio namespace
    - "aks-istio-system/*"     # Istio control plane
    - "*/api.catfacts.ninja"   # API externa autorizada
```

**Validação**:
```bash
# Acesso permitido
kubectl exec -n pets deploy/pets-primary -c pets -- \
  curl -s https://api.catfacts.ninja/fact  # ✅ OK

# Acesso bloqueado
kubectl exec -n pets deploy/pets-primary -c pets -- \
  curl -s https://google.com  # ❌ Blocked by Sidecar
```

---

## 🔧 Comandos Úteis

### Validação de Configuração

```bash
# Verificar todos os recursos Istio
kubectl get gateway,vs,dr,pa,ra,ap,sa,se,sidecar,telemetry -n pets

# Analisar configuração com istioctl
istioctl analyze -n pets

# Verificar proxy config de um pod
istioctl proxy-config routes deploy/pets-primary -n pets
istioctl proxy-config clusters deploy/pets-primary -n pets
istioctl proxy-config listeners deploy/pets-primary -n pets
```

### Logs e Debugging

```bash
# Logs do Ingress Gateway
kubectl logs -n aks-istio-ingress -l app=aks-istio-ingressgateway-external --tail=100

# Logs do sidecar proxy
kubectl logs -n pets deploy/pets-primary -c istio-proxy --tail=50

# Describe de recursos
kubectl describe virtualservice pets-routes -n pets
kubectl describe authorizationpolicy pets-access-control -n pets
```

### Teste de Performance

```bash
# Instalar fortio
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/httpbin/sample-client/fortio-deploy.yaml

# Teste de carga
kubectl exec -n default deploy/fortio -- \
  fortio load -c 10 -qps 100 -t 60s https://pets.contoso.com/api/pets
```

---

## 📚 Próximos Passos

1. **Implementar Workloads Reais**: Criar Deployments e Services para as 6 variantes
2. **Adicionar Rate Limiting**: Usar EnvoyFilter para limitar requisições por IP
3. **Configurar WAF**: Integrar Azure Application Gateway com WAF
4. **Multi-Cluster**: Expandir para federated Istio mesh
5. **Ambient Mesh**: Testar sidecar-less architecture (quando disponível)

---

## 🤝 Troubleshooting

### Problema: Tráfego não roteia corretamente

```bash
# Verificar se VirtualService está aplicado
kubectl get vs pets-routes -n pets -o yaml

# Verificar se DestinationRule tem os subsets corretos
kubectl get dr pets-subsets -n pets -o yaml

# Analisar rotas do proxy
istioctl proxy-config routes deploy/pets-primary -n pets
```

### Problema: JWT validation falha

```bash
# Verificar RequestAuthentication
kubectl describe ra pets-jwt-auth -n pets

# Testar com token válido
TOKEN="eyJ..." # Seu JWT
curl -H "Authorization: Bearer $TOKEN" https://pets.contoso.com/api/pets -v
```

### Problema: mTLS não funciona

```bash
# Verificar PeerAuthentication
kubectl get pa -n pets

# Verificar certificados do proxy
istioctl proxy-config secret deploy/pets-primary -n pets
```

---

**🎉 Com estes recursos, você tem um laboratório completo para explorar todas as capacidades do Istio Managed Add-on no AKS!**
