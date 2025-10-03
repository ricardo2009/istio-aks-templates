#!/bin/bash

# 🔧 Script para criar os clusters AKS corretamente
# Corrige os problemas encontrados no script principal

set -euo pipefail

# 🎨 Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 🔧 Configurações
RG_MAIN="lab-istio"
RG_NETWORKING="rg-istio-networking"
LOCATION="westus3"
ACR_NAME="acristiolab"
LAW_NAME="law-istio-lab"

# Obter IDs dos recursos necessários
VNET_NAME="vnet-istio-lab"
SUBNET1_NAME="snet-cluster1"
SUBNET2_NAME="snet-cluster2"

log_info "🔍 Obtendo IDs dos recursos necessários..."

# Obter ID da subnet 1
SUBNET1_ID=$(az network vnet subnet show \
    --resource-group "$RG_NETWORKING" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET1_NAME" \
    --query id -o tsv)

log_info "Subnet 1 ID: $SUBNET1_ID"

# Obter ID da subnet 2
SUBNET2_ID=$(az network vnet subnet show \
    --resource-group "$RG_NETWORKING" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET2_NAME" \
    --query id -o tsv)

log_info "Subnet 2 ID: $SUBNET2_ID"

# Obter ID do Log Analytics Workspace
LAW_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RG_MAIN" \
    --workspace-name "$LAW_NAME" \
    --query id -o tsv)

log_info "Log Analytics Workspace ID: $LAW_ID"

# 🏗️ Criar Cluster 1 (Primary)
log_info "🏗️ Criando AKS Cluster Primary..."

if az aks show --resource-group "$RG_MAIN" --name "aks-istio-primary" &>/dev/null; then
    log_info "Cluster aks-istio-primary já existe"
else
    log_info "Criando cluster aks-istio-primary (15-20 minutos)..."
    
    az aks create \
        --resource-group "$RG_MAIN" \
        --name "aks-istio-primary" \
        --location "$LOCATION" \
        --kubernetes-version "1.31.2" \
        --node-count 3 \
        --node-vm-size "Standard_D2s_v3" \
        --vnet-subnet-id "$SUBNET1_ID" \
        --enable-addons monitoring \
        --workspace-resource-id "$LAW_ID" \
        --enable-managed-identity \
        --attach-acr "$ACR_NAME" \
        --network-plugin azure \
        --network-policy azure \
        --service-cidr "172.16.0.0/16" \
        --dns-service-ip "172.16.0.10" \
        --ssh-access disabled \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 5 \
        --tags Environment=lab Project=istio-service-mesh CreatedBy=automation \
        --no-wait
    
    log_success "Criação do cluster aks-istio-primary iniciada"
fi

# 🏗️ Criar Cluster 2 (Secondary)
log_info "🏗️ Criando AKS Cluster Secondary..."

if az aks show --resource-group "$RG_MAIN" --name "aks-istio-secondary" &>/dev/null; then
    log_info "Cluster aks-istio-secondary já existe"
else
    log_info "Criando cluster aks-istio-secondary (15-20 minutos)..."
    
    az aks create \
        --resource-group "$RG_MAIN" \
        --name "aks-istio-secondary" \
        --location "$LOCATION" \
        --kubernetes-version "1.31.2" \
        --node-count 3 \
        --node-vm-size "Standard_D2s_v3" \
        --vnet-subnet-id "$SUBNET2_ID" \
        --enable-addons monitoring \
        --workspace-resource-id "$LAW_ID" \
        --enable-managed-identity \
        --attach-acr "$ACR_NAME" \
        --network-plugin azure \
        --network-policy azure \
        --service-cidr "172.17.0.0/16" \
        --dns-service-ip "172.17.0.10" \
        --ssh-access disabled \
        --enable-cluster-autoscaler \
        --min-count 1 \
        --max-count 5 \
        --tags Environment=lab Project=istio-service-mesh CreatedBy=automation \
        --no-wait
    
    log_success "Criação do cluster aks-istio-secondary iniciada"
fi

# 📊 Monitorar status dos clusters
log_info "📊 Monitorando status dos clusters..."

check_cluster_status() {
    local cluster_name=$1
    local state=$(az aks show --resource-group "$RG_MAIN" --name "$cluster_name" --query "provisioningState" -o tsv 2>/dev/null || echo "NotFound")
    echo "$state"
}

log_info "Aguardando conclusão da criação dos clusters (isso pode demorar até 20 minutos)..."
log_info "Você pode verificar o progresso com: az aks list --resource-group $RG_MAIN --output table"

# Listar status atual
az aks list --resource-group "$RG_MAIN" --output table

log_success "✅ Script executado com sucesso!"
log_info "💡 Para monitorar o progresso, execute:"
log_info "   az aks list --resource-group $RG_MAIN --output table"
log_info "💡 Para habilitar Istio nos clusters após a criação:"
log_info "   az aks mesh enable --resource-group $RG_MAIN --name aks-istio-primary"
log_info "   az aks mesh enable --resource-group $RG_MAIN --name aks-istio-secondary"