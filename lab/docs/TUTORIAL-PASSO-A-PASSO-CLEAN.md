# 🚀 TUTORIAL PASSO-A-PASSO: LABORATÓRIO ISTIO MULTI-CLUSTER

**Versão limpa sem credenciais sensíveis**

## 📋 PRÉ-REQUISITOS

Antes de começar, certifique-se de que você tem:
- ✅ Azure CLI instalado
- ✅ kubectl instalado  
- ✅ Acesso à subscription Azure
- ✅ Permissões de Contributor
- ✅ Credenciais do service principal

## 🎯 PASSO 1: CONFIGURAR AMBIENTE

### 1.1 Definir Variáveis de Ambiente

```bash
export AZURE_CLIENT_ID="<SEU_CLIENT_ID>"
export AZURE_CLIENT_SECRET="<SEU_CLIENT_SECRET>"
export AZURE_TENANT_ID="<SEU_TENANT_ID>"
export AZURE_SUBSCRIPTION_ID="<SUA_SUBSCRIPTION_ID>"
```

### 1.2 Fazer Login no Azure

```bash
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID
```

## 🏗️ PASSO 2: PROVISIONAR LABORATÓRIO COMPLETO

### 2.1 Executar Script de Provisionamento

```bash
cd istio-aks-templates
./lab/scripts/00-provision-complete-lab.sh
```

Este script irá:
- ✅ Criar 2 clusters AKS com Istio gerenciado
- ✅ Configurar Azure Key Vault com certificados
- ✅ Instalar Kiali, Grafana, Jaeger
- ✅ Implementar aplicações de demonstração
- ✅ Configurar mTLS STRICT
- ✅ Executar validações completas

## 📊 PASSO 3: ACESSAR DASHBOARDS

### 3.1 Obter IPs dos Serviços

```bash
# Executar script de acesso
/tmp/lab-access.sh
```

### 3.2 URLs de Acesso

- **🛒 E-commerce App**: http://GATEWAY_IP
- **🔍 Kiali**: http://KIALI_IP:20001/kiali
- **📊 Grafana**: http://GRAFANA_IP (admin/admin123)
- **🔍 Jaeger**: http://JAEGER_IP:16686

## 🧪 PASSO 4: EXECUTAR DEMONSTRAÇÕES

### 4.1 Testar Estratégias Unificadas

```bash
./lab/scripts/test-unified-strategies.sh
```

### 4.2 Demonstração Cross-Cluster

```bash
./lab/scripts/03-ultra-advanced-demo.sh
```

### 4.3 Validar Infraestrutura

```bash
./lab/scripts/01-validate-infrastructure.sh
```

## 🔐 PASSO 5: VERIFICAR SEGURANÇA

### 5.1 Verificar mTLS

```bash
kubectl get peerauthentication -A
```

### 5.2 Verificar Certificados

```bash
kubectl get secrets -n istio-certificates
```

## 🧹 PASSO 6: LIMPEZA (OPCIONAL)

```bash
/tmp/lab-cleanup.sh
```

## 📚 RECURSOS ADICIONAIS

- **Análise de Especialista**: `lab/docs/EXPERT-ANALYSIS.md`
- **Tutorial para Cliente**: `lab/docs/CLIENT-STEP-BY-STEP-TUTORIAL.md`
- **Plano Mestre**: `lab/docs/LAB-MASTER-PLAN.md`

---

**🎉 LABORATÓRIO PRONTO PARA DEMONSTRAÇÃO!**

Este tutorial garante uma execução segura e profissional do laboratório Istio multi-cluster.
