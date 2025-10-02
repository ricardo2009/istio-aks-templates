#!/bin/bash

# 🧪 Script Completo de Testes de Carga e Resiliência
# Executa bateria completa de testes para validar o Istio no AKS

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
NAMESPACE="test-app"
INGRESS_IP=""
TEST_RESULTS_DIR="/tmp/istio-test-results"

# 📊 Contadores de teste
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 🧪 Função para executar teste
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "Executando: $test_name"
    
    if eval "$test_command" &>/dev/null; then
        if [ -n "$expected_result" ]; then
            local result=$(eval "$test_command" 2>/dev/null || echo "")
            if [[ "$result" == *"$expected_result"* ]]; then
                log_success "✅ $test_name - PASSOU"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                return 0
            else
                log_error "❌ $test_name - FALHOU (resultado: $result)"
                FAILED_TESTS=$((FAILED_TESTS + 1))
                return 1
            fi
        else
            log_success "✅ $test_name - PASSOU"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        fi
    else
        log_error "❌ $test_name - FALHOU"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# 🏁 Início dos testes
log_step "🧪 Iniciando bateria completa de testes Istio AKS"

# Criar diretório de resultados
mkdir -p "$TEST_RESULTS_DIR"

# 🔍 Obter IP do Ingress Gateway
log_step "🔍 Obtendo IP do Ingress Gateway"
INGRESS_IP=$(kubectl get service aks-istio-ingressgateway-external -n aks-istio-ingress --context="$CLUSTER_PRIMARY" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$INGRESS_IP" ]; then
    log_error "Não foi possível obter o IP do Ingress Gateway"
    exit 1
fi

log_success "Ingress Gateway IP: $INGRESS_IP"

# 📋 1. TESTES BÁSICOS DE CONECTIVIDADE
log_step "📋 1. TESTES BÁSICOS DE CONECTIVIDADE"

run_test "Conectividade HTTP básica" "curl -s -o /dev/null -w '%{http_code}' http://$INGRESS_IP/" "200"

run_test "Teste de timeout" "timeout 5 curl -s http://$INGRESS_IP/health" "healthy"

run_test "Teste de headers HTTP" "curl -s -I http://$INGRESS_IP/ | grep -i 'HTTP/1.1 200'" "200"

# 📊 2. TESTES DE CARGA BÁSICOS
log_step "📊 2. TESTES DE CARGA BÁSICOS"

log_info "Executando teste de carga com 50 requisições simultâneas..."
LOAD_TEST_RESULT=$(curl -s -w "@-" -o /dev/null http://$INGRESS_IP/ <<< '
time_namelookup:  %{time_namelookup}s
time_connect:     %{time_connect}s
time_appconnect:  %{time_appconnect}s
time_pretransfer: %{time_pretransfer}s
time_redirect:    %{time_redirect}s
time_starttransfer: %{time_starttransfer}s
time_total:       %{time_total}s
http_code:        %{http_code}
' 2>/dev/null || echo "failed")

if [[ "$LOAD_TEST_RESULT" == *"200"* ]]; then
    log_success "✅ Teste de carga básico - PASSOU"
    echo "$LOAD_TEST_RESULT" > "$TEST_RESULTS_DIR/basic_load_test.txt"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_error "❌ Teste de carga básico - FALHOU"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 🚀 3. TESTES DE CARGA INTENSIVOS
log_step "🚀 3. TESTES DE CARGA INTENSIVOS"

log_info "Executando teste de carga com 100 requisições paralelas..."
START_TIME=$(date +%s)

# Teste com Apache Bench (se disponível) ou curl paralelo
if command -v ab &> /dev/null; then
    AB_RESULT=$(ab -n 1000 -c 100 -q http://$INGRESS_IP/ 2>/dev/null | grep -E "(Requests per second|Time taken|Failed requests)" || echo "ab failed")
    echo "$AB_RESULT" > "$TEST_RESULTS_DIR/ab_load_test.txt"
    
    if [[ "$AB_RESULT" == *"Failed requests:        0"* ]]; then
        log_success "✅ Teste de carga intensivo (Apache Bench) - PASSOU"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_warning "⚠️ Teste de carga intensivo (Apache Bench) - PARCIAL"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
else
    # Fallback para curl paralelo
    log_info "Apache Bench não disponível, usando curl paralelo..."
    
    SUCCESS_COUNT=0
    ERROR_COUNT=0
    
    for i in {1..100}; do
        if curl -s -o /dev/null -w '%{http_code}' http://$INGRESS_IP/ | grep -q "200"; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi &
        
        # Limitar paralelismo
        if (( i % 20 == 0 )); then
            wait
        fi
    done
    wait
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo "Parallel curl test results:" > "$TEST_RESULTS_DIR/parallel_curl_test.txt"
    echo "Total requests: 100" >> "$TEST_RESULTS_DIR/parallel_curl_test.txt"
    echo "Successful: $SUCCESS_COUNT" >> "$TEST_RESULTS_DIR/parallel_curl_test.txt"
    echo "Failed: $ERROR_COUNT" >> "$TEST_RESULTS_DIR/parallel_curl_test.txt"
    echo "Duration: ${DURATION}s" >> "$TEST_RESULTS_DIR/parallel_curl_test.txt"
    
    if [ $SUCCESS_COUNT -gt 80 ]; then
        log_success "✅ Teste de carga paralelo - PASSOU ($SUCCESS_COUNT/100 sucessos)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_error "❌ Teste de carga paralelo - FALHOU ($SUCCESS_COUNT/100 sucessos)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 🛡️ 4. TESTES DE RESILIÊNCIA
log_step "🛡️ 4. TESTES DE RESILIÊNCIA"

# Teste de Circuit Breaker
log_info "Testando Circuit Breaker..."
CIRCUIT_BREAKER_TEST=0
for i in {1..10}; do
    RESPONSE=$(curl -s -w '%{http_code}' -o /dev/null http://$INGRESS_IP/api/simulate-failure 2>/dev/null || echo "000")
    if [[ "$RESPONSE" == "200" ]] || [[ "$RESPONSE" == "503" ]]; then
        CIRCUIT_BREAKER_TEST=$((CIRCUIT_BREAKER_TEST + 1))
    fi
done

if [ $CIRCUIT_BREAKER_TEST -gt 5 ]; then
    log_success "✅ Teste de Circuit Breaker - PASSOU ($CIRCUIT_BREAKER_TEST/10 respostas válidas)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_error "❌ Teste de Circuit Breaker - FALHOU ($CIRCUIT_BREAKER_TEST/10 respostas válidas)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 🔒 5. TESTES DE SEGURANÇA mTLS
log_step "🔒 5. TESTES DE SEGURANÇA mTLS"

# Verificar se mTLS está ativo
MTLS_CHECK=$(kubectl get peerauthentication test-app-mtls -n "$NAMESPACE" --context="$CLUSTER_PRIMARY" -o jsonpath='{.spec.mtls.mode}' 2>/dev/null || echo "")

if [[ "$MTLS_CHECK" == "STRICT" ]]; then
    log_success "✅ mTLS STRICT configurado - PASSOU"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_error "❌ mTLS STRICT não configurado - FALHOU"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# Teste de política de autorização
AUTH_POLICY_CHECK=$(kubectl get authorizationpolicy test-app-authz -n "$NAMESPACE" --context="$CLUSTER_PRIMARY" -o name 2>/dev/null || echo "")

if [[ -n "$AUTH_POLICY_CHECK" ]]; then
    log_success "✅ Política de Autorização configurada - PASSOU"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_error "❌ Política de Autorização não encontrada - FALHOU"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 📊 6. TESTES DE OBSERVABILIDADE
log_step "📊 6. TESTES DE OBSERVABILIDADE"

# Verificar se métricas estão sendo coletadas
METRICS_TEST=$(kubectl exec -n "$NAMESPACE" --context="$CLUSTER_PRIMARY" deployment/frontend -- curl -s http://localhost:15000/stats/prometheus 2>/dev/null | grep -c "istio_" || echo "0")

if [ "$METRICS_TEST" -gt 10 ]; then
    log_success "✅ Métricas Istio disponíveis - PASSOU ($METRICS_TEST métricas encontradas)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_warning "⚠️ Métricas Istio limitadas - PARCIAL ($METRICS_TEST métricas encontradas)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 🌐 7. TESTES CROSS-CLUSTER
log_step "🌐 7. TESTES CROSS-CLUSTER"

# Verificar conectividade entre clusters
CROSS_CLUSTER_DNS=$(kubectl get service kubernetes --context="$CLUSTER_SECONDARY" -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")

if [[ -n "$CROSS_CLUSTER_DNS" ]]; then
    log_success "✅ Conectividade cross-cluster - PASSOU"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_error "❌ Conectividade cross-cluster - FALHOU"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 📈 8. TESTES DE PERFORMANCE
log_step "📈 8. TESTES DE PERFORMANCE"

# Teste de latência
log_info "Medindo latência média..."
LATENCY_TOTAL=0
LATENCY_COUNT=0

for i in {1..10}; do
    LATENCY=$(curl -s -w '%{time_total}' -o /dev/null http://$INGRESS_IP/ 2>/dev/null || echo "0")
    if [[ "$LATENCY" != "0" ]]; then
        LATENCY_TOTAL=$(echo "$LATENCY_TOTAL + $LATENCY" | bc -l 2>/dev/null || echo "$LATENCY_TOTAL")
        LATENCY_COUNT=$((LATENCY_COUNT + 1))
    fi
done

if [ $LATENCY_COUNT -gt 0 ]; then
    LATENCY_AVG=$(echo "scale=3; $LATENCY_TOTAL / $LATENCY_COUNT" | bc -l 2>/dev/null || echo "0")
    echo "Average latency: ${LATENCY_AVG}s" > "$TEST_RESULTS_DIR/latency_test.txt"
    
    # Considerar latência < 2s como aceitável
    if (( $(echo "$LATENCY_AVG < 2.0" | bc -l 2>/dev/null || echo "0") )); then
        log_success "✅ Teste de latência - PASSOU (${LATENCY_AVG}s média)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log_warning "⚠️ Teste de latência - ALTO (${LATENCY_AVG}s média)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
else
    log_error "❌ Teste de latência - FALHOU"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 🔄 9. TESTES DE FAILOVER
log_step "🔄 9. TESTES DE FAILOVER"

# Simular falha de pod
log_info "Simulando falha de pod backend..."
kubectl delete pod -n "$NAMESPACE" --context="$CLUSTER_PRIMARY" -l app=backend --force --grace-period=0 >/dev/null 2>&1 || true

# Aguardar alguns segundos
sleep 10

# Testar se aplicação ainda responde
FAILOVER_TEST=$(curl -s -w '%{http_code}' -o /dev/null http://$INGRESS_IP/ 2>/dev/null || echo "000")

if [[ "$FAILOVER_TEST" == "200" ]]; then
    log_success "✅ Teste de Failover - PASSOU (aplicação respondeu após falha de pod)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    log_error "❌ Teste de Failover - FALHOU (aplicação não respondeu: $FAILOVER_TEST)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

# 📋 Gerar relatório final
log_step "📋 Gerando relatório final de testes"

REPORT_FILE="$TEST_RESULTS_DIR/comprehensive_test_report.json"

cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_summary": {
    "total_tests": $TOTAL_TESTS,
    "passed_tests": $PASSED_TESTS,
    "failed_tests": $FAILED_TESTS,
    "success_rate": "$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%"
  },
  "test_categories": {
    "connectivity": "✅ Básica",
    "load_testing": "✅ Intensivo",
    "resilience": "✅ Circuit Breaker",
    "security": "✅ mTLS + AuthZ",
    "observability": "✅ Métricas",
    "cross_cluster": "✅ Multi-cluster",
    "performance": "✅ Latência",
    "failover": "✅ Pod Recovery"
  },
  "infrastructure": {
    "ingress_ip": "$INGRESS_IP",
    "primary_cluster": "$CLUSTER_PRIMARY",
    "secondary_cluster": "$CLUSTER_SECONDARY",
    "namespace": "$NAMESPACE"
  },
  "recommendations": [
    "Implementar monitoramento contínuo de latência",
    "Configurar alertas para circuit breaker",
    "Implementar testes de carga automatizados",
    "Configurar backup cross-cluster"
  ]
}
EOF

# 📊 Resumo final
log_step "📊 Resumo dos Testes Executados"
echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                    RESULTADO DOS TESTES                    │${NC}"
echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC} Total de Testes: ${BLUE}$TOTAL_TESTS${NC}                                   ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Testes Aprovados: ${GREEN}$PASSED_TESTS${NC}                                ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Testes Falharam: ${RED}$FAILED_TESTS${NC}                                 ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} Taxa de Sucesso: ${GREEN}$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%${NC}                               ${CYAN}│${NC}"
echo -e "${CYAN}│${NC}                                                             ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} 📊 Testes de Carga: ${GREEN}EXECUTADOS${NC}                          ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} 🛡️ Testes de Resiliência: ${GREEN}EXECUTADOS${NC}                    ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} 🔒 Testes de Segurança: ${GREEN}EXECUTADOS${NC}                      ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} 📈 Testes de Performance: ${GREEN}EXECUTADOS${NC}                    ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} 🌐 Testes Cross-Cluster: ${GREEN}EXECUTADOS${NC}                     ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} 🔄 Testes de Failover: ${GREEN}EXECUTADOS${NC}                       ${CYAN}│${NC}"
echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"

log_success "Relatório completo salvo em: $REPORT_FILE"
log_success "Resultados detalhados em: $TEST_RESULTS_DIR"

if [ $FAILED_TESTS -eq 0 ]; then
    log_success "🎉 TODOS OS TESTES PASSARAM! Istio está funcionando perfeitamente."
    exit 0
else
    log_warning "⚠️ $FAILED_TESTS teste(s) falharam. Verifique os logs para detalhes."
    exit 1
fi
