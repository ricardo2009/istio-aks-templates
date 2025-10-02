#!/bin/bash

# 🚀 Script para Criação do Segundo Cluster AKS
# Laboratório Multi-Cluster Istio AKS
# Autor: Especialista em Service Mesh

set -euo pipefail

# 🎨 Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 📋 Configurações do Laboratório
SUBSCRIPTION_ID="f7963a09-275a-4fc0-aa3f-805aa89eb2b7"
RESOURCE_GROUP="rg-aks-labs"
LOCATION="westus3"
VNET_NAME="vnet-labs"
CLUSTER1_NAME="aks-labs"
CLUSTER2_NAME="aks-labs-secondary"
CLUSTER2_SUBNET="aks-cluster2"
ACR_NAME="acrlabs$(date +%s | tail -c 6)"
KEY_VAULT_NAME="kv-labs-$(date +%s | tail -c 6)"

# 🔧 Configurações do Cluster 2
NODE_COUNT=3
NODE_SIZE="Standard_D4s_v3"
KUBERNETES_VERSION="1.32"
MAX_PODS=110

# 📝 Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# 🔍 Função para verificar pré-requisitos
check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    # Verificar se az CLI está instalado
    if ! command -v az &> /dev/null; then
        error "Azure CLI não está instalado. Instale com: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    fi
    
    # Verificar se kubectl está instalado
    if ! command -v kubectl &> /dev/null; then
        warning "kubectl não encontrado. Instalando..."
        az aks install-cli
    fi
    
    # Verificar login no Azure
    if ! az account show &> /dev/null; then
        error "Não está logado no Azure. Execute: az login"
    fi
    
    # Verificar subscription
    CURRENT_SUB=$(az account show --query id -o tsv)
    if [ "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]; then
        log "Definindo subscription correta..."
        az account set --subscription "$SUBSCRIPTION_ID"
    fi
    
    success "Pré-requisitos verificados"
}

# 🏗️ Função para verificar recursos existentes
check_existing_resources() {
    log "Verificando recursos existentes..."
    
    # Verificar Resource Group
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        error "Resource Group '$RESOURCE_GROUP' não encontrado"
    fi
    
    # Verificar VNet
    if ! az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" &> /dev/null; then
        error "VNet '$VNET_NAME' não encontrada"
    fi
    
    # Verificar Cluster 1
    if ! az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER1_NAME" &> /dev/null; then
        error "Cluster primário '$CLUSTER1_NAME' não encontrado"
    fi
    
    # Verificar se Cluster 2 já existe
    if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER2_NAME" &> /dev/null; then
        warning "Cluster '$CLUSTER2_NAME' já existe. Pulando criação..."
        return 1
    fi
    
    success "Verificação de recursos concluída"
    return 0
}

# 🔑 Função para criar Azure Container Registry
create_acr() {
    log "Criando Azure Container Registry..."
    
    if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        info "ACR '$ACR_NAME' já existe"
        return 0
    fi
    
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACR_NAME" \
        --sku Standard \
        --location "$LOCATION" \
        --admin-enabled true
    
    success "ACR '$ACR_NAME' criado com sucesso"
}

# 🔐 Função para criar Azure Key Vault
create_key_vault() {
    log "Criando Azure Key Vault..."
    
    if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        info "Key Vault '$KEY_VAULT_NAME' já existe"
        return 0
    fi
    
    az keyvault create \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku standard \
        --enable-rbac-authorization true
    
    success "Key Vault '$KEY_VAULT_NAME' criado com sucesso"
}

# 🌐 Função para obter informações da subnet
get_subnet_info() {
    log "Obtendo informações da subnet..."
    
    SUBNET_ID=$(az network vnet subnet show \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$CLUSTER2_SUBNET" \
        --query id -o tsv)
    
    if [ -z "$SUBNET_ID" ]; then
        error "Subnet '$CLUSTER2_SUBNET' não encontrada"
    fi
    
    info "Subnet ID: $SUBNET_ID"
}

# 🏗️ Função para criar o segundo cluster AKS
create_cluster2() {
    log "Criando segundo cluster AKS: $CLUSTER2_NAME"
    
    # Obter versão mais recente do Kubernetes
    K8S_VERSION=$(az aks get-versions \
        --location "$LOCATION" \
        --query "orchestrators[?orchestratorVersion=='$KUBERNETES_VERSION'].orchestratorVersion" \
        -o tsv | head -1)
    
    if [ -z "$K8S_VERSION" ]; then
        warning "Versão $KUBERNETES_VERSION não disponível. Usando versão padrão..."
        K8S_VERSION=$(az aks get-versions \
            --location "$LOCATION" \
            --query "orchestrators[-1].orchestratorVersion" \
            -o tsv)
    fi
    
    info "Usando Kubernetes versão: $K8S_VERSION"
    
    # Criar o cluster
    az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER2_NAME" \
        --location "$LOCATION" \
        --kubernetes-version "$K8S_VERSION" \
        --node-count "$NODE_COUNT" \
        --node-vm-size "$NODE_SIZE" \
        --max-pods "$MAX_PODS" \
        --network-plugin azure \
        --network-policy azure \
        --vnet-subnet-id "$SUBNET_ID" \
        --enable-managed-identity \
        --enable-addons monitoring \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 5 \
        --zones 1 2 3 \
        --tier standard \
        --generate-ssh-keys \
        --yes
    
    success "Cluster '$CLUSTER2_NAME' criado com sucesso"
}

# 🔧 Função para habilitar add-ons do Istio
enable_istio_addon() {
    log "Habilitando Istio add-on no cluster $CLUSTER2_NAME..."
    
    # Habilitar Istio
    az aks mesh enable \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER2_NAME"
    
    success "Istio add-on habilitado"
}

# 📊 Função para habilitar monitoramento
enable_monitoring() {
    log "Configurando monitoramento avançado..."
    
    # Habilitar Azure Monitor for Containers
    az aks enable-addons \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER2_NAME" \
        --addons monitoring
    
    # Habilitar Prometheus metrics
    az aks update \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER2_NAME" \
        --enable-azure-monitor-metrics
    
    success "Monitoramento configurado"
}

# 🔗 Função para configurar integração com ACR
configure_acr_integration() {
    log "Configurando integração com ACR..."
    
    az aks update \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER2_NAME" \
        --attach-acr "$ACR_NAME"
    
    success "Integração com ACR configurada"
}

# 📋 Função para obter credenciais do cluster
get_cluster_credentials() {
    log "Obtendo credenciais do cluster..."
    
    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER2_NAME" \
        --overwrite-existing \
        --context "$CLUSTER2_NAME"
    
    success "Credenciais obtidas"
}

# 🧪 Função para validar o cluster
validate_cluster() {
    log "Validando cluster..."
    
    # Verificar nodes
    kubectl get nodes --context="$CLUSTER2_NAME"
    
    # Verificar Istio
    kubectl get pods -n aks-istio-system --context="$CLUSTER2_NAME"
    
    # Verificar namespaces
    kubectl get namespaces --context="$CLUSTER2_NAME"
    
    success "Cluster validado com sucesso"
}

# 📄 Função para gerar relatório
generate_report() {
    log "Gerando relatório de recursos criados..."
    
    REPORT_FILE="/tmp/cluster2-resources-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "subscription": "$SUBSCRIPTION_ID",
  "resourceGroup": "$RESOURCE_GROUP",
  "location": "$LOCATION",
  "cluster": {
    "name": "$CLUSTER2_NAME",
    "kubernetesVersion": "$K8S_VERSION",
    "nodeCount": $NODE_COUNT,
    "nodeSize": "$NODE_SIZE",
    "subnetId": "$SUBNET_ID"
  },
  "acr": {
    "name": "$ACR_NAME",
    "loginServer": "$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)"
  },
  "keyVault": {
    "name": "$KEY_VAULT_NAME",
    "vaultUri": "$(az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query properties.vaultUri -o tsv)"
  },
  "istio": {
    "enabled": true,
    "version": "managed"
  },
  "monitoring": {
    "azureMonitor": true,
    "prometheus": true
  }
}
EOF
    
    success "Relatório gerado: $REPORT_FILE"
    cat "$REPORT_FILE"
}

# 🎯 Função principal
main() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                🚀 LABORATÓRIO MULTI-CLUSTER ISTIO AKS        ║"
    echo "║                     Criação do Segundo Cluster               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_prerequisites
    
    if check_existing_resources; then
        get_subnet_info
        create_acr
        create_key_vault
        create_cluster2
        enable_istio_addon
        enable_monitoring
        configure_acr_integration
        get_cluster_credentials
        validate_cluster
        generate_report
        
        echo -e "${GREEN}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    ✅ CLUSTER CRIADO COM SUCESSO!            ║"
        echo "║                                                              ║"
        echo "║  Próximos passos:                                            ║"
        echo "║  1. Execute: ./02-setup-cross-cluster.sh                    ║"
        echo "║  2. Deploy da aplicação: ./03-deploy-application.sh         ║"
        echo "║  3. Configure observabilidade: ./04-setup-monitoring.sh     ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
    else
        info "Cluster já existe. Prosseguindo para próxima etapa..."
    fi
}

# 🚀 Executar script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
