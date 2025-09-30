# 🧪 Guia de Validação Completa - Istio AKS Templates

Este guia fornece instruções passo a passo para validar todos os componentes da solução Istio no AKS.

## 📋 Pré-requisitos

### 🔧 Ferramentas Necessárias
- `kubectl` configurado para o cluster AKS
- `az` CLI autenticado
- Acesso ao cluster AKS com Istio gerenciado habilitado
- Permissões de Contributor na subscription

### 🏗️ Infraestrutura
- Cluster AKS com Istio add-on habilitado
- Azure Monitor for Prometheus configurado
- Azure Managed Grafana (opcional)

## 🚀 Validação Passo a Passo

### 1. 🔍 Validação Offline (Sem Cluster)

Execute a validação completa dos templates sem necessidade de cluster:

```bash
# Clonar o repositório
git clone https://github.com/ricardo2009/istio-aks-templates.git
cd istio-aks-templates

# Executar validação completa
./scripts/validate-all.sh
```

**Resultado Esperado:**
- ✅ Todos os templates renderizados com sucesso
- ✅ YAMLs válidos gerados
- ✅ 32 arquivos de configuração criados
- ✅ Relatório de validação em `validation-output/validation-report.md`

### 2. 🔗 Validação de Conectividade

Verifique a conectividade com o cluster:

```bash
# Verificar conectividade
kubectl cluster-info

# Verificar Istio gerenciado
kubectl get namespace aks-istio-system
kubectl get pods -n aks-istio-system

# Verificar se há aplicações existentes no namespace pets
kubectl get all -n pets 2>/dev/null || echo "Namespace pets não existe"
```

**Resultado Esperado:**
- ✅ Cluster acessível
- ✅ Istio control plane rodando
- ✅ Pods do Istio em estado Running

### 3. 🚀 Deploy Manual Completo

Execute o deploy manual da aplicação de demonstração:

```bash
# Executar deploy interativo
./scripts/deploy-manual.sh

# Ou seguir os passos individuais:

# 1. Criar namespace
kubectl apply -f demo-app/k8s-manifests/namespace.yaml

# 2. Aplicar políticas de segurança
./scripts/render.sh -f templates/security/namespace-security-policy.yaml -s ecommerce -n ecommerce-demo
kubectl apply -f manifests/ecommerce/namespace-security-policy.yaml

# 3. Deploy da aplicação
kubectl apply -f demo-app/k8s-manifests/frontend.yaml
kubectl apply -f demo-app/k8s-manifests/api-gateway.yaml
kubectl apply -f demo-app/k8s-manifests/backend-services.yaml

# 4. Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod --all -n ecommerce-demo --timeout=300s

# 5. Configurar Istio Gateway
./scripts/render.sh -f templates/base/advanced-gateway.yaml -s frontend -n ecommerce-demo -h ecommerce-demo.aks-labs.com --tls-secret ecommerce-tls
kubectl apply -f manifests/frontend/advanced-gateway.yaml

# 6. Configurar VirtualServices e DestinationRules
services=("frontend" "api-gateway" "user-service" "order-service" "payment-service" "notification-service")
for service in "${services[@]}"; do
  ./scripts/render.sh -f templates/traffic-management/advanced-virtual-service.yaml -s "$service" -n ecommerce-demo -h ecommerce-demo.aks-labs.com
  kubectl apply -f "manifests/$service/advanced-virtual-service.yaml"
  
  ./scripts/render.sh -f templates/traffic-management/advanced-destination-rule.yaml -s "$service" -n ecommerce-demo
  kubectl apply -f "manifests/$service/advanced-destination-rule.yaml"
done

# 7. Aplicar configurações de segurança
for service in "${services[@]}"; do
  ./scripts/render.sh -f templates/security/peer-authentication.yaml -s "$service" -n ecommerce-demo
  kubectl apply -f "manifests/$service/peer-authentication.yaml"
  
  ./scripts/render.sh -f templates/security/authorization-policy.yaml -s "$service" -n ecommerce-demo --caller-sa api-gateway --method GET --path "/"
  kubectl apply -f "manifests/$service/authorization-policy.yaml"
done

# 8. Configurar observabilidade
for service in "${services[@]}"; do
  ./scripts/render.sh -f templates/observability/advanced-telemetry.yaml -s "$service" -n ecommerce-demo
  kubectl apply -f "manifests/$service/advanced-telemetry.yaml"
done
```

**Resultado Esperado:**
- ✅ 6 serviços deployados e rodando
- ✅ Istio Gateway configurado
- ✅ mTLS STRICT habilitado
- ✅ Circuit breakers configurados
- ✅ Políticas de autorização aplicadas
- ✅ Telemetria configurada

### 4. 🔍 Verificação do Deploy

Verifique se tudo está funcionando corretamente:

```bash
# Status geral
kubectl get all -n ecommerce-demo

# Configurações Istio
kubectl get gateway,virtualservice,destinationrule -n ecommerce-demo

# Políticas de segurança
kubectl get peerauthentication,authorizationpolicy -n ecommerce-demo

# Telemetria
kubectl get telemetry -n ecommerce-demo

# Logs dos pods
kubectl logs -l app=frontend -n ecommerce-demo --tail=10
kubectl logs -l app=payment-service -n ecommerce-demo --tail=10

# Verificar injeção do sidecar
kubectl get pods -n ecommerce-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

**Resultado Esperado:**
- ✅ Todos os pods com 2/2 containers (app + istio-proxy)
- ✅ Configurações Istio aplicadas
- ✅ Logs sem erros críticos

### 5. 🌐 Teste de Conectividade

Obtenha o IP externo e teste o acesso:

```bash
# Obter IP externo
EXTERNAL_IP=$(kubectl get service aks-istio-ingressgateway-external -n aks-istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "IP Externo: $EXTERNAL_IP"

# Testar conectividade HTTP
curl -v http://$EXTERNAL_IP/ -H "Host: ecommerce-demo.aks-labs.com"

# Testar conectividade HTTPS (se certificado configurado)
curl -v https://$EXTERNAL_IP/ -H "Host: ecommerce-demo.aks-labs.com" -k

# Testar APIs específicas
curl -v http://$EXTERNAL_IP/api/users/ -H "Host: ecommerce-demo.aks-labs.com"
curl -v http://$EXTERNAL_IP/api/orders/ -H "Host: ecommerce-demo.aks-labs.com"
```

**Resultado Esperado:**
- ✅ Resposta HTTP 200 do frontend
- ✅ APIs respondendo corretamente
- ✅ Headers Istio presentes nas respostas

### 6. 🔒 Teste de Segurança

Valide as configurações de segurança:

```bash
# Testar mTLS entre serviços
kubectl exec -n ecommerce-demo deployment/frontend -c istio-proxy -- curl -v http://api-gateway.ecommerce-demo.svc.cluster.local:8080/health

# Verificar certificados mTLS
kubectl exec -n ecommerce-demo deployment/frontend -c istio-proxy -- openssl s_client -connect api-gateway.ecommerce-demo.svc.cluster.local:8080 -cert /etc/ssl/certs/cert-chain.pem -key /etc/ssl/private/key.pem

# Testar políticas de autorização (deve falhar)
kubectl run test-pod --image=curlimages/curl -n ecommerce-demo --rm -it -- curl -v http://user-service.ecommerce-demo.svc.cluster.local:8080/

# Verificar rate limiting (se configurado)
for i in {1..20}; do
  curl -s -o /dev/null -w "%{http_code}\n" http://$EXTERNAL_IP/ -H "Host: ecommerce-demo.aks-labs.com"
done
```

**Resultado Esperado:**
- ✅ Comunicação mTLS funcionando
- ✅ Políticas de autorização bloqueando acesso não autorizado
- ✅ Rate limiting ativo (se configurado)

### 7. ⚡ Teste de Resiliência

Teste os circuit breakers e retry policies:

```bash
# Simular falha no payment service
kubectl patch deployment payment-service -n ecommerce-demo -p '{"spec":{"replicas":0}}'

# Testar circuit breaker
for i in {1..10}; do
  curl -s -o /dev/null -w "%{http_code} %{time_total}s\n" http://$EXTERNAL_IP/api/payments/ -H "Host: ecommerce-demo.aks-labs.com"
  sleep 1
done

# Restaurar payment service
kubectl patch deployment payment-service -n ecommerce-demo -p '{"spec":{"replicas":2}}'

# Aguardar recovery
kubectl wait --for=condition=ready pod -l app=payment-service -n ecommerce-demo --timeout=120s

# Testar recovery
curl -v http://$EXTERNAL_IP/api/payments/ -H "Host: ecommerce-demo.aks-labs.com"
```

**Resultado Esperado:**
- ✅ Circuit breaker abrindo após falhas
- ✅ Respostas rápidas (fail fast) quando circuit breaker aberto
- ✅ Recovery automático após serviço voltar

### 8. 📊 Teste de Observabilidade

Verifique se as métricas estão sendo coletadas:

```bash
# Verificar métricas do Istio
kubectl exec -n ecommerce-demo deployment/frontend -c istio-proxy -- curl -s localhost:15000/stats/prometheus | grep istio_requests_total

# Verificar telemetria
kubectl get telemetry -n ecommerce-demo -o yaml

# Gerar tráfego para métricas
for i in {1..50}; do
  curl -s http://$EXTERNAL_IP/ -H "Host: ecommerce-demo.aks-labs.com" > /dev/null
  curl -s http://$EXTERNAL_IP/api/users/ -H "Host: ecommerce-demo.aks-labs.com" > /dev/null
  curl -s http://$EXTERNAL_IP/api/orders/ -H "Host: ecommerce-demo.aks-labs.com" > /dev/null
done

# Verificar logs estruturados
kubectl logs -l app=api-gateway -n ecommerce-demo | grep -E "(GET|POST|PUT|DELETE)"
```

**Resultado Esperado:**
- ✅ Métricas Prometheus sendo coletadas
- ✅ Logs estruturados com trace IDs
- ✅ Telemetria configurada corretamente

### 9. 🎪 Demonstração Interativa

Execute a demonstração completa:

```bash
# Executar demonstração interativa
./scripts/demo-presentation.sh

# Ou executar cenários específicos manualmente:

# Cenário 1: Canary Deployment
kubectl patch deployment order-service -n ecommerce-demo -p '{"spec":{"template":{"metadata":{"labels":{"version":"canary"}}}}}'

# Cenário 2: Chaos Engineering
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: payment-chaos
  namespace: ecommerce-demo
spec:
  hosts:
  - payment-service.ecommerce-demo.svc.cluster.local
  http:
  - fault:
      delay:
        percentage:
          value: 50.0
        fixedDelay: 5s
    route:
    - destination:
        host: payment-service.ecommerce-demo.svc.cluster.local
EOF

# Cenário 3: Load Testing
kubectl run fortio --image=fortio/fortio -- load -c 10 -qps 100 -t 60s http://frontend.ecommerce-demo.svc.cluster.local/
```

**Resultado Esperado:**
- ✅ Demonstração executando sem erros
- ✅ Cenários de resiliência funcionando
- ✅ Métricas sendo atualizadas em tempo real

### 10. 🧹 Limpeza do Ambiente

Após a validação, limpe o ambiente:

```bash
# Limpeza automática
./scripts/deploy-manual.sh
# Escolher opção 2 (Limpar ambiente)

# Ou limpeza manual
kubectl delete namespace ecommerce-demo

# Verificar limpeza
kubectl get all -n ecommerce-demo 2>/dev/null || echo "Namespace removido com sucesso"
```

**Resultado Esperado:**
- ✅ Todos os recursos removidos
- ✅ Namespace deletado
- ✅ Ambiente limpo

## 🤖 Validação via GitHub Actions

### 1. Configurar Secrets

No repositório GitHub, configure os secrets:

```
AZURE_CLIENT_ID=<seu-client-id>
AZURE_TENANT_ID=<seu-tenant-id>
AZURE_SUBSCRIPTION_ID=<seu-subscription-id>
```

### 2. Executar Workflows

Execute os workflows na seguinte ordem:

1. **Deploy**: Actions → "🚀 Deploy E-commerce Platform Demo" → Run workflow → Action: `deploy`
2. **Canary**: Actions → "🚀 Deploy E-commerce Platform Demo" → Run workflow → Action: `canary-deploy`
3. **Chaos**: Actions → "🚀 Deploy E-commerce Platform Demo" → Run workflow → Action: `chaos-test`
4. **Load Test**: Actions → "🚀 Deploy E-commerce Platform Demo" → Run workflow → Action: `load-test`
5. **Cleanup**: Actions → "🚀 Deploy E-commerce Platform Demo" → Run workflow → Action: `destroy`

### 3. Verificar Logs

Monitore os logs de cada workflow para garantir execução sem erros.

## ✅ Checklist de Validação

### Templates e Scripts
- [ ] Todos os templates renderizam sem erro
- [ ] YAMLs gerados são válidos
- [ ] Script de renderização funciona com todas as opções
- [ ] Script de validação executa completamente
- [ ] Script de demonstração funciona

### Aplicação Demo
- [ ] Namespace criado com injeção Istio
- [ ] Todos os 6 serviços deployados
- [ ] Pods com sidecar Istio (2/2 containers)
- [ ] Serviços acessíveis internamente
- [ ] Frontend acessível externamente

### Configurações Istio
- [ ] Gateway configurado e funcionando
- [ ] VirtualServices aplicados
- [ ] DestinationRules com circuit breakers
- [ ] mTLS STRICT habilitado
- [ ] Políticas de autorização ativas
- [ ] Telemetria coletando métricas

### Resiliência
- [ ] Circuit breakers funcionando
- [ ] Retry policies ativas
- [ ] Timeout policies configuradas
- [ ] Outlier detection funcionando
- [ ] Graceful degradation testada

### Segurança
- [ ] mTLS entre todos os serviços
- [ ] Políticas de autorização bloqueando acesso
- [ ] Rate limiting funcionando (se configurado)
- [ ] Certificados válidos
- [ ] Auditoria de acesso ativa

### Observabilidade
- [ ] Métricas Prometheus coletadas
- [ ] Logs estruturados gerados
- [ ] Trace IDs presentes
- [ ] Telemetria customizada funcionando
- [ ] Dashboards acessíveis (se configurado)

### GitHub Actions
- [ ] Workflow de deploy executa sem erro
- [ ] Workflow de canary funciona
- [ ] Workflow de chaos test executa
- [ ] Workflow de load test funciona
- [ ] Workflow de cleanup limpa ambiente

## 🚨 Troubleshooting

### Problemas Comuns

1. **Pods não ficam prontos**
   ```bash
   kubectl describe pod <pod-name> -n ecommerce-demo
   kubectl logs <pod-name> -c istio-proxy -n ecommerce-demo
   ```

2. **Gateway não responde**
   ```bash
   kubectl get gateway -n ecommerce-demo
   kubectl describe gateway frontend-gateway -n ecommerce-demo
   ```

3. **mTLS não funciona**
   ```bash
   kubectl get peerauthentication -n ecommerce-demo
   kubectl logs -l app=istiod -n aks-istio-system
   ```

4. **Circuit breaker não abre**
   ```bash
   kubectl get destinationrule -n ecommerce-demo -o yaml
   kubectl exec -n ecommerce-demo deployment/frontend -c istio-proxy -- curl localhost:15000/clusters
   ```

### Logs Importantes

```bash
# Logs do Istio control plane
kubectl logs -l app=istiod -n aks-istio-system

# Logs do sidecar
kubectl logs <pod-name> -c istio-proxy -n ecommerce-demo

# Configuração do Envoy
kubectl exec <pod-name> -c istio-proxy -n ecommerce-demo -- curl localhost:15000/config_dump
```

## 📞 Suporte

Para problemas ou dúvidas:

1. Verifique os logs conforme indicado no troubleshooting
2. Consulte a documentação oficial do Istio
3. Abra uma issue no repositório GitHub
4. Entre em contato com a equipe de arquitetura

---

**Desenvolvido com ❤️ para máxima confiabilidade e excelência operacional.**
