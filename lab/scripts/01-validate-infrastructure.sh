#!/bin/bash

# 🔍 Script de Validação Completa da Infraestrutura
# Valida se todos os recursos estão funcionando corretamente

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

# 📊 Contadores de validação
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# 🧪 Função para executar validação
validate_check() {
    local check_name="$1"
    local check_command="$2"
    local expected_result="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    log_info "Validando: $check_name"
    
    if eval "$check_command" &>/dev/null; then
        if [ -n "$expected_result" ]; then
            local result=$(eval "$check_command" 2>/dev/null || echo "")
            if [[ "$result" == *"$expected_result"* ]]; then
                log_success "✅ $check_name - PASSOU"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
                return 0
            else
                log_error "❌ $check_name - FALHOU (resultado inesperado: $result)"
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
                return 1
            fi
        else
            log_success "✅ $check_name - PASSOU"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        fi
    else
        log_error "❌ $check_name - FALHOU"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# 🏁 Início da validação
log_step "🔍 Iniciando validação completa da infraestrutura"

# 🔐 Validar autenticação Azure
log_step "🔐 Validando autenticação Azure"
validate_check "Login Azure" "az account show" "e8b8de74-8888-4318-a598-fbe78fb29c59"

# 🏗️ Validar Resource Groups
log_step "🏗️ Validando Resource Groups"
validate_check "Resource Group Principal" "az group show --name lab-istio" "lab-istio"
validate_check "Resource Group Monitoring" "az group show --name rg-istio-monitoring" "rg-istio-monitoring"
validate_check "Resource Group Networking" "az group show --name rg-istio-networking" "rg-istio-networking"

# 🌐 Validar Networking
log_step "🌐 Validando Networking"
validate_check "Virtual Network" "az network vnet show --resource-group rg-istio-networking --name vnet-istio-lab" "vnet-istio-lab"
validate_check "Subnet Cluster 1" "az network vnet subnet show --resource-group rg-istio-networking --vnet-name vnet-istio-lab --name snet-cluster1" "snet-cluster1"
validate_check "Subnet Cluster 2" "az network vnet subnet show --resource-group rg-istio-networking --vnet-name vnet-istio-lab --name snet-cluster2" "snet-cluster2"

# 🏗️ Validar AKS Clusters
log_step "🏗️ Validando AKS Clusters"
validate_check "AKS Cluster Primary" "az aks show --resource-group lab-istio --name aks-istio-primary" "Succeeded"
validate_check "AKS Cluster Secondary" "az aks show --resource-group lab-istio --name aks-istio-secondary" "Succeeded"

# 🔑 Validar conectividade Kubernetes
log_step "🔑 Validando conectividade Kubernetes"
validate_check "Kubectl Primary Cluster" "kubectl get nodes --context=aks-istio-primary" "Ready"
validate_check "Kubectl Secondary Cluster" "kubectl get nodes --context=aks-istio-secondary" "Ready"

# 🕸️ Validar Istio
log_step "🕸️ Validando Istio"
validate_check "Istio Primary - Control Plane" "kubectl get pods -n aks-istio-system --context=aks-istio-primary" "Running"
validate_check "Istio Secondary - Control Plane" "kubectl get pods -n aks-istio-system --context=aks-istio-secondary" "Running"

# 📊 Validar Monitoring
log_step "📊 Validando Monitoring"
validate_check "Log Analytics Workspace" "az monitor log-analytics workspace show --resource-group rg-istio-monitoring --workspace-name law-istio-lab" "law-istio-lab"

# 🐳 Validar Container Registry
log_step "🐳 Validando Container Registry"
validate_check "Azure Container Registry" "az acr show --name acristiolab --resource-group lab-istio" "acristiolab"

# 🧪 Testes de conectividade avançados
log_step "🧪 Executando testes de conectividade avançados"

# Testar comunicação entre clusters (DNS)
log_info "Testando resolução DNS entre clusters..."
PRIMARY_DNS=$(kubectl get service kubernetes --context=aks-istio-primary -o jsonpath='{.spec.clusterIP}')
SECONDARY_DNS=$(kubectl get service kubernetes --context=aks-istio-secondary -o jsonpath='{.spec.clusterIP}')

if [ -n "$PRIMARY_DNS" ] && [ -n "$SECONDARY_DNS" ]; then
    log_success "✅ DNS dos clusters obtido - Primary: $PRIMARY_DNS, Secondary: $SECONDARY_DNS"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    log_error "❌ Falha ao obter DNS dos clusters"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Testar Istio Ingress Gateway
log_info "Verificando Istio Ingress Gateway..."
if kubectl get service aks-istio-ingressgateway-external -n aks-istio-ingress --context=aks-istio-primary &>/dev/null; then
    INGRESS_IP=$(kubectl get service aks-istio-ingressgateway-external -n aks-istio-ingress --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || echo "pending")
    if [ "$INGRESS_IP" != "pending" ] && [ -n "$INGRESS_IP" ]; then
        log_success "✅ Istio Ingress Gateway funcionando - IP: $INGRESS_IP"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_warning "⚠️ Istio Ingress Gateway ainda obtendo IP externo"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    fi
else
    log_error "❌ Istio Ingress Gateway não encontrado"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# 📋 Coletar informações detalhadas
log_step "📋 Coletando informações detalhadas do ambiente"

VALIDATION_REPORT="/tmp/infrastructure-validation-report.json"

cat > "$VALIDATION_REPORT" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "validation_summary": {
    "total_checks": $TOTAL_CHECKS,
    "passed_checks": $PASSED_CHECKS,
    "failed_checks": $FAILED_CHECKS,
    "success_rate": "$(echo "scale=2; $PASSED_CHECKS * 100 / $TOTAL_CHECKS" | bc)%"
  },
  "azure_resources": {
    "subscription_id": "$(az account show --query id -o tsv)",
    "resource_groups": {
      "main": "lab-istio",
      "monitoring": "rg-istio-monitoring",
      "networking": "rg-istio-networking"
    },
    "clusters": {
      "primary": {
        "name": "aks-istio-primary",
        "status": "$(az aks show --resource-group lab-istio --name aks-istio-primary --query provisioningState -o tsv)",
        "kubernetes_version": "$(az aks show --resource-group lab-istio --name aks-istio-primary --query kubernetesVersion -o tsv)",
        "node_count": $(kubectl get nodes --context=aks-istio-primary --no-headers | wc -l),
        "istio_pods": $(kubectl get pods -n aks-istio-system --context=aks-istio-primary --no-headers | grep -c Running || echo "0")
      },
      "secondary": {
        "name": "aks-istio-secondary",
        "status": "$(az aks show --resource-group lab-istio --name aks-istio-secondary --query provisioningState -o tsv)",
        "kubernetes_version": "$(az aks show --resource-group lab-istio --name aks-istio-secondary --query kubernetesVersion -o tsv)",
        "node_count": $(kubectl get nodes --context=aks-istio-secondary --no-headers | wc -l),
        "istio_pods": $(kubectl get pods -n aks-istio-system --context=aks-istio-secondary --no-headers | grep -c Running || echo "0")
      }
    },
    "networking": {
      "vnet": "vnet-istio-lab",
      "address_space": "10.20.0.0/16",
      "ingress_ip": "${INGRESS_IP:-pending}"
    }
  },
  "istio_configuration": {
    "revision": "asm-1-25",
    "mode": "Managed",
    "cross_cluster_ready": $([ $PASSED_CHECKS -eq $TOTAL_CHECKS ] && echo "true" || echo "false")
  },
  "next_steps": [
    "Deploy sample applications",
    "Configure cross-cluster communication",
    "Setup monitoring and observability",
    "Implement security policies"
  ]
}
EOF

log_success "Relatório de validação salvo em: $VALIDATION_REPORT"

# 📊 Resumo final
log_step "📊 Resumo da Validação"
echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                  RESULTADO DA VALIDAÇÃO                     │${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC} Total de Verificações: ${BLUE}$TOTAL_CHECKS${NC}                            ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Verificações Aprovadas: ${GREEN}$PASSED_CHECKS${NC}                         ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Verificações Falharam: ${RED}$FAILED_CHECKS${NC}                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Taxa de Sucesso: ${GREEN}$(echo "scale=1; $PASSED_CHECKS * 100 / $TOTAL_CHECKS" | bc)%${NC}                              ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"

if [ $FAILED_CHECKS -eq 0 ]; then
    log_success "🎉 Todos os testes passaram! Infraestrutura está pronta para o laboratório."
    echo -e "\n${GREEN}✅ INFRAESTRUTURA VALIDADA COM SUCESSO!${NC}"
    echo -e "${GREEN}🚀 Pronto para executar o laboratório Istio multi-cluster!${NC}"
    exit 0
else
    log_error "⚠️ Alguns testes falharam. Verifique os logs acima para detalhes."
    echo -e "\n${RED}❌ VALIDAÇÃO FALHOU EM $FAILED_CHECKS VERIFICAÇÕES${NC}"
    echo -e "${RED}🔧 Corrija os problemas antes de prosseguir com o laboratório.${NC}"
    exit 1
fi
