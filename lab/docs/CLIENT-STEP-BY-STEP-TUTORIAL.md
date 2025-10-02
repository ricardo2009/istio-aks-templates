# 🎯 TUTORIAL PASSO-A-PASSO PARA CLIENTE
## Laboratório Istio Multi-Cluster no AKS com Estratégias Avançadas

---

## 📋 **PRÉ-REQUISITOS**

### **🔧 Ferramentas Necessárias**
```bash
# 1. Azure CLI (versão 2.50+)
az --version

# 2. kubectl (versão 1.28+)
kubectl version --client

# 3. Git
git --version

# 4. jq (para parsing JSON)
jq --version
```

### **☁️ Permissões Azure**
- ✅ **Subscription**: Contributor ou Owner
- ✅ **Resource Group**: Contributor
- ✅ **AKS**: Azure Kubernetes Service Contributor
- ✅ **Network**: Network Contributor

### **🔑 Credenciais Necessárias**
- ✅ **Azure Service Principal** com client secret
- ✅ **GitHub Token** (se usando automação)
- ✅ **Subscription ID** e **Tenant ID**

---

## 🚀 **FASE 1: PREPARAÇÃO DO AMBIENTE**

### **Passo 1.1: Clone do Repositório**
```bash
# Clone o repositório do laboratório
git clone https://github.com/ricardo2009/istio-aks-templates.git
cd istio-aks-templates

# Verificar estrutura do projeto
ls -la lab/
```

**✅ Resultado Esperado:**
```
lab/
├── applications/          # Aplicações de demonstração
├── docs/                 # Documentação completa
├── manifests/            # Manifestos Kubernetes
├── observability/        # Dashboards e configurações
└── scripts/              # Scripts de automação
```

### **Passo 1.2: Configuração das Credenciais**
```bash
# Definir variáveis de ambiente
export AZURE_CLIENT_ID="6f37088c-e465-472f-a2f0-ac45a3fd8e57"
export AZURE_CLIENT_SECRET="SEU_CLIENT_SECRET_AQUI"
export AZURE_TENANT_ID="03ebf151-fe12-4011-976d-d593ff5252a0"
export AZURE_SUBSCRIPTION_ID="e8b8de74-8888-4318-a598-fbe78fb29c59"

# Fazer login no Azure
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Definir subscription padrão
az account set --subscription $AZURE_SUBSCRIPTION_ID
```

**✅ Resultado Esperado:**
```json
{
  "environmentName": "AzureCloud",
  "homeTenantId": "03ebf151-fe12-4011-976d-d593ff5252a0",
  "id": "e8b8de74-8888-4318-a598-fbe78fb29c59",
  "isDefault": true,
  "name": "Sua Subscription",
  "state": "Enabled",
  "tenantId": "03ebf151-fe12-4011-976d-d593ff5252a0"
}
```

### **Passo 1.3: Validação do Ambiente**
```bash
# Verificar quota de cores disponível
az vm list-usage --location westus3 --query "[?name.value=='cores'].{Name:name.value,Current:currentValue,Limit:limit}" -o table

# Verificar resource group
az group show --name lab-istio --query "{Name:name,Location:location,State:properties.provisioningState}" -o table
```

**✅ Resultado Esperado:**
- ✅ Pelo menos **8 cores disponíveis** na região
- ✅ Resource group **lab-istio** existe e está **Succeeded**

---

## 🏗️ **FASE 2: CRIAÇÃO DA INFRAESTRUTURA**

### **Passo 2.1: Execução do Script de Setup**
```bash
# Navegar para o diretório do laboratório
cd istio-aks-templates

# Executar script de criação da infraestrutura
./lab/scripts/00-setup-azure-resources.sh
```

**⏱️ Tempo Estimado: 15-20 minutos**

**📊 Progresso Esperado:**
```
[INFO] 🚀 Criando clusters AKS...
[INFO] ✅ Cluster aks-istio-primary criado com sucesso
[INFO] ✅ Cluster aks-istio-secondary criado com sucesso
[INFO] 🔧 Habilitando Istio nos clusters...
[INFO] ✅ Istio habilitado no cluster primário
[INFO] ✅ Istio habilitado no cluster secundário
[INFO] 🌐 Habilitando Ingress Gateways...
[INFO] ✅ Ingress Gateway configurado
[SUCCESS] 🎉 Infraestrutura criada com sucesso!
```

### **Passo 2.2: Validação da Infraestrutura**
```bash
# Executar script de validação
./lab/scripts/01-validate-infrastructure.sh
```

**✅ Resultado Esperado:**
```json
{
  "validation_summary": {
    "total_checks": 17,
    "passed": 17,
    "failed": 0,
    "success_rate": "100.0%"
  },
  "cluster_status": {
    "aks-istio-primary": "✅ Healthy",
    "aks-istio-secondary": "✅ Healthy"
  },
  "istio_status": {
    "control_plane": "✅ Running",
    "ingress_gateways": "✅ Ready"
  }
}
```

### **Passo 2.3: Configuração do kubectl**
```bash
# Obter credenciais dos clusters
az aks get-credentials --resource-group lab-istio --name aks-istio-primary --context aks-istio-primary
az aks get-credentials --resource-group lab-istio --name aks-istio-secondary --context aks-istio-secondary

# Verificar conectividade
kubectl get nodes --context=aks-istio-primary
kubectl get nodes --context=aks-istio-secondary
```

**✅ Resultado Esperado:**
```
NAME                                STATUS   ROLES   AGE   VERSION
aks-nodepool1-41477546-vmss000000   Ready    agent   10m   v1.30.14
aks-nodepool1-41477546-vmss000001   Ready    agent   10m   v1.30.14
```

---

## 🎯 **FASE 3: IMPLEMENTAÇÃO DAS ESTRATÉGIAS UNIFICADAS**

### **Passo 3.1: Deploy da Aplicação Unificada**
```bash
# Aplicar aplicação com todas as estratégias
kubectl apply -f lab/applications/unified-strategies/ecommerce-app-fixed.yaml
kubectl apply -f lab/applications/unified-strategies/istio-unified-strategies-fixed.yaml

# Aguardar pods estarem prontos (pode levar 2-3 minutos)
kubectl wait --for=condition=ready pod -l app=ecommerce-app -n ecommerce-unified --timeout=300s
```

**✅ Resultado Esperado:**
```
namespace/ecommerce-unified created
deployment.apps/ecommerce-app-v1 created
deployment.apps/ecommerce-app-v2 created
deployment.apps/ecommerce-app-canary created
service/ecommerce-app created
gateway.networking.istio.io/ecommerce-gateway created
virtualservice.networking.istio.io/ecommerce-vs created
destinationrule.networking.istio.io/ecommerce-dr created
```

### **Passo 3.2: Verificação dos Pods**
```bash
# Verificar status dos pods
kubectl get pods -n ecommerce-unified -o wide

# Verificar logs de um pod (exemplo)
kubectl logs -n ecommerce-unified -l app=ecommerce-app,version=v1 --tail=10
```

**✅ Resultado Esperado:**
```
NAME                                 READY   STATUS    RESTARTS   AGE
ecommerce-app-v1-7f6d9cf9f4-abc123   1/1     Running   0          2m
ecommerce-app-v2-8g7e0dg0g5-def456   1/1     Running   0          2m
ecommerce-app-canary-9h8f1eh1h6-ghi789 1/1   Running   0          2m
```

### **Passo 3.3: Obter IP do Ingress Gateway**
```bash
# Obter IP externo do Ingress Gateway
GATEWAY_IP=$(kubectl get service aks-istio-ingressgateway-external -n aks-istio-ingress --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "🌐 Gateway IP: $GATEWAY_IP"

# Testar conectividade básica
curl -s "http://$GATEWAY_IP/" | jq -r '.version'
```

**✅ Resultado Esperado:**
```
🌐 Gateway IP: 4.249.105.42
v1.0.0
```

---

## 🧪 **FASE 4: DEMONSTRAÇÃO DAS ESTRATÉGIAS**

### **Passo 4.1: Teste das Estratégias Unificadas**
```bash
# Executar script de teste completo
./lab/scripts/test-unified-strategies.sh
```

**📊 Resultados Esperados:**

#### **🔵 Blue/Green Deployment**
```
Blue/Green Test Results:
- Blue (v1.0.0): 14 requests (70%)
- Green (v2.0.0): 6 requests (30%)
✅ Blue/Green strategy working correctly!
```

#### **🎯 A/B Testing**
```
A/B Testing Results:
- Premium users → Green: 10/10 (100%)
- Regular users → Mixed: 8 Blue, 2 Green
✅ A/B testing strategy working correctly!
```

#### **🚀 Canary Deployment**
```
Canary Test Results:
- Stable (v1): 16 requests (80%)
- Canary (v3): 4 requests (20%)
✅ Canary strategy working correctly!
```

### **Passo 4.2: Demonstração Cross-Cluster**
```bash
# Deploy aplicações cross-cluster
kubectl apply -f lab/applications/cross-cluster-real/cluster1-api.yaml --context=aks-istio-primary
kubectl apply -f lab/applications/cross-cluster-real/cluster2-api.yaml --context=aks-istio-secondary

# Aguardar pods estarem prontos
kubectl wait --for=condition=ready pod -l app=frontend-api -n cross-cluster-demo --context=aks-istio-primary --timeout=300s
kubectl wait --for=condition=ready pod -l app=payment-api -n cross-cluster-demo --context=aks-istio-secondary --timeout=300s
```

### **Passo 4.3: Teste de Comunicação Cross-Cluster**
```bash
# Executar demonstração ultra-avançada
./lab/scripts/03-ultra-advanced-demo.sh
```

**📊 Resultados Esperados:**
```json
{
  "service": "Payment API",
  "cluster": "aks-istio-secondary",
  "payment": {
    "id": "pay_1759421930224_48xgp5",
    "status": "✅ approved",
    "amount": 99.99,
    "currency": "EUR",
    "processingTime": 226
  },
  "audit": {
    "success": true,
    "responseTime": 55
  },
  "crossClusterCall": {
    "source": "aks-istio-primary",
    "target": "aks-istio-secondary",
    "success": true,
    "latency": 283
  },
  "responseTime": 283
}
```

---

## 📊 **FASE 5: OBSERVABILIDADE E DASHBOARDS**

### **Passo 5.1: Instalação do Kiali**
```bash
# Aplicar configuração do Kiali
kubectl apply -f lab/observability/kiali-config.yaml

# Aguardar Kiali estar pronto
kubectl wait --for=condition=ready pod -l app=kiali -n kiali-operator --timeout=300s

# Obter IP do Kiali
KIALI_IP=$(kubectl get service kiali -n kiali-operator -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "🔍 Kiali URL: http://$KIALI_IP:20001/kiali"
```

### **Passo 5.2: Configuração do Dashboard Grafana**
```bash
# Instalar Grafana (se não estiver instalado)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm install grafana grafana/grafana \
  --namespace grafana \
  --create-namespace \
  --set service.type=LoadBalancer \
  --set adminPassword=admin123

# Aguardar Grafana estar pronto
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n grafana --timeout=300s

# Obter IP do Grafana
GRAFANA_IP=$(kubectl get service grafana -n grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "📊 Grafana URL: http://$GRAFANA_IP"
echo "👤 Username: admin"
echo "🔑 Password: admin123"
```

### **Passo 5.3: Importar Dashboard Personalizado**
```bash
# O dashboard está em: lab/observability/grafana-dashboard-ultimate.json
echo "📋 Para importar o dashboard:"
echo "1. Acesse Grafana: http://$GRAFANA_IP"
echo "2. Vá em '+' → Import"
echo "3. Cole o conteúdo de: lab/observability/grafana-dashboard-ultimate.json"
echo "4. Clique em 'Load' e depois 'Import'"
```

---

## 🎭 **FASE 6: DEMONSTRAÇÃO PARA O CLIENTE**

### **Passo 6.1: Preparação da Apresentação**
```bash
# Executar script de apresentação
./lab/scripts/demo-presentation.sh

# Verificar se todos os serviços estão funcionando
echo "🔍 Kiali: http://$KIALI_IP:20001/kiali"
echo "📊 Grafana: http://$GRAFANA_IP"
echo "🌐 Aplicação: http://$GATEWAY_IP"
```

### **Passo 6.2: Pontos de Destaque para o Cliente**

#### **🎯 Demonstrar Estratégias Unificadas**
```bash
# 1. Blue/Green - Mostrar distribuição 70/30
curl -s "http://$GATEWAY_IP/" | jq -r '.version'

# 2. A/B Testing - Usuários premium sempre v2
curl -s -H "x-user-type: premium" "http://$GATEWAY_IP/" | jq -r '.version'

# 3. Canary - 20% do tráfego para canary
curl -s -H "x-user-type: regular" "http://$GATEWAY_IP/" | jq -r '.version'

# 4. Geographic - Usuários europeus para Green
curl -s -H "x-user-location: eu" "http://$GATEWAY_IP/" | jq -r '.version'
```

#### **🌐 Demonstrar Cross-Cluster**
```bash
# Mostrar comunicação entre clusters
kubectl exec -n cross-cluster-demo --context=aks-istio-secondary \
  $(kubectl get pod -l app=payment-api -n cross-cluster-demo --context=aks-istio-secondary -o jsonpath='{.items[0].metadata.name}') \
  -- wget -qO- "http://10.20.2.16:3002/payment?amount=99.99&currency=EUR"
```

#### **📊 Demonstrar Observabilidade**
```bash
# Mostrar logs em tempo real
kubectl logs -f -l app=ecommerce-app,version=v1 -n ecommerce-unified --tail=10
```

### **Passo 6.3: Métricas de Sucesso para Mostrar**

#### **⚡ Performance**
- ✅ **Latência P95**: < 500ms
- ✅ **Success Rate**: > 99%
- ✅ **Cross-Cluster Latency**: ~283ms

#### **🔄 Resiliência**
- ✅ **Circuit Breaker**: Ativo e funcional
- ✅ **Auto-Recovery**: < 2 minutos
- ✅ **Failover**: Automático entre clusters

#### **🎯 Estratégias**
- ✅ **6 Estratégias Simultâneas**: A/B + Blue/Green + Canary + Shadow + Geographic + Device
- ✅ **Rollback Automático**: Baseado em SLOs
- ✅ **Zero Downtime**: Durante deployments

---

## 🧹 **FASE 7: LIMPEZA (OPCIONAL)**

### **Passo 7.1: Limpeza Completa**
```bash
# Executar script de limpeza
./lab/scripts/00-cleanup-all.sh

# Confirmar limpeza quando solicitado
# Digite 'y' e pressione Enter
```

### **Passo 7.2: Verificação da Limpeza**
```bash
# Verificar se recursos foram removidos
az aks list --resource-group lab-istio --output table
kubectl config get-contexts
```

**✅ Resultado Esperado:**
```
No resources found.
```

---

## 🎯 **PONTOS DE DESTAQUE PARA IMPRESSIONAR O CLIENTE**

### **🏆 Diferenciadores Técnicos**
1. **6 Estratégias Simultâneas** - Único no mercado
2. **Rollback Automático** - Baseado em métricas reais
3. **Cross-Cluster Nativo** - Comunicação transparente
4. **Execução Real** - Não é simulação, tudo funcional
5. **Observabilidade Completa** - Logs, métricas, traces

### **💼 Valor de Negócio**
1. **Zero Downtime** - Deployments sem impacto
2. **Risk Mitigation** - Rollback automático em < 2min
3. **User Experience** - Roteamento inteligente
4. **Cost Optimization** - Recursos otimizados
5. **Compliance Ready** - Audit trails completos

### **🚀 Expertise Demonstrada**
1. **Service Mesh Mastery** - Istio gerenciado no AKS
2. **Cloud-Native Architecture** - Microservices, containers
3. **DevOps Excellence** - Automação completa
4. **Site Reliability Engineering** - SLOs, monitoring
5. **Enterprise Security** - mTLS, authorization policies

---

## 📞 **SUPORTE E CONTATO**

### **🆘 Em Caso de Problemas**
1. **Verificar logs**: `kubectl logs -f <pod-name> -n <namespace>`
2. **Verificar eventos**: `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`
3. **Verificar recursos**: `kubectl get all -n <namespace>`
4. **Verificar Istio**: `kubectl get pods -n aks-istio-system`

### **📚 Documentação Adicional**
- **Análise de Especialista**: `lab/docs/EXPERT-ANALYSIS.md`
- **Arquitetura Detalhada**: `lab/docs/ARCHITECTURE.md`
- **Troubleshooting**: `lab/docs/TROUBLESHOOTING.md`

---

## 🎉 **CONCLUSÃO**

**Parabéns! Você implementou com sucesso um laboratório de Service Mesh de nível empresarial que demonstra:**

- ✅ **Expertise Técnica Avançada** em Istio e Kubernetes
- ✅ **Arquitetura Multi-Cluster** funcional e escalável
- ✅ **Estratégias de Deployment** de última geração
- ✅ **Observabilidade Empresarial** completa
- ✅ **Automação Inteligente** com rollback automático

**Este laboratório está pronto para impressionar clientes de altíssimo nível técnico e demonstrar capacidades de consultoria especializada em Service Mesh!** 🚀
