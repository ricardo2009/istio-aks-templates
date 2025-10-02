#!/bin/bash

# 🔍 Script de Verificação de Dependências
# Verifica se todas as ferramentas necessárias estão instaladas

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log colorido
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Função para verificar comando
check_command() {
    local cmd=$1
    local name=$2
    local install_hint=$3
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        case $cmd in
            "az")
                version=$(az version --output tsv --query '"azure-cli"' 2>/dev/null || echo "unknown")
                ;;
            "kubectl")
                version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
                ;;
            "jq")
                version=$(jq --version 2>/dev/null || echo "unknown")
                ;;
            "openssl")
                version=$(openssl version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
                ;;
            "curl")
                version=$(curl --version 2>/dev/null | head -n1 | cut -d' ' -f2 || echo "unknown")
                ;;
            *)
                version="installed"
                ;;
        esac
        log_success "$name: $version"
        return 0
    else
        log_error "$name não encontrado"
        log_warning "Instale com: $install_hint"
        return 1
    fi
}

# Banner
echo -e "${BLUE}"
echo "🔍 VERIFICAÇÃO DE DEPENDÊNCIAS - LABORATÓRIO ISTIO AKS"
echo "=================================================="
echo -e "${NC}"

# Contador de dependências
total=0
missing=0

# Verificar Azure CLI
total=$((total + 1))
if ! check_command "az" "Azure CLI" "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"; then
    missing=$((missing + 1))
fi

# Verificar kubectl
total=$((total + 1))
if ! check_command "kubectl" "kubectl" "az aks install-cli"; then
    missing=$((missing + 1))
fi

# Verificar jq
total=$((total + 1))
if ! check_command "jq" "jq (JSON processor)" "sudo apt-get install -y jq"; then
    missing=$((missing + 1))
fi

# Verificar OpenSSL
total=$((total + 1))
if ! check_command "openssl" "OpenSSL" "sudo apt-get install -y openssl"; then
    missing=$((missing + 1))
fi

# Verificar curl
total=$((total + 1))
if ! check_command "curl" "curl" "sudo apt-get install -y curl"; then
    missing=$((missing + 1))
fi

# Verificar git
total=$((total + 1))
if ! check_command "git" "Git" "sudo apt-get install -y git"; then
    missing=$((missing + 1))
fi

echo ""
echo -e "${BLUE}=================================================="
echo "RESUMO DA VERIFICAÇÃO"
echo -e "==================================================${NC}"

if [ $missing -eq 0 ]; then
    log_success "Todas as dependências estão instaladas! ($total/$total)"
    log_info "Você pode executar o laboratório com segurança."
    echo ""
    log_info "Próximo passo: ./lab/scripts/00-provision-complete-lab.sh"
    exit 0
else
    log_error "$missing de $total dependências estão faltando"
    echo ""
    log_warning "Instale as dependências faltantes antes de continuar."
    echo ""
    log_info "Script de instalação rápida:"
    echo "sudo apt-get update && sudo apt-get install -y jq openssl curl git"
    echo "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    echo "az aks install-cli"
    exit 1
fi
