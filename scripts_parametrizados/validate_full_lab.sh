#!/bin/bash

#====================================================================
# SCRIPT DE VALIDAÇÃO UNIVERSAL DO LABORATÓRIO AKS + ISTIO + FLAGGER
#====================================================================
# Este script valida completamente a infraestrutura multi-cluster
# incluindo AKS, Istio, Flagger e aplicações implementadas
#
# Autor: Sistema de Validação Automatizada
# Data: $(date +%Y-%m-%d)
# Versão: 2.0
#====================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASSED_TESTS++))
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
    ((FAILED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Função para testar conectividade
test_connectivity() {
    local resource=$1
    local context=$2
    ((TOTAL_TESTS++))
    
    if kubectl --context="$context" get "$resource" &>/dev/null; then
        log_success "Conectividade com $resource no contexto $context"
        return 0
    else
        log_error "Falha na conectividade com $resource no contexto $context"
        return 1
    fi
}

# Função para validar deployments
validate_deployment() {
    local deployment=$1
    local namespace=$2
    local context=$3
    ((TOTAL_TESTS++))
    
    local ready=$(kubectl --context="$context" get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired=$(kubectl --context="$context" get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    
    if [[ "$ready" == "$desired" ]] && [[ "$ready" != "0" ]]; then
        log_success "Deployment $deployment está pronto ($ready/$desired) no namespace $namespace"
        return 0
    else
        log_error "Deployment $deployment não está pronto ($ready/$desired) no namespace $namespace"
        return 1
    fi
}

# Função para validar pods
validate_pods() {
    local namespace=$1
    local context=$2
    local label_selector=${3:-""}
    ((TOTAL_TESTS++))
    
    local selector_arg=""
    if [[ -n "$label_selector" ]]; then
        selector_arg="-l $label_selector"
    fi
    
    local not_ready=$(kubectl --context="$context" get pods -n "$namespace" $selector_arg --no-headers 2>/dev/null | grep -v "Running\|Completed" | wc -l)
    
    if [[ "$not_ready" == "0" ]]; then
        log_success "Todos os pods estão executando no namespace $namespace"
        return 0
    else
        log_error "$not_ready pods não estão executando no namespace $namespace"
        kubectl --context="$context" get pods -n "$namespace" $selector_arg --no-headers | grep -v "Running\|Completed" | head -5
        return 1
    fi
}

# Função para validar serviços
validate_service() {
    local service=$1
    local namespace=$2
    local context=$3
    ((TOTAL_TESTS++))
    
    if kubectl --context="$context" get service "$service" -n "$namespace" &>/dev/null; then
        local endpoints=$(kubectl --context="$context" get endpoints "$service" -n "$namespace" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
        if [[ "$endpoints" -gt 0 ]]; then
            log_success "Serviço $service tem $endpoints endpoints ativos"
            return 0
        else
            log_error "Serviço $service não tem endpoints ativos"
            return 1
        fi
    else
        log_error "Serviço $service não encontrado no namespace $namespace"
        return 1
    fi
}

# Função principal de validação
main_validation() {
    log "=== INICIANDO VALIDAÇÃO COMPLETA DO LABORATÓRIO ==="
    
    # Detectar contextos disponíveis
    log_info "Detectando contextos Kubernetes disponíveis..."
    local contexts=$(kubectl config get-contexts -o name 2>/dev/null || echo "")
    
    if [[ -z "$contexts" ]]; then
        log_error "Nenhum contexto Kubernetes encontrado"
        return 1
    fi
    
    echo "Contextos encontrados:"
    for ctx in $contexts; do
        echo "  - $ctx"
    done
    
    # Validação por contexto
    for context in $contexts; do
        log "\n=== VALIDANDO CONTEXTO: $context ==="
        
        # Testar conectividade básica
        test_connectivity "nodes" "$context" || continue
        test_connectivity "namespaces" "$context" || continue
        
        # Listar namespaces
        log_info "Namespaces encontrados:"
        kubectl --context="$context" get namespaces --no-headers -o custom-columns=":metadata.name" 2>/dev/null | head -10
        
        # Validar namespaces críticos
        local critical_namespaces=("default" "kube-system" "istio-system")
        
        for ns in "${critical_namespaces[@]}"; do
            if kubectl --context="$context" get namespace "$ns" &>/dev/null; then
                log_success "Namespace $ns existe"
                validate_pods "$ns" "$context"
            else
                log_warning "Namespace $ns não encontrado (pode ser normal)"
            fi
        done
        
        # Validar Istio se presente
        if kubectl --context="$context" get namespace istio-system &>/dev/null; then
            log "\n--- VALIDAÇÃO DO ISTIO ---"
            
            # Componentes do Istio
            local istio_components=("istiod" "istio-proxy")
            
            validate_deployment "istiod" "istio-system" "$context"
            validate_service "istiod" "istio-system" "$context"
            validate_pods "istio-system" "$context" "app=istiod"
            
            # Gateway e VirtualService
            ((TOTAL_TESTS++))
            local gateways=$(kubectl --context="$context" get gateway --all-namespaces --no-headers 2>/dev/null | wc -l)
            if [[ "$gateways" -gt 0 ]]; then
                log_success "$gateways Gateway(s) encontrado(s)"
            else
                log_warning "Nenhum Gateway encontrado"
            fi
            
            ((TOTAL_TESTS++))
            local vs=$(kubectl --context="$context" get virtualservice --all-namespaces --no-headers 2>/dev/null | wc -l)
            if [[ "$vs" -gt 0 ]]; then
                log_success "$vs VirtualService(s) encontrado(s)"
            else
                log_warning "Nenhum VirtualService encontrado"
            fi
        fi
        
        # Validar Flagger se presente
        if kubectl --context="$context" get crd canaries.flagger.app &>/dev/null; then
            log "\n--- VALIDAÇÃO DO FLAGGER ---"
            
            validate_deployment "flagger" "flagger-system" "$context" 2>/dev/null || 
            validate_deployment "flagger" "istio-system" "$context" 2>/dev/null || 
            log_warning "Deployment do Flagger não encontrado nos namespaces esperados"
            
            ((TOTAL_TESTS++))
            local canaries=$(kubectl --context="$context" get canary --all-namespaces --no-headers 2>/dev/null | wc -l)
            if [[ "$canaries" -gt 0 ]]; then
                log_success "$canaries Canary deployment(s) encontrado(s)"
            else
                log_warning "Nenhum Canary deployment encontrado"
            fi
        fi
        
        # Validar aplicações comuns
        log "\n--- VALIDAÇÃO DE APLICAÇÕES ---"
        
        # Procurar por deployments de aplicação
        local app_deployments=$(kubectl --context="$context" get deployments --all-namespaces --no-headers 2>/dev/null | grep -v "kube-system\|istio-system\|flagger-system" | head -5)
        
        if [[ -n "$app_deployments" ]]; then
            log_info "Deployments de aplicação encontrados:"
            echo "$app_deployments" | while read -r namespace name ready uptodate available age; do
                validate_deployment "$name" "$namespace" "$context"
            done
        else
            log_warning "Nenhum deployment de aplicação encontrado"
        fi
        
        # Testar conectividade de rede básica
        log "\n--- TESTE DE CONECTIVIDADE ---"
        
        ((TOTAL_TESTS++))
        if kubectl --context="$context" run test-pod --image=busybox --rm -it --restart=Never --command -- nslookup kubernetes.default &>/dev/null; then
            log_success "DNS interno funcionando"
        else
            log_warning "Teste de DNS interno falhou ou não pôde ser executado"
        fi
    done
    
    # Relatório final
    log "\n=== RELATÓRIO FINAL DA VALIDAÇÃO ==="
    log_info "Total de testes executados: $TOTAL_TESTS"
    log_success "Testes aprovados: $PASSED_TESTS"
    log_error "Testes falharam: $FAILED_TESTS"
    
    local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    log_info "Taxa de sucesso: ${success_rate}%"
    
    if [[ "$success_rate" -ge 80 ]]; then
        log_success "\n🎉 LABORATÓRIO VALIDADO COM SUCESSO! 🎉"
        log_success "A infraestrutura está funcionando adequadamente."
        return 0
    elif [[ "$success_rate" -ge 60 ]]; then
        log_warning "\n⚠️  LABORATÓRIO PARCIALMENTE FUNCIONAL"
        log_warning "Alguns componentes precisam de atenção."
        return 1
    else
        log_error "\n❌ LABORATÓRIO COM PROBLEMAS CRÍTICOS"
        log_error "Múltiplos componentes falharam na validação."
        return 1
    fi
}

# Função de ajuda
show_help() {
    cat << EOF
Script de Validação Universal - Laboratório AKS + Istio + Flagger

USO:
    $0 [opções]

OPÇÕES:
    -h, --help     Mostra esta ajuda
    -v, --verbose  Modo verboso (padrão)
    -q, --quiet    Modo silencioso
    --summary      Apenas relatório final

EXEMPLOS:
    $0                    # Validação completa
    $0 --summary          # Apenas relatório final
    $0 --quiet            # Sem detalhes extras

Este script valida:
- Conectividade com clusters Kubernetes
- Status dos namespaces críticos
- Componentes do Istio (se instalado)
- Deployments do Flagger (se instalado)
- Status das aplicações
- Conectividade de rede básica

EOF
}

# Processamento dos argumentos
VERBOSE=true
QUIET=false
SUMMARY_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            QUIET=false
            shift
            ;;
        -q|--quiet)
            QUIET=true
            VERBOSE=false
            shift
            ;;
        --summary)
            SUMMARY_ONLY=true
            shift
            ;;
        *)
            log_error "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
done

# Configurar nível de log baseado nas opções
if [[ "$QUIET" == "true" ]]; then
    exec 1>/dev/null
fi

# Verificar pré-requisitos
log "Verificando pré-requisitos..."

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl não está instalado ou não está no PATH"
    exit 1
fi

log_success "kubectl encontrado: $(kubectl version --client --short 2>/dev/null || echo 'versão não detectada')"

# Executar validação principal
if main_validation; then
    exit 0
else
    exit 1
fi