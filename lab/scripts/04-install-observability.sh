#!/bin/bash

# 🔍 Script de Instalação de Observabilidade Avançada
# Instala Kiali, Grafana e configura dashboards personalizados

set -euo pipefail

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="/tmp/observability-install_${TIMESTAMP}.log"

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

# Verificar pré-requisitos
check_prerequisites() {
    log_info "🔍 Verificando pré-requisitos..."
    
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
    
    # Verificar conectividade com clusters
    if ! kubectl cluster-info --context=aks-istio-primary &> /dev/null; then
        log_error "Não foi possível conectar ao cluster primário"
        exit 1
    fi
    
    if ! kubectl cluster-info --context=aks-istio-secondary &> /dev/null; then
        log_error "Não foi possível conectar ao cluster secundário"
        exit 1
    fi
    
    log_success "Pré-requisitos verificados com sucesso"
}

# Instalar Kiali
install_kiali() {
    log_info "🔍 Instalando Kiali para visualização da service mesh..."
    
    # Aplicar configuração do Kiali
    kubectl apply -f "${LAB_DIR}/observability/kiali-config.yaml" --context=aks-istio-primary
    
    # Aguardar Kiali estar pronto
    log_info "⏳ Aguardando Kiali estar pronto..."
    kubectl wait --for=condition=ready pod -l app=kiali -n kiali-operator --context=aks-istio-primary --timeout=300s
    
    # Obter IP do Kiali
    local kiali_ip
    kiali_ip=$(kubectl get service kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    if [ "$kiali_ip" != "pending" ] && [ -n "$kiali_ip" ]; then
        log_success "Kiali instalado com sucesso!"
        echo "🔍 Kiali URL: http://$kiali_ip:20001/kiali" | tee -a "$LOG_FILE"
        echo "KIALI_URL=http://$kiali_ip:20001/kiali" >> "/tmp/observability_urls_${TIMESTAMP}.txt"
    else
        log_warning "Kiali instalado, mas IP ainda não foi atribuído. Aguarde alguns minutos."
    fi
}

# Instalar Grafana
install_grafana() {
    log_info "📊 Instalando Grafana para dashboards avançados..."
    
    # Adicionar repositório do Grafana
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    # Instalar Grafana
    helm install grafana grafana/grafana \
        --namespace grafana \
        --create-namespace \
        --set service.type=LoadBalancer \
        --set adminPassword=admin123 \
        --set persistence.enabled=true \
        --set persistence.size=10Gi \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=128Mi \
        --set resources.limits.cpu=500m \
        --set resources.limits.memory=512Mi \
        --context=aks-istio-primary
    
    # Aguardar Grafana estar pronto
    log_info "⏳ Aguardando Grafana estar pronto..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n grafana --context=aks-istio-primary --timeout=300s
    
    # Obter IP do Grafana
    local grafana_ip
    grafana_ip=$(kubectl get service grafana -n grafana --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    if [ "$grafana_ip" != "pending" ] && [ -n "$grafana_ip" ]; then
        log_success "Grafana instalado com sucesso!"
        echo "📊 Grafana URL: http://$grafana_ip" | tee -a "$LOG_FILE"
        echo "👤 Username: admin" | tee -a "$LOG_FILE"
        echo "🔑 Password: admin123" | tee -a "$LOG_FILE"
        echo "GRAFANA_URL=http://$grafana_ip" >> "/tmp/observability_urls_${TIMESTAMP}.txt"
        echo "GRAFANA_USER=admin" >> "/tmp/observability_urls_${TIMESTAMP}.txt"
        echo "GRAFANA_PASS=admin123" >> "/tmp/observability_urls_${TIMESTAMP}.txt"
    else
        log_warning "Grafana instalado, mas IP ainda não foi atribuído. Aguarde alguns minutos."
    fi
}

# Instalar Prometheus (se não estiver instalado)
install_prometheus() {
    log_info "📈 Verificando instalação do Prometheus..."
    
    # Verificar se Prometheus já está instalado
    if kubectl get namespace prometheus --context=aks-istio-primary &> /dev/null; then
        log_info "Prometheus já está instalado"
        return 0
    fi
    
    log_info "📈 Instalando Prometheus..."
    
    # Adicionar repositório do Prometheus
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Instalar Prometheus
    helm install prometheus prometheus-community/prometheus \
        --namespace prometheus \
        --create-namespace \
        --set server.service.type=LoadBalancer \
        --set server.persistentVolume.size=20Gi \
        --set alertmanager.persistentVolume.size=5Gi \
        --context=aks-istio-primary
    
    # Aguardar Prometheus estar pronto
    log_info "⏳ Aguardando Prometheus estar pronto..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server -n prometheus --context=aks-istio-primary --timeout=300s
    
    log_success "Prometheus instalado com sucesso!"
}

# Configurar datasources no Grafana
configure_grafana_datasources() {
    log_info "🔧 Configurando datasources no Grafana..."
    
    # Aguardar um pouco para Grafana estar completamente pronto
    sleep 30
    
    # Obter IP do Grafana
    local grafana_ip
    grafana_ip=$(kubectl get service grafana -n grafana --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$grafana_ip" ]; then
        log_warning "IP do Grafana não disponível ainda. Pule esta etapa por enquanto."
        return 0
    fi
    
    # Configurar Prometheus como datasource
    local prometheus_url="http://prometheus-server.prometheus.svc.cluster.local"
    
    cat > "/tmp/prometheus-datasource.json" << EOF
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "$prometheus_url",
  "access": "proxy",
  "isDefault": true,
  "basicAuth": false,
  "jsonData": {
    "httpMethod": "POST",
    "manageAlerts": true,
    "alertmanagerUid": ""
  }
}
EOF
    
    # Tentar configurar datasource (pode falhar se Grafana não estiver totalmente pronto)
    if curl -s -X POST \
        -H "Content-Type: application/json" \
        -d @/tmp/prometheus-datasource.json \
        "http://admin:admin123@$grafana_ip/api/datasources" > /dev/null 2>&1; then
        log_success "Datasource Prometheus configurado no Grafana"
    else
        log_warning "Não foi possível configurar datasource automaticamente. Configure manualmente no Grafana."
    fi
    
    # Limpar arquivo temporário
    rm -f "/tmp/prometheus-datasource.json"
}

# Instalar Jaeger para distributed tracing
install_jaeger() {
    log_info "🔍 Instalando Jaeger para distributed tracing..."
    
    # Criar namespace
    kubectl create namespace jaeger --context=aks-istio-primary --dry-run=client -o yaml | kubectl apply -f - --context=aks-istio-primary
    
    # Instalar Jaeger All-in-One
    kubectl apply -f - --context=aks-istio-primary << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: jaeger
  labels:
    app: jaeger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:1.50
        ports:
        - containerPort: 16686
          name: ui
        - containerPort: 14250
          name: grpc
        - containerPort: 14268
          name: http
        env:
        - name: COLLECTOR_OTLP_ENABLED
          value: "true"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-query
  namespace: jaeger
  labels:
    app: jaeger
spec:
  type: LoadBalancer
  ports:
  - port: 16686
    targetPort: 16686
    name: ui
  - port: 14250
    targetPort: 14250
    name: grpc
  - port: 14268
    targetPort: 14268
    name: http
  selector:
    app: jaeger
EOF
    
    # Aguardar Jaeger estar pronto
    log_info "⏳ Aguardando Jaeger estar pronto..."
    kubectl wait --for=condition=ready pod -l app=jaeger -n jaeger --context=aks-istio-primary --timeout=300s
    
    # Obter IP do Jaeger
    local jaeger_ip
    jaeger_ip=$(kubectl get service jaeger-query -n jaeger --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    if [ "$jaeger_ip" != "pending" ] && [ -n "$jaeger_ip" ]; then
        log_success "Jaeger instalado com sucesso!"
        echo "🔍 Jaeger URL: http://$jaeger_ip:16686" | tee -a "$LOG_FILE"
        echo "JAEGER_URL=http://$jaeger_ip:16686" >> "/tmp/observability_urls_${TIMESTAMP}.txt"
    else
        log_warning "Jaeger instalado, mas IP ainda não foi atribuído. Aguarde alguns minutos."
    fi
}

# Criar script de acesso rápido
create_access_script() {
    log_info "📝 Criando script de acesso rápido..."
    
    cat > "/tmp/observability-access.sh" << 'EOF'
#!/bin/bash

# Script de Acesso Rápido à Observabilidade

echo "🔍 OBSERVABILIDADE - URLS DE ACESSO"
echo "=================================="

# Kiali
KIALI_IP=$(kubectl get service kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$KIALI_IP" != "pending" ] && [ -n "$KIALI_IP" ]; then
    echo "🔍 Kiali (Service Mesh Topology): http://$KIALI_IP:20001/kiali"
else
    echo "🔍 Kiali: IP ainda não atribuído"
fi

# Grafana
GRAFANA_IP=$(kubectl get service grafana -n grafana --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$GRAFANA_IP" != "pending" ] && [ -n "$GRAFANA_IP" ]; then
    echo "📊 Grafana (Dashboards): http://$GRAFANA_IP"
    echo "   👤 Username: admin"
    echo "   🔑 Password: admin123"
else
    echo "📊 Grafana: IP ainda não atribuído"
fi

# Jaeger
JAEGER_IP=$(kubectl get service jaeger-query -n jaeger --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$JAEGER_IP" != "pending" ] && [ -n "$JAEGER_IP" ]; then
    echo "🔍 Jaeger (Distributed Tracing): http://$JAEGER_IP:16686"
else
    echo "🔍 Jaeger: IP ainda não atribuído"
fi

# Prometheus
PROMETHEUS_IP=$(kubectl get service prometheus-server -n prometheus --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$PROMETHEUS_IP" != "pending" ] && [ -n "$PROMETHEUS_IP" ]; then
    echo "📈 Prometheus (Metrics): http://$PROMETHEUS_IP"
else
    echo "📈 Prometheus: Acessível internamente via port-forward"
    echo "   kubectl port-forward -n prometheus svc/prometheus-server 9090:80 --context=aks-istio-primary"
fi

echo ""
echo "🎯 Para abrir todos os serviços:"
echo "   ./open-observability.sh"
EOF
    
    chmod +x "/tmp/observability-access.sh"
    
    # Criar script para abrir todos os serviços
    cat > "/tmp/open-observability.sh" << 'EOF'
#!/bin/bash

# Script para abrir todos os serviços de observabilidade

echo "🚀 Abrindo serviços de observabilidade..."

# Kiali
KIALI_IP=$(kubectl get service kiali -n kiali-operator --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$KIALI_IP" ] && [ "$KIALI_IP" != "pending" ]; then
    echo "🔍 Abrindo Kiali..."
    open "http://$KIALI_IP:20001/kiali" 2>/dev/null || xdg-open "http://$KIALI_IP:20001/kiali" 2>/dev/null || echo "Abra manualmente: http://$KIALI_IP:20001/kiali"
fi

# Grafana
GRAFANA_IP=$(kubectl get service grafana -n grafana --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$GRAFANA_IP" ] && [ "$GRAFANA_IP" != "pending" ]; then
    echo "📊 Abrindo Grafana..."
    open "http://$GRAFANA_IP" 2>/dev/null || xdg-open "http://$GRAFANA_IP" 2>/dev/null || echo "Abra manualmente: http://$GRAFANA_IP"
fi

# Jaeger
JAEGER_IP=$(kubectl get service jaeger-query -n jaeger --context=aks-istio-primary -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -n "$JAEGER_IP" ] && [ "$JAEGER_IP" != "pending" ]; then
    echo "🔍 Abrindo Jaeger..."
    open "http://$JAEGER_IP:16686" 2>/dev/null || xdg-open "http://$JAEGER_IP:16686" 2>/dev/null || echo "Abra manualmente: http://$JAEGER_IP:16686"
fi

echo "✅ Todos os serviços foram abertos!"
EOF
    
    chmod +x "/tmp/open-observability.sh"
    
    log_success "Scripts de acesso criados em /tmp/"
}

# Função principal
main() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🔍 INSTALAÇÃO DE OBSERVABILIDADE AVANÇADA"
    echo "═══════════════════════════════════════════════════════════════"
    log_info "🎯 Iniciando instalação de observabilidade completa"
    log_info "📁 Logs salvos em: $LOG_FILE"
    
    # Executar instalações
    check_prerequisites
    install_prometheus
    install_kiali
    install_grafana
    install_jaeger
    configure_grafana_datasources
    create_access_script
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    echo "═══════════════════════════════════════════════════════════════"
    
    log_success "🎉 Observabilidade instalada com sucesso!"
    
    echo ""
    echo "📋 PRÓXIMOS PASSOS:"
    echo "1. Execute: /tmp/observability-access.sh para ver as URLs"
    echo "2. Aguarde alguns minutos para todos os IPs serem atribuídos"
    echo "3. Importe o dashboard personalizado no Grafana:"
    echo "   - Arquivo: ${LAB_DIR}/observability/grafana-dashboard-ultimate.json"
    echo "4. Configure datasources adicionais se necessário"
    echo ""
    echo "📊 Para importar o dashboard no Grafana:"
    echo "   1. Acesse Grafana (URL será mostrada pelo script de acesso)"
    echo "   2. Vá em '+' → Import"
    echo "   3. Cole o conteúdo do arquivo grafana-dashboard-ultimate.json"
    echo "   4. Clique em 'Load' e depois 'Import'"
    echo ""
    echo "🔍 Logs completos salvos em: $LOG_FILE"
}

# Executar função principal
main "$@"
