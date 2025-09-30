#!/bin/bash

# Script de Deploy Manual - E-commerce Platform Demo
# Para validação e teste local

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configurações
NAMESPACE="ecommerce-demo"
DOMAIN="ecommerce-demo.aks-labs.com"
CLUSTER_NAME="aks-labs"
RESOURCE_GROUP="rg-aks-labs"

# Função para imprimir cabeçalhos
print_header() {
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}                    $1${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
}

# Função para imprimir seções
print_section() {
    echo -e "\n${CYAN}▶ $1${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────────────${NC}"
}

# Função para verificar se o comando foi executado com sucesso
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
        return 0
    else
        echo -e "${RED}❌ Falha: $1${NC}"
        return 1
    fi
}

# Função para aguardar input do usuário
wait_for_input() {
    echo -e "\n${YELLOW}⏸️  Pressione ENTER para continuar...${NC}"
    read -r
}

# Função principal de deploy
deploy_application() {
    print_header "🚀 DEPLOY MANUAL - E-COMMERCE PLATFORM DEMO"
    
    echo -e "${WHITE}Iniciando deploy manual da plataforma e-commerce com Istio...${NC}"
    
    # 1. Verificar conectividade
    print_section "🔍 Verificando Conectividade com Cluster"
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${RED}❌ Não foi possível conectar ao cluster Kubernetes${NC}"
        echo -e "${YELLOW}Certifique-se de que o kubectl está configurado corretamente${NC}"
        exit 1
    fi
    
    check_success "Conectividade com cluster AKS"
    
    # Verificar se Istio está instalado
    if kubectl get namespace aks-istio-system >/dev/null 2>&1; then
        check_success "Istio gerenciado detectado"
    else
        echo -e "${RED}❌ Istio gerenciado não encontrado${NC}"
        echo -e "${YELLOW}Certifique-se de que o Istio add-on está habilitado no AKS${NC}"
        exit 1
    fi
    
    wait_for_input
    
    # 2. Criar namespace
    print_section "📦 Criando Namespace"
    
    echo -e "${BLUE}Aplicando namespace com injeção do Istio...${NC}"
    kubectl apply -f demo-app/k8s-manifests/namespace.yaml
    check_success "Namespace criado"
    
    # Verificar se a injeção está ativa
    kubectl get namespace $NAMESPACE --show-labels
    
    wait_for_input
    
    # 3. Aplicar políticas de segurança
    print_section "🛡️ Aplicando Políticas de Segurança"
    
    echo -e "${BLUE}Gerando e aplicando políticas de segurança do namespace...${NC}"
    ./scripts/render.sh -f templates/security/namespace-security-policy.yaml -s ecommerce -n $NAMESPACE
    kubectl apply -f manifests/ecommerce/namespace-security-policy.yaml
    check_success "Políticas de segurança aplicadas"
    
    wait_for_input
    
    # 4. Deploy da aplicação
    print_section "🚀 Deployando Aplicação E-commerce"
    
    echo -e "${BLUE}Deployando frontend...${NC}"
    kubectl apply -f demo-app/k8s-manifests/frontend.yaml
    check_success "Frontend deployado"
    
    echo -e "${BLUE}Deployando API gateway...${NC}"
    kubectl apply -f demo-app/k8s-manifests/api-gateway.yaml
    check_success "API Gateway deployado"
    
    echo -e "${BLUE}Deployando serviços backend...${NC}"
    kubectl apply -f demo-app/k8s-manifests/backend-services.yaml
    check_success "Serviços backend deployados"
    
    wait_for_input
    
    # 5. Aguardar pods ficarem prontos
    print_section "⏳ Aguardando Pods Ficarem Prontos"
    
    services=("frontend" "api-gateway" "user-service" "order-service" "payment-service" "notification-service")
    
    for service in "${services[@]}"; do
        echo -e "${BLUE}Aguardando $service ficar pronto...${NC}"
        kubectl wait --for=condition=ready pod \
            --selector=app=$service \
            --namespace=$NAMESPACE \
            --timeout=300s
        check_success "$service está pronto"
    done
    
    wait_for_input
    
    # 6. Configurar Istio Gateway
    print_section "🌐 Configurando Istio Gateway"
    
    echo -e "${BLUE}Gerando e aplicando Gateway...${NC}"
    ./scripts/render.sh -f templates/base/advanced-gateway.yaml -s frontend -n $NAMESPACE -h $DOMAIN --tls-secret ecommerce-tls
    kubectl apply -f manifests/frontend/advanced-gateway.yaml
    check_success "Istio Gateway configurado"
    
    wait_for_input
    
    # 7. Configurar gerenciamento de tráfego
    print_section "🔀 Configurando Gerenciamento de Tráfego"
    
    for service in "${services[@]}"; do
        echo -e "${BLUE}Configurando tráfego para $service...${NC}"
        
        # VirtualService
        ./scripts/render.sh -f templates/traffic-management/advanced-virtual-service.yaml -s "$service" -n $NAMESPACE -h $DOMAIN
        kubectl apply -f "manifests/$service/advanced-virtual-service.yaml"
        
        # DestinationRule com configurações específicas para payment-service
        if [ "$service" = "payment-service" ]; then
            ./scripts/render.sh -f templates/traffic-management/advanced-destination-rule.yaml -s "$service" -n $NAMESPACE --max-connections 30 --consecutive-5xx-errors 3 --base-ejection-time 60s
        else
            ./scripts/render.sh -f templates/traffic-management/advanced-destination-rule.yaml -s "$service" -n $NAMESPACE
        fi
        kubectl apply -f "manifests/$service/advanced-destination-rule.yaml"
        
        check_success "Tráfego configurado para $service"
    done
    
    wait_for_input
    
    # 8. Aplicar configurações de segurança
    print_section "🔒 Aplicando Configurações de Segurança"
    
    for service in "${services[@]}"; do
        echo -e "${BLUE}Aplicando segurança para $service...${NC}"
        
        # PeerAuthentication (mTLS STRICT)
        ./scripts/render.sh -f templates/security/peer-authentication.yaml -s "$service" -n $NAMESPACE
        kubectl apply -f "manifests/$service/peer-authentication.yaml"
        
        # AuthorizationPolicy
        ./scripts/render.sh -f templates/security/authorization-policy.yaml -s "$service" -n $NAMESPACE --caller-sa api-gateway --method GET --path "/"
        kubectl apply -f "manifests/$service/authorization-policy.yaml"
        
        check_success "Segurança configurada para $service"
    done
    
    wait_for_input
    
    # 9. Configurar observabilidade
    print_section "📊 Configurando Observabilidade"
    
    for service in "${services[@]}"; do
        echo -e "${BLUE}Configurando observabilidade para $service...${NC}"
        
        # Telemetry avançada
        ./scripts/render.sh -f templates/observability/advanced-telemetry.yaml -s "$service" -n $NAMESPACE
        kubectl apply -f "manifests/$service/advanced-telemetry.yaml"
        
        check_success "Observabilidade configurada para $service"
    done
    
    wait_for_input
    
    # 10. Verificar deployment
    print_section "🔍 Verificando Deployment"
    
    echo -e "${BLUE}Status dos pods:${NC}"
    kubectl get pods -n $NAMESPACE
    
    echo -e "\n${BLUE}Status dos serviços:${NC}"
    kubectl get services -n $NAMESPACE
    
    echo -e "\n${BLUE}Configurações Istio:${NC}"
    kubectl get gateway,virtualservice,destinationrule -n $NAMESPACE
    
    echo -e "\n${BLUE}Políticas de segurança:${NC}"
    kubectl get peerauthentication,authorizationpolicy -n $NAMESPACE
    
    echo -e "\n${BLUE}Telemetria:${NC}"
    kubectl get telemetry -n $NAMESPACE
    
    wait_for_input
    
    # 11. Obter URL da aplicação
    print_section "🌐 Obtendo URL da Aplicação"
    
    echo -e "${BLUE}Obtendo IP externo do Istio Ingress Gateway...${NC}"
    
    EXTERNAL_IP=$(kubectl get service aks-istio-ingressgateway-external -n aks-istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$EXTERNAL_IP" ]; then
        echo -e "${GREEN}🌐 IP Externo: $EXTERNAL_IP${NC}"
        echo -e "${GREEN}🌐 Domínio: $DOMAIN${NC}"
        echo -e "\n${YELLOW}📝 Para acessar a aplicação, adicione ao seu /etc/hosts:${NC}"
        echo -e "${WHITE}$EXTERNAL_IP $DOMAIN${NC}"
        echo -e "\n${YELLOW}🔗 URLs de acesso:${NC}"
        echo -e "${WHITE}https://$DOMAIN${NC}"
        echo -e "${WHITE}http://$EXTERNAL_IP${NC}"
    else
        echo -e "${YELLOW}⚠️  IP externo ainda não foi atribuído${NC}"
        echo -e "${YELLOW}Execute o comando abaixo em alguns minutos:${NC}"
        echo -e "${WHITE}kubectl get service aks-istio-ingressgateway-external -n aks-istio-system${NC}"
    fi
    
    # 12. Resumo do deployment
    print_header "🎉 DEPLOYMENT CONCLUÍDO COM SUCESSO"
    
    echo -e "${GREEN}✅ Namespace: $NAMESPACE${NC}"
    echo -e "${GREEN}✅ Serviços deployados: 6${NC}"
    echo -e "${GREEN}✅ Istio Gateway configurado${NC}"
    echo -e "${GREEN}✅ mTLS STRICT habilitado${NC}"
    echo -e "${GREEN}✅ Circuit breakers configurados${NC}"
    echo -e "${GREEN}✅ Observabilidade habilitada${NC}"
    echo -e "${GREEN}✅ Políticas de segurança aplicadas${NC}"
    
    echo -e "\n${CYAN}🎯 Próximos Passos:${NC}"
    echo -e "${WHITE}1. Acesse a aplicação via IP externo${NC}"
    echo -e "${WHITE}2. Execute testes de chaos: ./scripts/chaos-test.sh${NC}"
    echo -e "${WHITE}3. Monitore métricas no Grafana${NC}"
    echo -e "${WHITE}4. Teste canary deployments${NC}"
    echo -e "${WHITE}5. Execute a demonstração: ./scripts/demo-presentation.sh${NC}"
    
    echo -e "\n${PURPLE}📋 Comandos úteis:${NC}"
    echo -e "${WHITE}# Ver logs dos pods${NC}"
    echo -e "${WHITE}kubectl logs -f deployment/frontend -n $NAMESPACE${NC}"
    echo -e "${WHITE}# Ver métricas do Istio${NC}"
    echo -e "${WHITE}kubectl top pods -n $NAMESPACE${NC}"
    echo -e "${WHITE}# Limpar ambiente${NC}"
    echo -e "${WHITE}./scripts/cleanup.sh${NC}"
}

# Função de limpeza
cleanup_application() {
    print_header "🧹 LIMPEZA DO AMBIENTE"
    
    echo -e "${YELLOW}Removendo todas as configurações e recursos...${NC}"
    
    # Remover configurações Istio
    echo -e "${BLUE}Removendo configurações Istio...${NC}"
    kubectl delete gateway,virtualservice,destinationrule,peerauthentication,authorizationpolicy,telemetry --all -n $NAMESPACE --ignore-not-found=true
    check_success "Configurações Istio removidas"
    
    # Remover aplicação
    echo -e "${BLUE}Removendo aplicação...${NC}"
    kubectl delete -f demo-app/k8s-manifests/ --ignore-not-found=true
    check_success "Aplicação removida"
    
    # Remover namespace
    echo -e "${BLUE}Removendo namespace...${NC}"
    kubectl delete namespace $NAMESPACE --ignore-not-found=true
    check_success "Namespace removido"
    
    echo -e "\n${GREEN}✅ Ambiente limpo com sucesso!${NC}"
}

# Menu principal
show_menu() {
    clear
    print_header "🎪 DEPLOY MANUAL - E-COMMERCE PLATFORM"
    
    echo -e "${CYAN}Escolha uma opção:${NC}"
    echo -e "${WHITE}1. 🚀 Deploy completo da aplicação${NC}"
    echo -e "${WHITE}2. 🧹 Limpar ambiente${NC}"
    echo -e "${WHITE}3. 🔍 Verificar status${NC}"
    echo -e "${WHITE}4. ❌ Sair${NC}"
    echo -e "\n${YELLOW}Digite sua escolha (1-4): ${NC}"
}

# Função para verificar status
check_status() {
    print_section "🔍 Status do Ambiente"
    
    if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Namespace $NAMESPACE existe${NC}"
        
        echo -e "\n${BLUE}Pods:${NC}"
        kubectl get pods -n $NAMESPACE
        
        echo -e "\n${BLUE}Serviços:${NC}"
        kubectl get services -n $NAMESPACE
        
        echo -e "\n${BLUE}Configurações Istio:${NC}"
        kubectl get gateway,virtualservice,destinationrule -n $NAMESPACE
        
    else
        echo -e "${YELLOW}⚠️  Namespace $NAMESPACE não existe${NC}"
        echo -e "${YELLOW}Execute o deploy primeiro${NC}"
    fi
}

# Script principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                deploy_application
                wait_for_input
                ;;
            2)
                cleanup_application
                wait_for_input
                ;;
            3)
                check_status
                wait_for_input
                ;;
            4)
                echo -e "\n${GREEN}Obrigado por usar o deploy manual! 🚀${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}Opção inválida. Tente novamente.${NC}"
                sleep 2
                ;;
        esac
    done
fi
