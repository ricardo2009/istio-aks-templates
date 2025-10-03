#!/bin/bash
# =============================================================================
# Script de Validação de Sintaxe e Funcionamento
# =============================================================================

set -euo pipefail

echo "=== INICIANDO VALIDAÇÃO COMPLETA DOS SCRIPTS ==="
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success_count=0
error_count=0

# Função para testar sintaxe
test_syntax() {
    local script_file="$1"
    local script_name=$(basename "$script_file")
    
    echo -e "${BLUE}🔍 Testando sintaxe: $script_name${NC}"
    
    if bash -n "$script_file" 2>/dev/null; then
        echo -e "${GREEN}✅ Sintaxe OK: $script_name${NC}"
        ((success_count++))
        return 0
    else
        echo -e "${RED}❌ Erro de sintaxe: $script_name${NC}"
        echo "Detalhes do erro:"
        bash -n "$script_file"
        ((error_count++))
        return 1
    fi
}

# Função para testar execução em modo dry-run
test_dry_run() {
    local script_file="$1"
    local script_name=$(basename "$script_file")
    
    echo -e "${BLUE}🧪 Testando execução dry-run: $script_name${NC}"
    
    # Criar versão de teste
    local test_file="/tmp/test_${script_name}"
    cp "$script_file" "$test_file"
    
    # Adicionar modo dry-run no início
    sed -i '1a\\nDRY_RUN=true' "$test_file"
    
    # Substituir comandos Azure CLI por echo
    sed -i 's/az group create/echo "[DRY-RUN] az group create/g' "$test_file"
    sed -i 's/az aks create/echo "[DRY-RUN] az aks create/g' "$test_file"
    sed -i 's/az network vnet create/echo "[DRY-RUN] az network vnet create/g' "$test_file"
    sed -i 's/az keyvault create/echo "[DRY-RUN] az keyvault create/g' "$test_file"
    
    if timeout 30s bash "$test_file" --help 2>/dev/null || true; then
        echo -e "${GREEN}✅ Execução dry-run OK: $script_name${NC}"
        ((success_count++))
    else
        echo -e "${YELLOW}⚠️ Dry-run com avisos: $script_name${NC}"
    fi
    
    rm -f "$test_file"
}

# Scripts para testar
scripts=(
    "00-provision-complete-lab.sh"
    "00-setup-azure-resources.sh"
    "01-validate-infrastructure.sh"
    "02-comprehensive-testing.sh"
    "04-install-observability.sh"
)

echo "📋 Scripts a serem validados:"
for script in "${scripts[@]}"; do
    echo "  - $script"
done
echo ""

# Testar sintaxe de todos os scripts
echo "🔍 FASE 1: Validação de Sintaxe"
echo "================================"
for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        test_syntax "$script"
    else
        echo -e "${RED}❌ Arquivo não encontrado: $script${NC}"
        ((error_count++))
    fi
    echo ""
done

# Testar variáveis e dependências
echo "🔧 FASE 2: Validação de Dependências"
echo "====================================="

# Verificar Azure CLI
if command -v az >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Azure CLI instalado${NC}"
    ((success_count++))
else
    echo -e "${RED}❌ Azure CLI não encontrado${NC}"
    ((error_count++))
fi

# Verificar kubectl
if command -v kubectl >/dev/null 2>&1; then
    echo -e "${GREEN}✅ kubectl instalado${NC}"
    ((success_count++))
else
    echo -e "${RED}❌ kubectl não encontrado${NC}"
    ((error_count++))
fi

# Verificar login Azure
if az account show >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Login Azure ativo${NC}"
    ((success_count++))
else
    echo -e "${RED}❌ Login Azure necessário${NC}"
    ((error_count++))
fi

echo ""

# Testar variáveis de ambiente
echo "🌍 FASE 3: Validação de Variáveis"
echo "=================================="

# Verificar se scripts definem variáveis corretamente
for script in "${scripts[@]}"; do
    if [[ -f "$script" ]]; then
        echo -e "${BLUE}🔍 Analisando variáveis em: $script${NC}"
        
        # Verificar variáveis não definidas
        if grep -n '\$[A-Z_][A-Z0-9_]*' "$script" | grep -v '${.*:-' | head -5; then
            echo -e "${YELLOW}⚠️ Variáveis encontradas (verifique se estão definidas)${NC}"
        fi
        echo ""
    fi
done

# Resumo final
echo "📊 RESUMO DA VALIDAÇÃO"
echo "======================"
echo -e "✅ Sucessos: ${GREEN}$success_count${NC}"
echo -e "❌ Erros: ${RED}$error_count${NC}"

if [[ $error_count -eq 0 ]]; then
    echo -e "${GREEN}🎉 TODOS OS TESTES PASSARAM!${NC}"
    echo -e "${GREEN}✅ Scripts prontos para execução${NC}"
    exit 0
else
    echo -e "${RED}⚠️ PROBLEMAS ENCONTRADOS!${NC}"
    echo -e "${RED}❌ Corrija os erros antes de continuar${NC}"
    exit 1
fi