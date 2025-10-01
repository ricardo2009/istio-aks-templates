# 🚀 Tutorial Executivo - Istio Demo Lab Completo

> **Laboratório unificado com todas as features do Istio Managed Add-on no AKS**: Canary + Blue-Green + A/B Testing + mTLS + JWT + RBAC + Telemetry + Egress Control - **tudo funcionando simultaneamente**.

---

## 📋 O QUE ESTÁ IMPLEMENTADO

### ✅ Gerenciamento de Tráfego (3 estratégias simultâneas)
- [x] **Canary Deployment**: 90% primary / 10% canary (rota padrão)
- [x] **Blue-Green**: Path `/bg/*` → 100% green (ajustável via patch)
- [x] **A/B Testing**: Header `X-User-Group: alpha` → variant-a, `beta` → variant-b
- [x] **Traffic Policies**: LEAST_REQUEST load balancing, connection pooling, outlier detection
- [x] **Resiliency**: Retries (3x), timeouts (5s), circuit breaking

### ✅ Segurança
- [x] **mTLS STRICT**: Comunicação criptografada obrigatória entre serviços
- [x] **JWT Authentication**: Validação de tokens Azure AD (issuer + jwksUri + audience)
- [x] **Authorization RBAC**: Políticas baseadas em JWT claims (grupos) e ServiceAccounts
- [x] **6 ServiceAccounts**: Identidade separada por deployment (primary, canary, blue, green, variant-a, variant-b)

### ✅ Observabilidade
- [x] **Telemetry Resource**: Tracing config com Zipkin provider
- [x] **Custom Tags**: `user-group` e `release-track` extraídos de headers HTTP
- [x] **Sampling**: 10% das requisições para tracing
- [x] **Labels Padronizados**: app, version, deployment-strategy em todos os recursos

### ✅ Controle de Egress
- [x] **ServiceEntry**: Permite acesso HTTPS a `api.catfacts.ninja`
- [x] **Sidecar**: Restringe egress apenas para: namespace `pets`, `aks-istio-system`, APIs autorizadas

### ✅ Gateways
- [x] **Gateway Externo**: HTTPS (porta 443) com TLS (credentialName: `pets-gateway-tls`)
- [x] **Gateway Interno**: HTTP (porta 80) para workloads não-públicos

### ✅ Workloads (6 Deployments)
- [x] `pets-primary` (v1, 2 réplicas)
- [x] `pets-canary` (v2, 1 réplica)
- [x] `pets-blue` (v3, 2 réplicas)
- [x] `pets-green` (v4, 2 réplicas)
- [x] `pets-variant-a` (variant-a, 1 réplica)
- [x] `pets-variant-b` (variant-b, 1 réplica)

---

## 🚀 DEPLOY RÁPIDO (5 MINUTOS)

### Pré-requisitos

```powershell
# 1. Cluster AKS com Istio Managed Add-on habilitado
# 2. kubectl configurado
kubectl config use-context <SEU_CLUSTER>

# 3. Validar Istio instalado
kubectl get pods -n aks-istio-system
# Esperado: istiod-*, ztunnel-*, etc.
```

### Passo 1: Criar Namespace com Injeção Istio

```powershell
kubectl create namespace pets
kubectl label namespace pets istio.io/rev=asm-1-23
```

### Passo 2: Aplicar Todos os Manifestos

```powershell
# Aplicar em ordem
kubectl apply -f manifests/demo/serviceaccounts.yaml
kubectl apply -f manifests/demo/workloads.yaml
kubectl apply -f manifests/demo/gateway.yaml
kubectl apply -f manifests/demo/gateway-internal.yaml
kubectl apply -f manifests/demo/destinationrule.yaml
kubectl apply -f manifests/demo/virtualservice.yaml
kubectl apply -f manifests/demo/virtualservice-internal.yaml
kubectl apply -f manifests/demo/peerauthentication.yaml
kubectl apply -f manifests/demo/requestauthentication.yaml
kubectl apply -f manifests/demo/authorizationpolicy.yaml
kubectl apply -f manifests/demo/serviceentry.yaml
kubectl apply -f manifests/demo/sidecar.yaml
kubectl apply -f manifests/demo/telemetry.yaml
```

**OU aplicar tudo de uma vez**:
```powershell
kubectl apply -f manifests/demo/
```

### Passo 3: Aguardar Pods Prontos

```powershell
kubectl wait --for=condition=ready pod -l app=pets -n pets --timeout=300s
```

---

## ✅ VALIDAÇÃO COMPLETA

### 1. Verificar Recursos Istio Criados

```powershell
kubectl get gateway,virtualservice,destinationrule,peerauthentication,requestauthentication,authorizationpolicy,serviceaccounts,serviceentry,sidecar,telemetry -n pets
```

**Esperado**: 2 Gateways, 2 VirtualServices, 1 DestinationRule, 1 PeerAuth, 1 RequestAuth, 1 AuthzPolicy, 6 ServiceAccounts, 1 ServiceEntry, 1 Sidecar, 1 Telemetry

### 2. Verificar Pods com Sidecar Injetado

```powershell
kubectl get pods -n pets -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

**Esperado**: Cada pod deve ter 2 containers: `pets` + `istio-proxy`

### 3. Obter IP do Gateway

```powershell
$GATEWAY_IP = kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Write-Host "Gateway IP: $GATEWAY_IP"
```

---

## 🧪 TESTES FUNCIONAIS

### Teste 1: Canary Routing (90/10)

```powershell
# Gerar 100 requisições e ver distribuição
$results = @{}
1..100 | ForEach-Object {
    $response = Invoke-WebRequest -Uri "http://$GATEWAY_IP/headers" -Headers @{"Host"="pets.contoso.com"} -UseBasicParsing
    $version = ($response.Content | ConvertFrom-Json).headers.'X-Envoy-Decorator-Operation'
    if ($results.ContainsKey($version)) {
        $results[$version]++
    } else {
        $results[$version] = 1
    }
}
$results | Format-Table
```

**Esperado**: ~90 requisições para v1 (primary), ~10 para v2 (canary)

### Teste 2: Blue-Green via Path

```powershell
# Requisição para /bg (deve ir para green)
Invoke-WebRequest -Uri "http://$GATEWAY_IP/bg/headers" -Headers @{"Host"="pets.contoso.com"} -UseBasicParsing | 
    Select-Object -ExpandProperty Content | ConvertFrom-Json
```

**Esperado**: Headers mostrando `X-Envoy-Decorator-Operation: pets.pets.svc.cluster.local:80/green`

### Teste 3: A/B Testing via Header

```powershell
# Usuários alpha → variant-a
Invoke-WebRequest -Uri "http://$GATEWAY_IP/headers" `
    -Headers @{"Host"="pets.contoso.com"; "X-User-Group"="alpha"} `
    -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json

# Usuários beta → variant-b
Invoke-WebRequest -Uri "http://$GATEWAY_IP/headers" `
    -Headers @{"Host"="pets.contoso.com"; "X-User-Group"="beta"} `
    -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
```

**Esperado**: Rotas diferentes baseadas no header `X-User-Group`

### Teste 4: mTLS STRICT

```powershell
# Verificar modo mTLS no proxy
kubectl exec -n pets deploy/pets-primary -c istio-proxy -- curl -s http://localhost:15000/config_dump | Select-String "mode"
```

**Esperado**: `"mode":"STRICT"`

### Teste 5: Egress Permitido

```powershell
# Testar acesso a API externa autorizada
kubectl exec -n pets deploy/pets-primary -c pets -- curl -s https://api.catfacts.ninja/fact
```

**Esperado**: JSON com cat fact

### Teste 6: Egress Bloqueado

```powershell
# Testar acesso bloqueado (deve falhar)
kubectl exec -n pets deploy/pets-primary -c pets -- curl -s https://google.com --max-time 5
```

**Esperado**: Timeout ou connection refused (bloqueado pelo Sidecar)

---

## 📊 OBSERVABILIDADE

### Prometheus (Métricas)

```powershell
kubectl port-forward -n aks-istio-system svc/prometheus 9090:9090
# Abrir http://localhost:9090
# Queries úteis:
# - istio_requests_total{destination_service="pets.pets.svc.cluster.local"}
# - histogram_quantile(0.95, istio_request_duration_milliseconds_bucket)
```

### Kiali (Visualização da Mesh)

```powershell
kubectl port-forward -n aks-istio-system svc/kiali 20001:20001
# Abrir http://localhost:20001
# Ver Graph → namespace pets
# Validar: traffic split 90/10, mTLS locks, service topology
```

### Zipkin (Tracing)

```powershell
kubectl port-forward -n aks-istio-system svc/zipkin 9411:9411
# Abrir http://localhost:9411
# Filtrar por serviceName="pets.pets"
# Verificar custom tags: user-group, release-track
```

---

## 🔧 OPERAÇÕES AVANÇADAS

### Ajustar Split Canary para 50/50

```powershell
kubectl patch virtualservice pets -n pets --type merge -p '
{
  "spec": {
    "http": [
      {
        "name": "canary-default",
        "route": [
          {"destination": {"host": "pets.pets.svc.cluster.local", "subset": "canary"}, "weight": 50},
          {"destination": {"host": "pets.pets.svc.cluster.local", "subset": "primary"}, "weight": 50}
        ]
      }
    ]
  }
}'
```

### Alternar Blue-Green para 100% Blue

```powershell
kubectl patch virtualservice pets -n pets --type merge -p '
{
  "spec": {
    "http": [
      {
        "name": "blue-green",
        "match": [{"uri": {"prefix": "/bg"}}],
        "rewrite": {"uri": "/"},
        "route": [
          {"destination": {"host": "pets.pets.svc.cluster.local", "subset": "blue"}, "weight": 100},
          {"destination": {"host": "pets.pets.svc.cluster.local", "subset": "green"}, "weight": 0}
        ]
      }
    ]
  }
}'
```

### Simular Failover (Circuit Breaking)

```powershell
# Gerar tráfego que ultrapassa connection pool (1000 req)
kubectl run fortio --image=fortio/fortio --restart=Never -- load -c 200 -qps 0 -t 30s http://pets.pets.svc.cluster.local/headers

# Verificar métricas de circuit breaking
kubectl exec -n pets deploy/pets-primary -c istio-proxy -- curl -s http://localhost:15000/stats/prometheus | Select-String "upstream_rq_pending_overflow"
```

---

## 🐛 TROUBLESHOOTING

### Problema: Pods não têm sidecar

```powershell
# Verificar label do namespace
kubectl get namespace pets --show-labels
# Deve ter: istio.io/rev=asm-1-23

# Recriar pods para forçar injeção
kubectl rollout restart deployment -n pets
```

### Problema: Gateway não responde

```powershell
# Verificar se Gateway existe
kubectl get gateway pets-gateway -n pets

# Verificar logs do Ingress Gateway
kubectl logs -n aks-istio-ingress -l app=aks-istio-ingressgateway-external --tail=50

# Verificar se VirtualService referencia Gateway correto
kubectl get virtualservice pets -n pets -o yaml | Select-String "gateway"
```

### Problema: Tráfego não roteia corretamente

```powershell
# Analisar rotas do proxy
istioctl proxy-config routes deploy/pets-primary -n pets

# Verificar DestinationRule subsets
kubectl get destinationrule pets -n pets -o yaml

# Verificar labels dos pods
kubectl get pods -n pets --show-labels
```

### Problema: mTLS falha

```powershell
# Verificar PeerAuthentication
kubectl get peerauthentication -n pets -o yaml

# Verificar certificados no proxy
istioctl proxy-config secret deploy/pets-primary -n pets
```

---

## 📈 TESTE DE PERFORMANCE

### Instalar Fortio

```powershell
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.23/samples/httpbin/sample-client/fortio-deploy.yaml
```

### Teste de Carga (100 QPS por 60s)

```powershell
kubectl exec -n default deploy/fortio -- fortio load -c 10 -qps 100 -t 60s http://pets.pets.svc.cluster.local/headers
```

**Métricas Alvo**:
- P50 Latency: < 10ms
- P99 Latency: < 50ms
- Success Rate: > 99.9%

---

## ✅ CHECKLIST DE VALIDAÇÃO FINAL

Execute este checklist para confirmar que tudo está funcionando:

```powershell
# 1. Recursos Istio criados
kubectl get gateway,vs,dr,pa,ra,ap,sa,se,sidecar,telemetry -n pets | Measure-Object -Line
# Esperado: 14 recursos

# 2. Pods rodando com sidecar
kubectl get pods -n pets | Select-String "2/2.*Running" | Measure-Object -Line
# Esperado: 9 pods (6 deployments + possíveis extras)

# 3. Gateway responde
$GATEWAY_IP = kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Invoke-WebRequest -Uri "http://$GATEWAY_IP/headers" -Headers @{"Host"="pets.contoso.com"} -UseBasicParsing
# Esperado: 200 OK

# 4. Canary 90/10
# (Execute o teste 1 acima)

# 5. Blue-Green funciona
# (Execute o teste 2 acima)

# 6. A/B Testing funciona
# (Execute o teste 3 acima)

# 7. mTLS habilitado
# (Execute o teste 4 acima)

# 8. Egress permitido
# (Execute o teste 5 acima)

# 9. Egress bloqueado
# (Execute o teste 6 acima)

# 10. Telemetria funcionando
kubectl port-forward -n aks-istio-system svc/prometheus 9090:9090
# Abrir http://localhost:9090 e verificar métricas istio_*
```

---

## 🎓 O QUE FOI VALIDADO

### ✅ Implementado e Testado

1. **Gerenciamento de Tráfego**
   - ✅ Canary deployment com weight-based routing
   - ✅ Blue-Green deployment com path-based routing
   - ✅ A/B testing com header-based routing
   - ✅ Load balancing (LEAST_REQUEST)
   - ✅ Connection pooling
   - ✅ Circuit breaking (outlier detection)
   - ✅ Retries e timeouts

2. **Segurança**
   - ✅ mTLS STRICT global
   - ✅ JWT authentication (RequestAuthentication)
   - ✅ RBAC (AuthorizationPolicy com JWT claims + ServiceAccounts)
   - ✅ 6 ServiceAccounts isoladas

3. **Observabilidade**
   - ✅ Telemetry resource configurada
   - ✅ Tracing com Zipkin
   - ✅ Custom tags em headers
   - ✅ Sampling 10%
   - ✅ Integração com Prometheus
   - ✅ Visualização com Kiali

4. **Controle de Egress**
   - ✅ ServiceEntry para APIs externas (api.catfacts.ninja)
   - ✅ Sidecar para restringir egress não autorizado

### ⚠️ Limitações do Istio Gerenciado (Não Aplicável)

- ❌ **Customização do Control Plane**: Não é possível modificar configurações do `istiod` gerenciado
- ❌ **Istio Operator**: Não disponível, configuração via Azure Portal/CLI
- ❌ **Multi-Primary Mesh**: Não suportado nativamente no add-on gerenciado
- ❌ **Custom Envoy Filters**: Suporte limitado, depende de Azure roadmap

### 📝 Não Implementado (Fora do Escopo Demo)

- Certificate Management via Azure Key Vault (requer integração adicional)
- Azure AD Workload Identity (requer configuração Azure)
- Multi-cluster mesh
- Ambient mesh (sidecar-less, ainda experimental)

---

## 📚 PRÓXIMOS PASSOS

1. **Produtizar**:
   - Adicionar liveness/readiness probes nos Deployments
   - Configurar HPA (Horizontal Pod Autoscaler)
   - Implementar PodDisruptionBudget

2. **CI/CD**:
   - Usar workflow GitHub Actions (`.github/workflows/deploy.yml`)
   - Adicionar testes automatizados
   - Implementar GitOps com Flux/ArgoCD

3. **Observabilidade Avançada**:
   - Integrar com Azure Monitor
   - Configurar Application Insights
   - Criar dashboards Grafana customizados

4. **Segurança Adicional**:
   - Integrar com Azure Key Vault para TLS
   - Implementar rate limiting (EnvoyFilter)
   - Adicionar WAF (Azure Application Gateway)

---

**🎉 Laboratório completo! Todas as features principais do Istio Managed Add-on estão implementadas e testadas.**
