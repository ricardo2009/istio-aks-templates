#!/bin/bash

# 🚀 Script de Setup Inicial dos Recursos Azure
# Cria toda a infraestrutura necessária para o laboratório Istio AKS

set -euo pipefail

# 🎨 Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 📝 Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 🔧 Configuration
AZURE_CLIENT_ID="6f37088c-e465-472f-a2f0-ac45a3fd8e57"
AZURE_TENANT_ID="03ebf151-fe12-4011-976d-d593ff5252a0"
AZURE_SUBSCRIPTION_ID="e8b8de74-8888-4318-a598-fbe78fb29c59"

# Resource Groups
RG_MAIN="lab-istio"
RG_MONITORING="rg-istio-monitoring"
RG_NETWORKING="rg-istio-networking"

# Locations
PRIMARY_LOCATION="westus3"
SECONDARY_LOCATION="eastus2"

# Network Configuration
VNET_NAME="vnet-istio-lab"
VNET_ADDRESS_SPACE="10.20.0.0/16"

SUBNET_CLUSTER1="snet-cluster1"
SUBNET_CLUSTER1_PREFIX="10.20.1.0/24"

SUBNET_CLUSTER2="snet-cluster2"
SUBNET_CLUSTER2_PREFIX="10.20.2.0/24"

SUBNET_SERVICES="snet-services"
SUBNET_SERVICES_PREFIX="10.20.3.0/24"

SUBNET_MONITORING="snet-monitoring"
SUBNET_MONITORING_PREFIX="10.20.4.0/24"

# AKS Configuration
AKS_CLUSTER1="aks-istio-primary"
AKS_CLUSTER2="aks-istio-secondary"
AKS_NODE_COUNT=2
AKS_NODE_SIZE="Standard_D2s_v3"
AKS_K8S_VERSION="1.30.14"

# Monitoring
LAW_NAME="law-istio-lab"
PROMETHEUS_NAME="prom-istio-lab"
GRAFANA_NAME="grafana-istio-lab"

# Container Registry
ACR_NAME="acristiolab"

# 🏁 Start Setup
log_step "🚀 Iniciando setup dos recursos Azure para laboratório Istio AKS"

# 🔐 Login no Azure
log_step "🔐 Fazendo login no Azure..."
if ! az account show &>/dev/null; then
    log_info "Fazendo login no Azure..."
    az login --service-principal \
        --username "$AZURE_CLIENT_ID" \
        --password "$AZURE_CLIENT_SECRET" \
        --tenant "$AZURE_TENANT_ID" || {
        log_error "Falha no login do Azure. Verifique as credenciais."
        exit 1
    }
fi

# Set subscription
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
log_success "Login realizado com sucesso na subscription: $AZURE_SUBSCRIPTION_ID"

# 📊 Verificar quotas
log_step "📊 Verificando quotas disponíveis..."
CORES_AVAILABLE=$(az vm list-usage --location "$PRIMARY_LOCATION" --query "[?name.value=='cores'].currentValue | [0]" -o tsv)
CORES_LIMIT=$(az vm list-usage --location "$PRIMARY_LOCATION" --query "[?name.value=='cores'].limit | [0]" -o tsv)
CORES_NEEDED=8   # 2 nodes * 2 cores * 2 clusters

log_info "Cores disponíveis: $((CORES_LIMIT - CORES_AVAILABLE)) de $CORES_LIMIT"
if [ $((CORES_LIMIT - CORES_AVAILABLE)) -lt $CORES_NEEDED ]; then
    log_error "Quota insuficiente. Necessário: $CORES_NEEDED cores, disponível: $((CORES_LIMIT - CORES_AVAILABLE))"
    exit 1
fi

# 🏗️ Criar Resource Groups
log_step "🏗️ Criando Resource Groups..."

create_resource_group() {
    local rg_name=$1
    local location=$2
    
    if az group show --name "$rg_name" &>/dev/null; then
        log_warning "Resource Group $rg_name já existe"
    else
        log_info "Criando Resource Group: $rg_name"
        az group create --name "$rg_name" --location "$location" --tags \
            Environment=lab \
            Project=istio-service-mesh \
            Owner=tenant-lab \
            CreatedBy=automation
        log_success "Resource Group $rg_name criado"
    fi
}

create_resource_group "$RG_MAIN" "$PRIMARY_LOCATION"
create_resource_group "$RG_MONITORING" "$PRIMARY_LOCATION"
create_resource_group "$RG_NETWORKING" "$PRIMARY_LOCATION"

# 🌐 Criar Virtual Network
log_step "🌐 Criando Virtual Network..."

if az network vnet show --resource-group "$RG_NETWORKING" --name "$VNET_NAME" &>/dev/null; then
    log_warning "VNet $VNET_NAME já existe"
else
    log_info "Criando VNet: $VNET_NAME"
    az network vnet create \
        --resource-group "$RG_NETWORKING" \
        --name "$VNET_NAME" \
        --address-prefixes "$VNET_ADDRESS_SPACE" \
        --location "$PRIMARY_LOCATION" \
        --tags Environment=lab Project=istio-service-mesh
    log_success "VNet $VNET_NAME criada"
fi

# 🔗 Criar Subnets
log_step "🔗 Criando Subnets..."

create_subnet() {
    local subnet_name=$1
    local address_prefix=$2
    
    if az network vnet subnet show --resource-group "$RG_NETWORKING" --vnet-name "$VNET_NAME" --name "$subnet_name" &>/dev/null; then
        log_warning "Subnet $subnet_name já existe"
    else
        log_info "Criando Subnet: $subnet_name"
        az network vnet subnet create \
            --resource-group "$RG_NETWORKING" \
            --vnet-name "$VNET_NAME" \
            --name "$subnet_name" \
            --address-prefixes "$address_prefix"
        log_success "Subnet $subnet_name criada"
    fi
}

create_subnet "$SUBNET_CLUSTER1" "$SUBNET_CLUSTER1_PREFIX"
create_subnet "$SUBNET_CLUSTER2" "$SUBNET_CLUSTER2_PREFIX"
create_subnet "$SUBNET_SERVICES" "$SUBNET_SERVICES_PREFIX"
create_subnet "$SUBNET_MONITORING" "$SUBNET_MONITORING_PREFIX"

# 📊 Criar Log Analytics Workspace
log_step "📊 Criando Log Analytics Workspace..."

if az monitor log-analytics workspace show --resource-group "$RG_MONITORING" --workspace-name "$LAW_NAME" &>/dev/null; then
    log_warning "Log Analytics Workspace $LAW_NAME já existe"
else
    log_info "Criando Log Analytics Workspace: $LAW_NAME"
    az monitor log-analytics workspace create \
        --resource-group "$RG_MONITORING" \
        --workspace-name "$LAW_NAME" \
        --location "$PRIMARY_LOCATION" \
        --retention-time 30 \
        --tags Environment=lab Project=istio-service-mesh
    log_success "Log Analytics Workspace $LAW_NAME criado"
fi

# 🐳 Criar Azure Container Registry
log_step "🐳 Criando Azure Container Registry..."

if az acr show --name "$ACR_NAME" --resource-group "$RG_MAIN" &>/dev/null; then
    log_warning "ACR $ACR_NAME já existe"
else
    log_info "Criando ACR: $ACR_NAME"
    az acr create \
        --resource-group "$RG_MAIN" \
        --name "$ACR_NAME" \
        --sku Standard \
        --location "$PRIMARY_LOCATION" \
        --admin-enabled true \
        --tags Environment=lab Project=istio-service-mesh
    log_success "ACR $ACR_NAME criado"
fi

# 🏗️ Criar AKS Clusters
log_step "🏗️ Criando AKS Clusters..."

# Get subnet IDs
SUBNET1_ID=$(az network vnet subnet show --resource-group "$RG_NETWORKING" --vnet-name "$VNET_NAME" --name "$SUBNET_CLUSTER1" --query id -o tsv)
SUBNET2_ID=$(az network vnet subnet show --resource-group "$RG_NETWORKING" --vnet-name "$VNET_NAME" --name "$SUBNET_CLUSTER2" --query id -o tsv)
LAW_ID=$(az monitor log-analytics workspace show --resource-group "$RG_MONITORING" --workspace-name "$LAW_NAME" --query id -o tsv)

create_aks_cluster() {
    local cluster_name=$1
    local subnet_id=$2
    local location=$3
    
    if az aks show --resource-group "$RG_MAIN" --name "$cluster_name" &>/dev/null; then
        log_warning "AKS Cluster $cluster_name já existe"
        return
    fi
    
    log_info "Criando AKS Cluster: $cluster_name (isso pode demorar 15-20 minutos)"
    
    az aks create \
        --resource-group "$RG_MAIN" \
        --name "$cluster_name" \
        --location "$location" \
        --kubernetes-version "$AKS_K8S_VERSION" \
        --node-count "$AKS_NODE_COUNT" \
        --node-vm-size "$AKS_NODE_SIZE" \
        --vnet-subnet-id "$subnet_id" \
        --enable-addons monitoring \
        --workspace-resource-id "$LAW_ID" \
        --enable-managed-identity \
        --attach-acr "$ACR_NAME" \
        --network-plugin azure \
        --network-policy azure \
        --service-cidr 172.16.0.0/16 \
        --dns-service-ip 172.16.0.10 \
        --generate-ssh-keys \
        --tags Environment=lab Project=istio-service-mesh CreatedBy=automation
    
    log_success "AKS Cluster $cluster_name criado"
    
    # Enable Istio add-on
    log_info "Habilitando Istio add-on no cluster $cluster_name"
    az aks mesh enable --resource-group "$RG_MAIN" --name "$cluster_name"
    log_success "Istio add-on habilitado no cluster $cluster_name"
}

# Create clusters in parallel (background jobs)
log_info "Iniciando criação dos clusters AKS em paralelo..."
create_aks_cluster "$AKS_CLUSTER1" "$SUBNET1_ID" "$PRIMARY_LOCATION" &
PID1=$!
create_aks_cluster "$AKS_CLUSTER2" "$SUBNET2_ID" "$PRIMARY_LOCATION" &
PID2=$!

# Wait for both clusters to complete
log_info "Aguardando conclusão da criação dos clusters..."
wait $PID1
wait $PID2

# 📊 Criar Azure Monitor for Prometheus
log_step "📊 Configurando Azure Monitor for Prometheus..."

# Create Azure Monitor workspace
if az monitor account show --name "$PROMETHEUS_NAME" --resource-group "$RG_MONITORING" &>/dev/null; then
    log_warning "Azure Monitor workspace $PROMETHEUS_NAME já existe"
else
    log_info "Criando Azure Monitor workspace: $PROMETHEUS_NAME"
    az monitor account create \
        --name "$PROMETHEUS_NAME" \
        --resource-group "$RG_MONITORING" \
        --location "$PRIMARY_LOCATION" \
        --tags Environment=lab Project=istio-service-mesh
    log_success "Azure Monitor workspace $PROMETHEUS_NAME criado"
fi

# Link AKS clusters to Prometheus
link_cluster_to_prometheus() {
    local cluster_name=$1
    
    log_info "Vinculando cluster $cluster_name ao Prometheus"
    az aks update \
        --resource-group "$RG_MAIN" \
        --name "$cluster_name" \
        --enable-azure-monitor-metrics \
        --azure-monitor-workspace-resource-id "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RG_MONITORING/providers/Microsoft.Monitor/accounts/$PROMETHEUS_NAME"
    log_success "Cluster $cluster_name vinculado ao Prometheus"
}

link_cluster_to_prometheus "$AKS_CLUSTER1"
link_cluster_to_prometheus "$AKS_CLUSTER2"

# 🔐 Configurar RBAC
log_step "🔐 Configurando RBAC..."

# Get cluster identities
CLUSTER1_IDENTITY=$(az aks show --resource-group "$RG_MAIN" --name "$AKS_CLUSTER1" --query identity.principalId -o tsv)
CLUSTER2_IDENTITY=$(az aks show --resource-group "$RG_MAIN" --name "$AKS_CLUSTER2" --query identity.principalId -o tsv)

# Assign Network Contributor role to clusters
assign_network_role() {
    local identity=$1
    local cluster_name=$2
    
    log_info "Atribuindo role Network Contributor para $cluster_name"
    az role assignment create \
        --assignee "$identity" \
        --role "Network Contributor" \
        --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RG_NETWORKING"
    log_success "Role atribuída para $cluster_name"
}

assign_network_role "$CLUSTER1_IDENTITY" "$AKS_CLUSTER1"
assign_network_role "$CLUSTER2_IDENTITY" "$AKS_CLUSTER2"

# 🔑 Obter credenciais dos clusters
log_step "🔑 Obtendo credenciais dos clusters..."

az aks get-credentials --resource-group "$RG_MAIN" --name "$AKS_CLUSTER1" --context "$AKS_CLUSTER1" --overwrite-existing
az aks get-credentials --resource-group "$RG_MAIN" --name "$AKS_CLUSTER2" --context "$AKS_CLUSTER2" --overwrite-existing

log_success "Credenciais obtidas para ambos os clusters"

# 🧪 Testar conectividade
log_step "🧪 Testando conectividade dos clusters..."

test_cluster_connectivity() {
    local cluster_name=$1
    
    log_info "Testando conectividade do cluster $cluster_name"
    if kubectl get nodes --context="$cluster_name" &>/dev/null; then
        NODE_COUNT=$(kubectl get nodes --context="$cluster_name" --no-headers | wc -l)
        log_success "Cluster $cluster_name: $NODE_COUNT nodes prontos"
    else
        log_error "Falha na conectividade do cluster $cluster_name"
        return 1
    fi
    
    # Test Istio
    log_info "Verificando Istio no cluster $cluster_name"
    if kubectl get pods -n aks-istio-system --context="$cluster_name" &>/dev/null; then
        ISTIO_PODS=$(kubectl get pods -n aks-istio-system --context="$cluster_name" --no-headers | grep -c Running || echo "0")
        log_success "Cluster $cluster_name: $ISTIO_PODS pods do Istio rodando"
    else
        log_warning "Istio ainda não está pronto no cluster $cluster_name"
    fi
}

test_cluster_connectivity "$AKS_CLUSTER1"
test_cluster_connectivity "$AKS_CLUSTER2"

# 📋 Salvar informações dos recursos
log_step "📋 Salvando informações dos recursos..."

RESOURCE_INFO_FILE="/tmp/azure-resources-info.json"

cat > "$RESOURCE_INFO_FILE" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "azure": {
    "subscription_id": "$AZURE_SUBSCRIPTION_ID",
    "tenant_id": "$AZURE_TENANT_ID",
    "client_id": "$AZURE_CLIENT_ID"
  },
  "resource_groups": {
    "main": "$RG_MAIN",
    "monitoring": "$RG_MONITORING",
    "networking": "$RG_NETWORKING"
  },
  "network": {
    "vnet_name": "$VNET_NAME",
    "vnet_address_space": "$VNET_ADDRESS_SPACE",
    "subnets": {
      "cluster1": {
        "name": "$SUBNET_CLUSTER1",
        "prefix": "$SUBNET_CLUSTER1_PREFIX",
        "id": "$SUBNET1_ID"
      },
      "cluster2": {
        "name": "$SUBNET_CLUSTER2",
        "prefix": "$SUBNET_CLUSTER2_PREFIX",
        "id": "$SUBNET2_ID"
      }
    }
  },
  "clusters": {
    "primary": {
      "name": "$AKS_CLUSTER1",
      "resource_group": "$RG_MAIN",
      "location": "$PRIMARY_LOCATION",
      "identity": "$CLUSTER1_IDENTITY"
    },
    "secondary": {
      "name": "$AKS_CLUSTER2",
      "resource_group": "$RG_MAIN",
      "location": "$PRIMARY_LOCATION",
      "identity": "$CLUSTER2_IDENTITY"
    }
  },
  "monitoring": {
    "log_analytics": "$LAW_NAME",
    "prometheus": "$PROMETHEUS_NAME",
    "log_analytics_id": "$LAW_ID"
  },
  "registry": {
    "name": "$ACR_NAME",
    "resource_group": "$RG_MAIN"
  }
}
EOF

log_success "Informações dos recursos salvas em: $RESOURCE_INFO_FILE"

# 📊 Resumo final
log_step "📊 Resumo da infraestrutura criada:"
echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                    RECURSOS CRIADOS                        │${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC} Resource Groups: ${GREEN}3${NC} (main, monitoring, networking)     ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Virtual Network: ${GREEN}1${NC} ($VNET_NAME)                      ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Subnets:         ${GREEN}4${NC} (cluster1, cluster2, services, mon) ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} AKS Clusters:    ${GREEN}2${NC} ($AKS_CLUSTER1, $AKS_CLUSTER2)     ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Container Registry: ${GREEN}1${NC} ($ACR_NAME)                    ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Log Analytics:   ${GREEN}1${NC} ($LAW_NAME)                       ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Prometheus:      ${GREEN}1${NC} ($PROMETHEUS_NAME)                ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"

log_success "🎉 Setup da infraestrutura Azure concluído com sucesso!"
log_info "📋 Informações detalhadas salvas em: $RESOURCE_INFO_FILE"
log_info "🔑 Contextos kubectl configurados: $AKS_CLUSTER1, $AKS_CLUSTER2"
log_info "🚀 Pronto para executar o laboratório Istio!"

# 🧹 Cleanup function (commented out for safety)
# Uncomment and run if you need to clean up resources
cleanup_resources() {
    log_warning "🧹 ATENÇÃO: Esta função irá DELETAR TODOS os recursos criados!"
    read -p "Tem certeza que deseja continuar? (digite 'DELETE' para confirmar): " confirm
    
    if [ "$confirm" = "DELETE" ]; then
        log_info "Deletando Resource Groups..."
        az group delete --name "$RG_MAIN" --yes --no-wait
        az group delete --name "$RG_MONITORING" --yes --no-wait
        az group delete --name "$RG_NETWORKING" --yes --no-wait
        log_success "Comando de deleção enviado. Recursos serão removidos em background."
    else
        log_info "Operação cancelada."
    fi
}

# Para executar cleanup: uncomment the line below
# cleanup_resources
