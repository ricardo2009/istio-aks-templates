#!/bin/bash

# 🧹 Script de Limpeza Completa dos Clusters
# Remove todos os recursos criados nos clusters para começar do zero

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

# 🔧 Configurações
CLUSTER_PRIMARY="aks-istio-primary"
CLUSTER_SECONDARY="aks-istio-secondary"

# Lista de namespaces para limpar
NAMESPACES_TO_CLEAN=(
    "test-app"
    "cross-cluster-demo"
    "no-istio-demo"
    "ecommerce-demo"
    "canary-demo"
    "ab-test-demo"
    "bluegreen-demo"
)

# 🏁 Início da limpeza
log_step "🧹 Iniciando limpeza completa dos clusters"

echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                    LIMPEZA COMPLETA                         │${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC} Esta operação irá remover TODOS os recursos criados       ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} nos clusters para permitir um restart completo do lab.    ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                             ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Clusters afetados:                                         ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} - ${CLUSTER_PRIMARY}                              ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} - ${CLUSTER_SECONDARY}                            ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"

read -p "Deseja continuar com a limpeza? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Limpeza cancelada pelo usuário"
    exit 0
fi

# 🗑️ Função para limpar namespace
cleanup_namespace() {
    local cluster="$1"
    local namespace="$2"
    
    log_info "Limpando namespace '$namespace' no cluster '$cluster'..."
    
    # Verificar se o namespace existe
    if kubectl get namespace "$namespace" --context="$cluster" &>/dev/null; then
        # Remover finalizers de recursos Istio se existirem
        kubectl patch virtualservices --all -n "$namespace" --context="$cluster" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        kubectl patch destinationrules --all -n "$namespace" --context="$cluster" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        kubectl patch gateways --all -n "$namespace" --context="$cluster" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        kubectl patch peerauthentications --all -n "$namespace" --context="$cluster" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        kubectl patch authorizationpolicies --all -n "$namespace" --context="$cluster" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        
        # Forçar remoção de pods com grace period 0
        kubectl delete pods --all -n "$namespace" --context="$cluster" --force --grace-period=0 2>/dev/null || true
        
        # Remover o namespace
        kubectl delete namespace "$namespace" --context="$cluster" --timeout=60s 2>/dev/null || true
        
        # Aguardar remoção completa
        local timeout=60
        local count=0
        while kubectl get namespace "$namespace" --context="$cluster" &>/dev/null && [ $count -lt $timeout ]; do
            sleep 1
            count=$((count + 1))
        done
        
        if kubectl get namespace "$namespace" --context="$cluster" &>/dev/null; then
            log_warning "Namespace '$namespace' ainda existe após timeout, forçando remoção..."
            kubectl patch namespace "$namespace" --context="$cluster" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null || true
        else
            log_success "Namespace '$namespace' removido com sucesso do cluster '$cluster'"
        fi
    else
        log_info "Namespace '$namespace' não existe no cluster '$cluster'"
    fi
}

# 🧹 Limpeza do Cluster Primário
log_step "🧹 Limpando Cluster Primário ($CLUSTER_PRIMARY)"

for namespace in "${NAMESPACES_TO_CLEAN[@]}"; do
    cleanup_namespace "$CLUSTER_PRIMARY" "$namespace"
done

# Limpar recursos Istio globais no cluster primário
log_info "Removendo recursos Istio globais do cluster primário..."
kubectl delete gateways --all --all-namespaces --context="$CLUSTER_PRIMARY" 2>/dev/null || true
kubectl delete virtualservices --all --all-namespaces --context="$CLUSTER_PRIMARY" 2>/dev/null || true
kubectl delete destinationrules --all --all-namespaces --context="$CLUSTER_PRIMARY" 2>/dev/null || true
kubectl delete peerauthentications --all --all-namespaces --context="$CLUSTER_PRIMARY" 2>/dev/null || true
kubectl delete authorizationpolicies --all --all-namespaces --context="$CLUSTER_PRIMARY" 2>/dev/null || true

# 🧹 Limpeza do Cluster Secundário
log_step "🧹 Limpando Cluster Secundário ($CLUSTER_SECONDARY)"

for namespace in "${NAMESPACES_TO_CLEAN[@]}"; do
    cleanup_namespace "$CLUSTER_SECONDARY" "$namespace"
done

# Limpar recursos Istio globais no cluster secundário
log_info "Removendo recursos Istio globais do cluster secundário..."
kubectl delete gateways --all --all-namespaces --context="$CLUSTER_SECONDARY" 2>/dev/null || true
kubectl delete virtualservices --all --all-namespaces --context="$CLUSTER_SECONDARY" 2>/dev/null || true
kubectl delete destinationrules --all --all-namespaces --context="$CLUSTER_SECONDARY" 2>/dev/null || true
kubectl delete peerauthentications --all --all-namespaces --context="$CLUSTER_SECONDARY" 2>/dev/null || true
kubectl delete authorizationpolicies --all --all-namespaces --context="$CLUSTER_SECONDARY" 2>/dev/null || true

# 🔍 Verificação final
log_step "🔍 Verificando limpeza completa"

echo -e "\n${CYAN}=== VERIFICAÇÃO CLUSTER PRIMÁRIO ===${NC}"
for namespace in "${NAMESPACES_TO_CLEAN[@]}"; do
    if kubectl get namespace "$namespace" --context="$CLUSTER_PRIMARY" &>/dev/null; then
        log_warning "⚠️ Namespace '$namespace' ainda existe no cluster primário"
    else
        log_success "✅ Namespace '$namespace' removido do cluster primário"
    fi
done

echo -e "\n${CYAN}=== VERIFICAÇÃO CLUSTER SECUNDÁRIO ===${NC}"
for namespace in "${NAMESPACES_TO_CLEAN[@]}"; do
    if kubectl get namespace "$namespace" --context="$CLUSTER_SECONDARY" &>/dev/null; then
        log_warning "⚠️ Namespace '$namespace' ainda existe no cluster secundário"
    else
        log_success "✅ Namespace '$namespace' removido do cluster secundário"
    fi
done

# 📊 Status final dos clusters
log_step "📊 Status final dos clusters"

echo -e "\n${CYAN}=== NAMESPACES RESTANTES - CLUSTER PRIMÁRIO ===${NC}"
kubectl get namespaces --context="$CLUSTER_PRIMARY" | grep -v "kube-\|aks-\|default\|gatekeeper"

echo -e "\n${CYAN}=== NAMESPACES RESTANTES - CLUSTER SECUNDÁRIO ===${NC}"
kubectl get namespaces --context="$CLUSTER_SECONDARY" | grep -v "kube-\|aks-\|default\|gatekeeper"

echo -e "\n${CYAN}=== PODS ISTIO - CLUSTER PRIMÁRIO ===${NC}"
kubectl get pods -n aks-istio-system --context="$CLUSTER_PRIMARY"

echo -e "\n${CYAN}=== PODS ISTIO - CLUSTER SECUNDÁRIO ===${NC}"
kubectl get pods -n aks-istio-system --context="$CLUSTER_SECONDARY"

echo -e "\n${CYAN}=== INGRESS GATEWAYS ===${NC}"
echo "Cluster Primário:"
kubectl get service -n aks-istio-ingress --context="$CLUSTER_PRIMARY" 2>/dev/null || echo "Nenhum serviço encontrado"
echo "Cluster Secundário:"
kubectl get service -n aks-istio-ingress --context="$CLUSTER_SECONDARY" 2>/dev/null || echo "Nenhum serviço encontrado"

# 🧹 Limpar arquivos temporários locais
log_step "🧹 Limpando arquivos temporários locais"

if [ -d "/tmp/istio-test-results" ]; then
    rm -rf /tmp/istio-test-results
    log_success "Diretório de resultados de teste removido"
fi

if [ -f "/tmp/infrastructure-validation-report.json" ]; then
    rm -f /tmp/infrastructure-validation-report.json
    log_success "Relatório de validação removido"
fi

# 📋 Resumo final
log_step "📋 Resumo da Limpeza"

echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                    LIMPEZA CONCLUÍDA                        │${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC} ✅ Todos os namespaces de teste removidos                  ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ✅ Recursos Istio globais limpos                           ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ✅ Arquivos temporários removidos                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} ✅ Clusters prontos para nova execução                     ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                             ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} 🚀 Agora você pode executar o laboratório do zero!        ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"

log_success "🎉 Limpeza completa finalizada! Clusters estão limpos e prontos para nova execução."

echo -e "\n${GREEN}Próximos passos:${NC}"
echo -e "1. Execute: ${BLUE}./lab/scripts/01-validate-infrastructure.sh${NC}"
echo -e "2. Execute: ${BLUE}./lab/scripts/03-deploy-demo-applications.sh${NC}"
echo -e "3. Execute: ${BLUE}./lab/scripts/04-comprehensive-demo.sh${NC}"
