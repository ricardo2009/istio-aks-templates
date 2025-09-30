#!/bin/bash
# Script para simular o workflow do GitHub Actions localmente
# Este script executa os mesmos passos que o workflow deploy.yml

set -e  # Exit on error

echo "======================================================================"
echo "🚀 Simulando GitHub Actions Workflow - Validação de Templates"
echo "======================================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Change to repository root
cd "$(dirname "$0")/.."

# Step 1: Install dependencies
print_step "Passo 1: Instalando dependências"
pip install --upgrade pip -q
pip install -r requirements.txt -q
pip install yamllint -q
print_success "Dependências instaladas"
echo ""

# Step 2: Lint YAML files
print_step "Passo 2: Validando sintaxe YAML dos arquivos de valores"
if yamllint templates/values*.yaml; then
    print_success "YAML lint passou"
else
    print_error "YAML lint falhou"
    exit 1
fi
echo ""

# Step 3: Validate all environments
print_step "Passo 3: Validando todos os ambientes"
if python scripts/validate_templates.py -t templates; then
    print_success "Validação de todos os ambientes passou"
else
    print_error "Validação de ambientes falhou"
    exit 1
fi
echo ""

# Step 4: Test rendering - Default
print_step "Passo 4: Testando renderização - Ambiente Padrão"
if python scripts/helm_render.py -t templates -v templates/values.yaml -o /tmp/ci-test/default --strict; then
    print_success "Renderização do ambiente padrão passou"
else
    print_error "Renderização do ambiente padrão falhou"
    exit 1
fi
echo ""

# Step 5: Test rendering - Staging
print_step "Passo 5: Testando renderização - Staging"
if python scripts/helm_render.py -t templates -v templates/values-staging.yaml -o /tmp/ci-test/staging --strict; then
    print_success "Renderização do ambiente staging passou"
else
    print_error "Renderização do ambiente staging falhou"
    exit 1
fi
echo ""

# Step 6: Test rendering - Production
print_step "Passo 6: Testando renderização - Production"
if python scripts/helm_render.py -t templates -v templates/values-production.yaml -o /tmp/ci-test/production --strict; then
    print_success "Renderização do ambiente production passou"
else
    print_error "Renderização do ambiente production falhou"
    exit 1
fi
echo ""

# Summary
echo "======================================================================"
echo -e "${GREEN}🎉 TODOS OS PASSOS DO WORKFLOW PASSARAM COM SUCESSO!${NC}"
echo "======================================================================"
echo ""
echo "Manifests gerados em:"
echo "  - /tmp/ci-test/default/"
echo "  - /tmp/ci-test/staging/"
echo "  - /tmp/ci-test/production/"
echo ""
echo "Próximos passos:"
echo "  1. Revisar os manifests gerados"
echo "  2. Fazer commit das mudanças"
echo "  3. Abrir Pull Request"
echo ""
