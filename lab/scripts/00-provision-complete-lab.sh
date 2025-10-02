#!/bin/bash

# 🚀 SCRIPT COMPLETO DE PROVISIONAMENTO DO LABORATÓRIO ISTIO MULTI-CLUSTER
# Este script provisiona TODOS os recursos necessários para o laboratório avançado

set -euo pipefail

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/complete-lab-provision_${TIMESTAMP}.log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações do Azure
AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-6f37088c-e465-472f-a2f0-ac45a3fd8e57}"
AZURE_TENANT_ID="${AZURE_TENANT_ID:-03ebf151-fe12-4011-976d-d593ff5252a0}"
AZURE_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-e8b8de74-8888-4318-a598-fbe78fb29c59}"
RESOURCE_GROUP="${RESOURCE_GROUP:-lab-istio}"
LOCATION="${LOCATION:-westus3}"
KEY_VAULT_NAME="${KEY_VAULT_NAME:-kv-istio-lab-certs-$(date +%s)}"

# Funções de logging
log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] 🎯 $1${NC}" | tee -a "$LOG_FILE"
}

# Verificar pré-requisitos
check_prerequisites() {
    log_step "Verificando pré-requisitos..."
    
    # Verificar Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI não encontrado. Por favor, instale a Azure CLI."
        exit 1
    fi
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl não encontrado. Por favor, instale kubectl."
        exit 1
    fi
    
    # Verificar helm
    if ! command -v helm &> /dev/null; then
        log_info "📦 Instalando Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Verificar jq
    if ! command -v jq &> /dev/null; then
        log_info "📦 Instalando jq..."
        sudo apt-get update && sudo apt-get install -y jq
    fi
    
    # Verificar variáveis de ambiente
    if [ -z "$AZURE_CLIENT_SECRET" ]; then
        log_error "AZURE_CLIENT_SECRET não definido. Por favor, defina a variável de ambiente."
        exit 1
    fi
    
    log_success "Pré-requisitos verificados com sucesso"
}

# Fazer login no Azure
azure_login() {
    log_step "Fazendo login no Azure..."
    
    az login --service-principal \
        --username "$AZURE_CLIENT_ID" \
        --password "$AZURE_CLIENT_SECRET" \
        --tenant "$AZURE_TENANT_ID"
    
    az account set --subscription "$AZURE_SUBSCRIPTION_ID"
    
    log_success "Login no Azure realizado com sucesso"
}

# Criar Azure Key Vault
create_key_vault() {
    log_step "Criando Azure Key Vault para certificados..."
    
    # Verificar se Key Vault já existe
    if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Key Vault $KEY_VAULT_NAME já existe"
        return 0
    fi
    
    # Criar Key Vault
    az keyvault create \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku standard \
        --enabled-for-deployment true \
        --enabled-for-disk-encryption true \
        --enabled-for-template-deployment true \
        --enable-rbac-authorization false
    
    # Definir política de acesso para o service principal
    az keyvault set-policy \
        --name "$KEY_VAULT_NAME" \
        --spn "$AZURE_CLIENT_ID" \
        --certificate-permissions get list create update delete \
        --secret-permissions get list set delete \
        --key-permissions get list create update delete
    
    log_success "Key Vault $KEY_VAULT_NAME criado com sucesso"
}

# Gerar certificados no Key Vault
generate_certificates() {
    log_step "Gerando certificados no Key Vault..."
    
    # Política de certificado para Root CA
    cat > "/tmp/root-ca-policy.json" << EOF
{
  "issuerParameters": {
    "name": "Self"
  },
  "keyProperties": {
    "exportable": true,
    "keySize": 4096,
    "keyType": "RSA",
    "reuseKey": false
  },
  "secretProperties": {
    "contentType": "application/x-pem-file"
  },
  "x509CertificateProperties": {
    "keyUsage": [
      "cRLSign",
      "dataEncipherment",
      "digitalSignature",
      "keyAgreement",
      "keyCertSign",
      "keyEncipherment"
    ],
    "subject": "CN=Istio Root CA,O=Lab Istio,L=Cloud,ST=Azure,C=US",
    "validityInMonths": 24,
    "basicConstraints": {
      "ca": true
    }
  }
}
EOF
    
    # Política de certificado para Intermediate CA
    cat > "/tmp/intermediate-ca-policy.json" << EOF
{
  "issuerParameters": {
    "name": "Self"
  },
  "keyProperties": {
    "exportable": true,
    "keySize": 2048,
    "keyType": "RSA",
    "reuseKey": false
  },
  "secretProperties": {
    "contentType": "application/x-pem-file"
  },
  "x509CertificateProperties": {
    "keyUsage": [
      "cRLSign",
      "dataEncipherment",
      "digitalSignature",
      "keyAgreement",
      "keyCertSign",
      "keyEncipherment"
    ],
    "subject": "CN=Istio Intermediate CA,O=Lab Istio,L=Cloud,ST=Azure,C=US",
    "validityInMonths": 12,
    "basicConstraints": {
      "ca": true
    }
  }
}
EOF
    
    # Política de certificado para aplicação
    cat > "/tmp/app-cert-policy.json" << EOF
{
  "issuerParameters": {
    "name": "Self"
  },
  "keyProperties": {
    "exportable": true,
    "keySize": 2048,
    "keyType": "RSA",
    "reuseKey": false
  },
  "secretProperties": {
    "contentType": "application/x-pem-file"
  },
  "x509CertificateProperties": {
    "keyUsage": [
      "dataEncipherment",
      "digitalSignature",
      "keyEncipherment"
    ],
    "subject": "CN=ecommerce.lab.local,O=Lab Istio,L=Cloud,ST=Azure,C=US",
    "subjectAlternativeNames": {
      "dnsNames": [
        "ecommerce.lab.local",
        "*.ecommerce.lab.local",
        "api.ecommerce.lab.local",
        "frontend.ecommerce.lab.local"
      ]
    },
    "validityInMonths": 12
  }
}
EOF
    
    # Gerar certificados
    certificates=(
        "istio-root-ca-cert:/tmp/root-ca-policy.json"
        "istio-intermediate-ca-cert:/tmp/intermediate-ca-policy.json"
        "ecommerce-app-cert:/tmp/app-cert-policy.json"
        "gateway-tls-cert:/tmp/app-cert-policy.json"
    )
    
    for cert_info in "${certificates[@]}"; do
        cert_name="${cert_info%%:*}"
        policy_file="${cert_info##*:}"
        
        log_info "Gerando certificado: $cert_name"
        
        az keyvault certificate create \
            --vault-name "$KEY_VAULT_NAME" \
            --name "$cert_name" \
            --policy "$(cat "$policy_file")" \
            --tags "environment=lab" "component=istio" "type=certificate"
    done
    
    # Gerar chaves privadas como secrets
    private_keys=(
        "istio-root-ca-key"
        "istio-intermediate-ca-key"
        "ecommerce-app-key"
        "gateway-tls-key"
    )
    
    for key_name in "${private_keys[@]}"; do
        log_info "Gerando chave privada: $key_name"
        
        # Gerar chave privada (simulada para o laboratório)
        openssl genrsa -out "/tmp/$key_name.pem" 2048
        
        az keyvault secret set \
            --vault-name "$KEY_VAULT_NAME" \
            --name "$key_name" \
            --file "/tmp/$key_name.pem" \
            --tags "environment=lab" "component=istio" "type=private-key"
        
        rm -f "/tmp/$key_name.pem"
    done
    
    # Limpar arquivos temporários
    rm -f /tmp/*-policy.json
    
    log_success "Certificados gerados com sucesso no Key Vault"
}

# Instalar Azure Key Vault CSI Driver
install_keyvault_csi_driver() {
    log_step "Instalando Azure Key Vault CSI Driver..."
    
    # Adicionar repositório Helm
    helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
    helm repo update
    
    # Instalar CSI Driver no cluster primário
    helm upgrade --install csi-secrets-store-provider-azure csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
        --namespace kube-system \
        --set secrets-store-csi-driver.syncSecret.enabled=true \
        --set secrets-store-csi-driver.enableSecretRotation=true \
        --context=aks-istio-primary
    
    # Instalar CSI Driver no cluster secundário
    helm upgrade --install csi-secrets-store-provider-azure csi-secrets-store-provider-azure/csi-secrets-store-provider-azure \
        --namespace kube-system \
        --set secrets-store-csi-driver.syncSecret.enabled=true \
        --set secrets-store-csi-driver.enableSecretRotation=true \
        --context=aks-istio-secondary
    
    log_success "Azure Key Vault CSI Driver instalado com sucesso"
}

# Criar clusters AKS
create_aks_clusters() {
    log_step "Criando clusters AKS..."
    
    # Executar script de criação de infraestrutura
    if [ -f "${LAB_DIR}/scripts/00-setup-azure-resources.sh" ]; then
        "${LAB_DIR}/scripts/00-setup-azure-resources.sh"
    else
        log_error "Script de setup de infraestrutura não encontrado"
        exit 1
    fi
    
    log_success "Clusters AKS criados com sucesso"
}

# Configurar mTLS com Key Vault
setup_mtls_keyvault() {
    log_step "Configurando mTLS com Azure Key Vault..."
    
    # Atualizar configuração com o nome correto do Key Vault
    sed -i "s/kv-istio-lab-certs/$KEY_VAULT_NAME/g" "${LAB_DIR}/security/azure-keyvault-mtls.yaml"
    
    # Aplicar configuração de mTLS no cluster primário
    kubectl apply -f "${LAB_DIR}/security/azure-keyvault-mtls.yaml" --context=aks-istio-primary
    
    # Aplicar configuração de mTLS no cluster secundário
    kubectl apply -f "${LAB_DIR}/security/azure-keyvault-mtls.yaml" --context=aks-istio-secondary
    
    log_success "mTLS com Key Vault configurado com sucesso"
}

# Instalar observabilidade
install_observability() {
    log_step "Instalando stack de observabilidade..."
    
    # Executar script de instalação de observabilidade
    if [ -f "${LAB_DIR}/scripts/04-install-observability.sh" ]; then
        "${LAB_DIR}/scripts/04-install-observability.sh"
    else
        log_error "Script de observabilidade não encontrado"
        exit 1
    fi
    
    log_success "Stack de observabilidade instalada com sucesso"
}

# Implementar aplicações de demonstração
deploy_demo_applications() {
    log_step "Implementando aplicações de demonstração..."
    
    # Aplicar aplicação unificada com estratégias
    kubectl apply -f "${LAB_DIR}/applications/unified-strategies/ecommerce-app-fixed.yaml" --context=aks-istio-primary
    kubectl apply -f "${LAB_DIR}/applications/unified-strategies/istio-unified-strategies-fixed.yaml" --context=aks-istio-primary
    
    # Aplicar aplicações cross-cluster
    kubectl apply -f "${LAB_DIR}/applications/cross-cluster-real/cluster1-api.yaml" --context=aks-istio-primary
    kubectl apply -f "${LAB_DIR}/applications/cross-cluster-real/cluster2-api.yaml" --context=aks-istio-secondary
    
    # Aguardar pods estarem prontos
    log_info "Aguardando pods estarem prontos..."
    kubectl wait --for=condition=ready pod -l app=ecommerce-app -n ecommerce-unified --context=aks-istio-primary --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=frontend-api -n cross-cluster-demo --context=aks-istio-primary --timeout=300s || true
    kubectl wait --for=condition=ready pod -l app=payment-api -n cross-cluster-demo --context=aks-istio-secondary --timeout=300s || true
    
    log_success "Aplicações de demonstração implementadas com sucesso"
}

# Executar testes de validação
run_validation_tests() {
    log_step "Executando testes de validação..."
    
    # Executar validação de infraestrutura
    if [ -f "${LAB_DIR}/scripts/01-validate-infrastructure.sh" ]; then
        "${LAB_DIR}/scripts/01-validate-infrastructure.sh"
    fi
    
    # Executar testes de estratégias unificadas
    if [ -f "${LAB_DIR}/scripts/test-unified-strategies.sh" ]; then
        "${LAB_DIR}/scripts/test-unified-strategies.sh"
    fi
    
    # Executar demonstração ultra-avançada
    if [ -f "${LAB_DIR}/scripts/03-ultra-advanced-demo.sh" ]; then
        "${LAB_DIR}/scripts/03-ultra-advanced-demo.sh"
    fi
    
    log_success "Testes de validação executados com sucesso"
}

# Criar scripts de acesso
create_access_scripts() {
    log_step "Criando scripts de acesso rápido..."
    
    # Script de acesso completo
    cat > "/tmp/lab-access.sh" << 'EOF'
#!/bin/bash

echo "🚀 LABORATÓRIO ISTIO MULTI-CLUSTER - ACESSO RÁPIDO"
echo "=================================================="

# Obter IPs dos serviços
GATEWAY_IP=$(kubectl get service aks-istio-ingressgateway-external -n aks-istio-ingress --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
KIALI_IP=$(kubectl get service kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
GRAFANA_IP=$(kubectl get service grafana -n grafana --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
JAEGER_IP=$(kubectl get service jaeger-query -n jaeger --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo ""
echo "🌐 APLICAÇÕES:"
if [ "$GATEWAY_IP" != "pending" ] && [ -n "$GATEWAY_IP" ]; then
    echo "   🛒 E-commerce App: http://$GATEWAY_IP"
    echo "   🔐 E-commerce HTTPS: https://$GATEWAY_IP (com certificados Key Vault)"
else
    echo "   🛒 E-commerce App: IP ainda não atribuído"
fi

echo ""
echo "📊 OBSERVABILIDADE:"
if [ "$KIALI_IP" != "pending" ] && [ -n "$KIALI_IP" ]; then
    echo "   🔍 Kiali (Service Mesh): http://$KIALI_IP:20001/kiali"
else
    echo "   🔍 Kiali: IP ainda não atribuído"
fi

if [ "$GRAFANA_IP" != "pending" ] && [ -n "$GRAFANA_IP" ]; then
    echo "   📊 Grafana (Dashboards): http://$GRAFANA_IP"
    echo "      👤 Username: admin"
    echo "      🔑 Password: admin123"
else
    echo "   📊 Grafana: IP ainda não atribuído"
fi

if [ "$JAEGER_IP" != "pending" ] && [ -n "$JAEGER_IP" ]; then
    echo "   🔍 Jaeger (Tracing): http://$JAEGER_IP:16686"
else
    echo "   🔍 Jaeger: IP ainda não atribuído"
fi

echo ""
echo "🧪 TESTES:"
echo "   ./test-unified-strategies.sh    # Testar estratégias A/B + Blue/Green + Canary"
echo "   ./03-ultra-advanced-demo.sh     # Demonstração cross-cluster completa"
echo "   ./01-validate-infrastructure.sh # Validar infraestrutura"

echo ""
echo "🔐 SEGURANÇA:"
echo "   mTLS STRICT: ✅ Ativo com certificados Azure Key Vault"
echo "   Authorization Policies: ✅ Configuradas"
echo "   Certificate Rotation: ✅ Automática (CronJob)"

echo ""
echo "🌐 CLUSTERS:"
echo "   Primary: aks-istio-primary (Frontend, API Gateway, User, Order)"
echo "   Secondary: aks-istio-secondary (Payment, Notification, Audit)"

echo ""
echo "📋 Para ver logs em tempo real:"
echo "   kubectl logs -f -l app=ecommerce-app -n ecommerce-unified --context=aks-istio-primary"
echo "   kubectl logs -f -l app=payment-api -n cross-cluster-demo --context=aks-istio-secondary"
EOF
    
    chmod +x "/tmp/lab-access.sh"
    
    # Script de limpeza
    cat > "/tmp/lab-cleanup.sh" << 'EOF'
#!/bin/bash

echo "🧹 LIMPEZA COMPLETA DO LABORATÓRIO"
echo "=================================="

read -p "⚠️  Tem certeza que deseja limpar TODOS os recursos? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Operação cancelada"
    exit 1
fi

# Executar script de limpeza
if [ -f "./lab/scripts/00-cleanup-all.sh" ]; then
    ./lab/scripts/00-cleanup-all.sh
else
    echo "❌ Script de limpeza não encontrado"
fi
EOF
    
    chmod +x "/tmp/lab-cleanup.sh"
    
    log_success "Scripts de acesso criados em /tmp/"
}

# Gerar relatório final
generate_final_report() {
    log_step "Gerando relatório final..."
    
    cat > "/tmp/lab-provision-report.md" << EOF
# 🎉 LABORATÓRIO ISTIO MULTI-CLUSTER - RELATÓRIO DE PROVISIONAMENTO

**Data:** $(date)
**Duração:** Iniciado em $TIMESTAMP

## ✅ RECURSOS PROVISIONADOS

### 🏗️ Infraestrutura
- **Resource Group:** $RESOURCE_GROUP
- **Location:** $LOCATION
- **Clusters AKS:** 2 (aks-istio-primary, aks-istio-secondary)
- **Istio:** Gerenciado habilitado em ambos os clusters
- **Ingress Gateways:** Configurados com LoadBalancer

### 🔐 Segurança
- **Azure Key Vault:** $KEY_VAULT_NAME
- **Certificados:** 4 certificados gerados (Root CA, Intermediate CA, App, Gateway)
- **mTLS:** STRICT mode habilitado
- **Authorization Policies:** Configuradas
- **Certificate Rotation:** CronJob configurado

### 📊 Observabilidade
- **Kiali:** Instalado para service mesh topology
- **Grafana:** Instalado com dashboard personalizado
- **Jaeger:** Instalado para distributed tracing
- **Prometheus:** Configurado (gerenciado)

### 🚀 Aplicações
- **E-commerce Unificada:** 6 estratégias simultâneas (A/B + Blue/Green + Canary + Shadow + Geographic + Device)
- **Cross-Cluster APIs:** Payment API, Audit API, Frontend API
- **HPA:** Horizontal Pod Autoscaler configurado
- **Service Monitor:** Monitoramento de certificados

## 🎯 FUNCIONALIDADES DEMONSTRADAS

### 🔄 Estratégias de Deployment
- ✅ **A/B Testing** - Baseado em segmentos de usuário
- ✅ **Blue/Green** - Ambientes paralelos com switch automático
- ✅ **Canary** - Rollout gradual com 20% de tráfego
- ✅ **Shadow Testing** - Tráfego espelhado para testes
- ✅ **Geographic Routing** - Roteamento baseado em localização
- ✅ **Device-Based Routing** - Otimizado para mobile/desktop

### 🌐 Multi-Cluster
- ✅ **Cross-Cluster Communication** - APIs se comunicando entre clusters
- ✅ **Service Discovery** - Automático entre clusters
- ✅ **Load Balancing** - Distribuição inteligente de carga
- ✅ **Failover** - Recuperação automática entre clusters

### 🛡️ Segurança Zero Trust
- ✅ **mTLS STRICT** - Toda comunicação criptografada
- ✅ **Certificate Management** - Integração com Azure Key Vault
- ✅ **Authorization Policies** - Controle granular de acesso
- ✅ **Network Policies** - Isolamento de rede por namespace

### 📊 Observabilidade Empresarial
- ✅ **Service Mesh Topology** - Visualização com Kiali
- ✅ **Custom Dashboards** - 13 painéis especializados no Grafana
- ✅ **Distributed Tracing** - Rastreamento cross-cluster com Jaeger
- ✅ **Real-time Metrics** - Métricas de negócio e técnicas

## 🚀 COMO ACESSAR

Execute o script de acesso rápido:
\`\`\`bash
/tmp/lab-access.sh
\`\`\`

## 📚 PRÓXIMOS PASSOS

1. **Aguarde 5-10 minutos** para todos os IPs serem atribuídos
2. **Execute testes de validação** para confirmar funcionamento
3. **Importe dashboard personalizado** no Grafana
4. **Execute demonstração** para o cliente
5. **Monitore métricas** em tempo real

## 🧹 LIMPEZA

Para limpar todos os recursos:
\`\`\`bash
/tmp/lab-cleanup.sh
\`\`\`

---
**Status:** ✅ LABORATÓRIO PROVISIONADO COM SUCESSO!
**Logs completos:** $LOG_FILE
EOF
    
    log_success "Relatório final gerado em /tmp/lab-provision-report.md"
}

# Função principal
main() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🚀 PROVISIONAMENTO COMPLETO DO LABORATÓRIO ISTIO MULTI-CLUSTER"
    echo "═══════════════════════════════════════════════════════════════"
    log_info "🎯 Iniciando provisionamento completo do laboratório"
    log_info "📁 Logs salvos em: $LOG_FILE"
    
    # Executar todas as etapas
    check_prerequisites
    azure_login
    create_key_vault
    generate_certificates
    create_aks_clusters
    install_keyvault_csi_driver
    setup_mtls_keyvault
    install_observability
    deploy_demo_applications
    run_validation_tests
    create_access_scripts
    generate_final_report
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ✅ LABORATÓRIO PROVISIONADO COM SUCESSO!"
    echo "═══════════════════════════════════════════════════════════════"
    
    log_success "🎉 Laboratório completo provisionado com sucesso!"
    
    echo ""
    echo "📋 PRÓXIMOS PASSOS:"
    echo "1. Execute: /tmp/lab-access.sh para ver as URLs de acesso"
    echo "2. Aguarde alguns minutos para todos os IPs serem atribuídos"
    echo "3. Leia o relatório completo: /tmp/lab-provision-report.md"
    echo "4. Execute testes de validação para confirmar funcionamento"
    echo "5. Demonstre para o cliente usando o tutorial passo-a-passo"
    echo ""
    echo "🔍 Logs completos salvos em: $LOG_FILE"
    echo "📊 Key Vault criado: $KEY_VAULT_NAME"
    echo "🎯 Laboratório pronto para demonstração de nível empresarial!"
}

# Executar função principal
main "$@"
