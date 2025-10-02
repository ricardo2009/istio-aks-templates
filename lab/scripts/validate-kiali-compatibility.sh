#!/bin/bash

# 🔍 Script de Validação da Compatibilidade do Kiali com Istio Gerenciado
# Valida se o Kiali funciona corretamente com Prometheus gerenciado e Istio gerenciado no AKS

set -euo pipefail

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/kiali-validation_${TIMESTAMP}.log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Verificar se Istio está funcionando
validate_istio_managed() {
    log_info "🔍 Validando Istio gerenciado..."
    
    # Verificar pods do Istio
    local istio_pods
    istio_pods=$(kubectl get pods -n aks-istio-system --context=aks-istio-primary --no-headers 2>/dev/null | wc -l)
    
    if [ "$istio_pods" -gt 0 ]; then
        log_success "Istio gerenciado está rodando ($istio_pods pods)"
        
        # Listar pods do Istio
        kubectl get pods -n aks-istio-system --context=aks-istio-primary | tee -a "$LOG_FILE"
        
        # Verificar versão do Istio
        local istio_version
        istio_version=$(kubectl get pods -n aks-istio-system --context=aks-istio-primary -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}' 2>/dev/null || echo "unknown")
        log_info "Versão do Istio: $istio_version"
        
        return 0
    else
        log_error "Istio gerenciado não está funcionando"
        return 1
    fi
}

# Verificar se Prometheus está acessível
validate_prometheus_access() {
    log_info "📈 Validando acesso ao Prometheus..."
    
    # Tentar diferentes endpoints do Prometheus
    local prometheus_endpoints=(
        "http://prometheus-server.prometheus.svc.cluster.local:80"
        "http://prometheus-server.prometheus.svc.cluster.local"
        "http://prometheus-server:80"
        "http://ama-metrics.kube-system.svc.cluster.local:9090"  # Azure Monitor for Prometheus
    )
    
    for endpoint in "${prometheus_endpoints[@]}"; do
        log_info "Testando endpoint: $endpoint"
        
        # Criar pod de teste temporário
        kubectl run prometheus-test-$TIMESTAMP \
            --image=curlimages/curl:latest \
            --rm -i --restart=Never \
            --context=aks-istio-primary \
            --command -- curl -s -o /dev/null -w "%{http_code}" "$endpoint/api/v1/query?query=up" 2>/dev/null || true
        
        sleep 2
    done
    
    # Verificar se há serviços do Prometheus
    local prometheus_services
    prometheus_services=$(kubectl get services -A --context=aks-istio-primary | grep -i prometheus | wc -l)
    
    if [ "$prometheus_services" -gt 0 ]; then
        log_success "Encontrados $prometheus_services serviços relacionados ao Prometheus"
        kubectl get services -A --context=aks-istio-primary | grep -i prometheus | tee -a "$LOG_FILE"
    else
        log_warning "Nenhum serviço do Prometheus encontrado"
    fi
}

# Instalar Kiali com configuração compatível
install_kiali_compatible() {
    log_info "🔍 Instalando Kiali compatível com Istio gerenciado..."
    
    # Remover instalação anterior se existir
    kubectl delete namespace kiali-operator --context=aks-istio-primary --ignore-not-found=true
    
    # Aguardar namespace ser removido
    sleep 10
    
    # Aplicar configuração compatível
    kubectl apply -f "${LAB_DIR}/observability/kiali-managed-config.yaml" --context=aks-istio-primary
    
    # Aguardar pods estarem prontos
    log_info "⏳ Aguardando Kiali estar pronto..."
    kubectl wait --for=condition=ready pod -l app=kiali-operator -n kiali-operator --context=aks-istio-primary --timeout=300s || true
    
    # Verificar se o Kiali CR foi criado
    sleep 30
    
    # Aguardar instância do Kiali estar pronta
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kiali -n kiali-operator --context=aks-istio-primary --timeout=300s || true
}

# Testar conectividade do Kiali
test_kiali_connectivity() {
    log_info "🌐 Testando conectividade do Kiali..."
    
    # Obter IP do Kiali
    local kiali_ip
    kiali_ip=$(kubectl get service kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    if [ "$kiali_ip" != "pending" ] && [ -n "$kiali_ip" ]; then
        log_success "Kiali IP obtido: $kiali_ip"
        
        # Testar endpoint de health
        local health_status
        health_status=$(curl -s -o /dev/null -w "%{http_code}" "http://$kiali_ip:20001/kiali/api/health" 2>/dev/null || echo "000")
        
        if [ "$health_status" = "200" ]; then
            log_success "Kiali health check passou (HTTP $health_status)"
        else
            log_warning "Kiali health check falhou (HTTP $health_status)"
        fi
        
        # Testar endpoint de status
        local status_response
        status_response=$(curl -s "http://$kiali_ip:20001/kiali/api/status" 2>/dev/null || echo "failed")
        
        if [[ "$status_response" == *"Kiali"* ]]; then
            log_success "Kiali API está respondendo"
            echo "Status response: $status_response" | tee -a "$LOG_FILE"
        else
            log_warning "Kiali API não está respondendo corretamente"
        fi
        
    else
        log_warning "IP do Kiali ainda não foi atribuído"
        
        # Verificar status do serviço
        kubectl get service kiali -n kiali-operator --context=aks-istio-primary | tee -a "$LOG_FILE"
    fi
}

# Testar integração com Prometheus
test_prometheus_integration() {
    log_info "📊 Testando integração Kiali-Prometheus..."
    
    # Verificar se o Kiali consegue acessar métricas
    local kiali_pod
    kiali_pod=$(kubectl get pod -l app.kubernetes.io/name=kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$kiali_pod" ]; then
        log_info "Pod do Kiali encontrado: $kiali_pod"
        
        # Verificar logs do Kiali para erros de Prometheus
        local kiali_logs
        kiali_logs=$(kubectl logs "$kiali_pod" -n kiali-operator --context=aks-istio-primary --tail=50 2>/dev/null || echo "")
        
        if [[ "$kiali_logs" == *"prometheus"* ]]; then
            log_info "Logs do Kiali mencionam Prometheus"
            echo "$kiali_logs" | grep -i prometheus | tee -a "$LOG_FILE"
        fi
        
        if [[ "$kiali_logs" == *"error"* ]] || [[ "$kiali_logs" == *"ERROR"* ]]; then
            log_warning "Erros encontrados nos logs do Kiali"
            echo "$kiali_logs" | grep -i error | tee -a "$LOG_FILE"
        else
            log_success "Nenhum erro crítico encontrado nos logs do Kiali"
        fi
    else
        log_warning "Pod do Kiali não encontrado"
    fi
}

# Testar visualização de service mesh
test_service_mesh_visualization() {
    log_info "🕸️ Testando visualização do service mesh..."
    
    # Verificar se há aplicações com sidecar do Istio
    local apps_with_sidecar
    apps_with_sidecar=$(kubectl get pods -A --context=aks-istio-primary -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.spec.containers[*].name}{"\n"}{end}' | grep istio-proxy | wc -l)
    
    if [ "$apps_with_sidecar" -gt 0 ]; then
        log_success "Encontradas $apps_with_sidecar aplicações com sidecar do Istio"
        
        # Listar aplicações com sidecar
        kubectl get pods -A --context=aks-istio-primary -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.spec.containers[*].name}{"\n"}{end}' | grep istio-proxy | head -10 | tee -a "$LOG_FILE"
    else
        log_warning "Nenhuma aplicação com sidecar do Istio encontrada"
    fi
    
    # Verificar VirtualServices
    local virtual_services
    virtual_services=$(kubectl get virtualservices -A --context=aks-istio-primary --no-headers 2>/dev/null | wc -l)
    
    if [ "$virtual_services" -gt 0 ]; then
        log_success "Encontrados $virtual_services VirtualServices"
        kubectl get virtualservices -A --context=aks-istio-primary | tee -a "$LOG_FILE"
    else
        log_warning "Nenhum VirtualService encontrado"
    fi
    
    # Verificar DestinationRules
    local destination_rules
    destination_rules=$(kubectl get destinationrules -A --context=aks-istio-primary --no-headers 2>/dev/null | wc -l)
    
    if [ "$destination_rules" -gt 0 ]; then
        log_success "Encontradas $destination_rules DestinationRules"
        kubectl get destinationrules -A --context=aks-istio-primary | tee -a "$LOG_FILE"
    else
        log_warning "Nenhuma DestinationRule encontrada"
    fi
}

# Gerar relatório de compatibilidade
generate_compatibility_report() {
    log_info "📋 Gerando relatório de compatibilidade..."
    
    cat > "/tmp/kiali-compatibility-report_${TIMESTAMP}.json" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "kiali_compatibility": {
    "istio_managed": {
      "status": "$(kubectl get pods -n aks-istio-system --context=aks-istio-primary --no-headers 2>/dev/null | wc -l > 0 && echo "compatible" || echo "incompatible")",
      "version": "$(kubectl get pods -n aks-istio-system --context=aks-istio-primary -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}' 2>/dev/null || echo "unknown")",
      "pods_count": $(kubectl get pods -n aks-istio-system --context=aks-istio-primary --no-headers 2>/dev/null | wc -l)
    },
    "prometheus_integration": {
      "services_found": $(kubectl get services -A --context=aks-istio-primary | grep -i prometheus | wc -l),
      "endpoints_tested": 4,
      "status": "$([ $(kubectl get services -A --context=aks-istio-primary | grep -i prometheus | wc -l) -gt 0 ] && echo "available" || echo "not_found")"
    },
    "kiali_deployment": {
      "namespace": "kiali-operator",
      "pod_status": "$(kubectl get pod -l app.kubernetes.io/name=kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "not_found")",
      "service_ip": "$(kubectl get service kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")",
      "health_check": "$(curl -s -o /dev/null -w "%{http_code}" "http://$(kubectl get service kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null):20001/kiali/api/health" 2>/dev/null || echo "000")"
    },
    "service_mesh_resources": {
      "apps_with_sidecar": $(kubectl get pods -A --context=aks-istio-primary -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}' | grep istio-proxy | wc -l),
      "virtual_services": $(kubectl get virtualservices -A --context=aks-istio-primary --no-headers 2>/dev/null | wc -l),
      "destination_rules": $(kubectl get destinationrules -A --context=aks-istio-primary --no-headers 2>/dev/null | wc -l),
      "gateways": $(kubectl get gateways -A --context=aks-istio-primary --no-headers 2>/dev/null | wc -l)
    }
  },
  "recommendations": [
    "Use Prometheus endpoint: http://prometheus-server.prometheus.svc.cluster.local:80",
    "Configure Kiali with managed Istio revision: asm-1-25",
    "Enable service mesh injection for applications",
    "Configure proper RBAC for Kiali access to Istio resources"
  ],
  "compatibility_score": "$(echo "scale=1; ($(kubectl get pods -n aks-istio-system --context=aks-istio-primary --no-headers 2>/dev/null | wc -l > 0 && echo 25 || echo 0) + $([ $(kubectl get services -A --context=aks-istio-primary | grep -i prometheus | wc -l) -gt 0 ] && echo 25 || echo 0) + $([ "$(kubectl get pod -l app.kubernetes.io/name=kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.items[0].status.phase}' 2>/dev/null)" = "Running" ] && echo 25 || echo 0) + $([ $(kubectl get pods -A --context=aks-istio-primary -o jsonpath='{range .items[*]}{.spec.containers[*].name}{"\n"}{end}' | grep istio-proxy | wc -l) -gt 0 ] && echo 25 || echo 0))" | bc)%"
}
EOF
    
    log_success "Relatório de compatibilidade gerado: /tmp/kiali-compatibility-report_${TIMESTAMP}.json"
}

# Criar script de correção
create_fix_script() {
    log_info "🔧 Criando script de correção..."
    
    cat > "/tmp/fix-kiali-compatibility.sh" << 'EOF'
#!/bin/bash

echo "🔧 CORREÇÃO DA COMPATIBILIDADE KIALI + ISTIO GERENCIADO"
echo "====================================================="

# 1. Reinstalar Kiali com configuração correta
echo "1. Reinstalando Kiali..."
kubectl delete namespace kiali-operator --ignore-not-found=true
sleep 10

kubectl apply -f ../observability/kiali-managed-config.yaml

# 2. Aguardar Kiali estar pronto
echo "2. Aguardando Kiali estar pronto..."
kubectl wait --for=condition=ready pod -l app=kiali-operator -n kiali-operator --timeout=300s
sleep 30
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kiali -n kiali-operator --timeout=300s

# 3. Configurar Prometheus endpoint
echo "3. Configurando endpoint do Prometheus..."
kubectl patch configmap kiali-config -n kiali-operator --patch='
data:
  config.yaml: |
    external_services:
      prometheus:
        url: "http://prometheus-server.prometheus.svc.cluster.local:80"
        health_check_url: "http://prometheus-server.prometheus.svc.cluster.local:80/-/healthy"
'

# 4. Reiniciar Kiali
echo "4. Reiniciando Kiali..."
kubectl rollout restart deployment/kiali -n kiali-operator

echo "✅ Correção concluída!"
echo "🔍 Acesse Kiali em: http://$(kubectl get service kiali -n kiali-operator -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):20001/kiali"
EOF
    
    chmod +x "/tmp/fix-kiali-compatibility.sh"
    
    log_success "Script de correção criado: /tmp/fix-kiali-compatibility.sh"
}

# Função principal
main() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🔍 VALIDAÇÃO DE COMPATIBILIDADE KIALI + ISTIO GERENCIADO"
    echo "═══════════════════════════════════════════════════════════════"
    log_info "🎯 Iniciando validação de compatibilidade"
    log_info "📁 Logs salvos em: $LOG_FILE"
    
    # Executar validações
    validate_istio_managed
    validate_prometheus_access
    install_kiali_compatible
    test_kiali_connectivity
    test_prometheus_integration
    test_service_mesh_visualization
    generate_compatibility_report
    create_fix_script
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ✅ VALIDAÇÃO DE COMPATIBILIDADE CONCLUÍDA!"
    echo "═══════════════════════════════════════════════════════════════"
    
    log_success "🎉 Validação de compatibilidade concluída!"
    
    echo ""
    echo "📋 RESULTADOS:"
    echo "   📊 Relatório: /tmp/kiali-compatibility-report_${TIMESTAMP}.json"
    echo "   🔧 Script de correção: /tmp/fix-kiali-compatibility.sh"
    echo "   📁 Logs completos: $LOG_FILE"
    echo ""
    echo "🔍 Para ver o relatório:"
    echo "   cat /tmp/kiali-compatibility-report_${TIMESTAMP}.json | jq ."
}

# Executar função principal
main "$@"
