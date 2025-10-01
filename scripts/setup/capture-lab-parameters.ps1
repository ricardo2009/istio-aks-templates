<#
.SYNOPSIS
    Script para capturar TODOS os parâmetros do laboratório AKS de forma DINÂMICA

.DESCRIPTION
    Este script captura todos os parâmetros necessários do cluster AKS e recursos Azure
    para que o laboratório possa ser DELETADO e RECRIADO sem hardcoded values.
    
    IMPORTANTE: Execute este script SEMPRE que recriar o laboratório!

.NOTES
    Arquivo: capture-lab-parameters.ps1
    Autor: Lab AKS Istio
    Versão: 1.0
    Data: 2025-10-01
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "../../aks-labs.config"
)

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CAPTURA DE PARÂMETROS DINÂMICOS DO LABORATÓRIO AKS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# SEÇÃO 1: VERIFICAR PRÉ-REQUISITOS
# =============================================================================
Write-Host "[1/7] Verificando pré-requisitos..." -ForegroundColor Yellow

# Verificar se Azure CLI está instalado
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Host "  ✓ Azure CLI versão: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Azure CLI não encontrado! Instale: https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}

# Verificar se kubectl está instalado
try {
    $kubectlVersion = kubectl version --client --output=json 2>$null | ConvertFrom-Json
    Write-Host "  ✓ kubectl instalado" -ForegroundColor Green
} catch {
    Write-Host "  ✗ kubectl não encontrado! Instale com: az aks install-cli" -ForegroundColor Red
    exit 1
}

# Verificar se está logado no Azure
try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    Write-Host "  ✓ Logado no Azure como: $($account.user.name)" -ForegroundColor Green
    Write-Host "  ✓ Subscription: $($account.name) ($($account.id))" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Não está logado no Azure! Execute: az login" -ForegroundColor Red
    exit 1
}

# =============================================================================
# SEÇÃO 2: CAPTURAR INFORMAÇÕES DO CLUSTER AKS
# =============================================================================
Write-Host ""
Write-Host "[2/7] Capturando informações do cluster AKS..." -ForegroundColor Yellow

# Perguntar ao usuário os nomes (já que podem variar)
$RESOURCE_GROUP = Read-Host "  Nome do Resource Group (pressione Enter para 'rg-aks-labs')"
if ([string]::IsNullOrWhiteSpace($RESOURCE_GROUP)) { $RESOURCE_GROUP = "rg-aks-labs" }

$CLUSTER_NAME = Read-Host "  Nome do Cluster AKS (pressione Enter para 'aks-labs')"
if ([string]::IsNullOrWhiteSpace($CLUSTER_NAME)) { $CLUSTER_NAME = "aks-labs" }

# Buscar informações do cluster
try {
    $clusterInfo = az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --output json | ConvertFrom-Json
    
    $CLUSTER_LOCATION = $clusterInfo.location
    $CLUSTER_K8S_VERSION = $clusterInfo.kubernetesVersion
    $CLUSTER_NODE_COUNT = $clusterInfo.agentPoolProfiles[0].count
    $CLUSTER_NODE_SIZE = $clusterInfo.agentPoolProfiles[0].vmSize
    $CLUSTER_SUBSCRIPTION_ID = $clusterInfo.id.Split('/')[2]
    
    Write-Host "  ✓ Cluster encontrado:" -ForegroundColor Green
    Write-Host "    - Nome: $CLUSTER_NAME" -ForegroundColor Gray
    Write-Host "    - Resource Group: $RESOURCE_GROUP" -ForegroundColor Gray
    Write-Host "    - Localização: $CLUSTER_LOCATION" -ForegroundColor Gray
    Write-Host "    - Versão K8s: $CLUSTER_K8S_VERSION" -ForegroundColor Gray
    Write-Host "    - Nós: $CLUSTER_NODE_COUNT x $CLUSTER_NODE_SIZE" -ForegroundColor Gray
    
} catch {
    Write-Host "  ✗ Erro ao buscar cluster! Verifique se o nome está correto." -ForegroundColor Red
    Write-Host "    Erro: $_" -ForegroundColor Red
    exit 1
}

# =============================================================================
# SEÇÃO 3: CAPTURAR INFORMAÇÕES DO ISTIO GATEWAY
# =============================================================================
Write-Host ""
Write-Host "[3/7] Capturando informações do Istio Gateway..." -ForegroundColor Yellow

try {
    # Buscar IP externo do Istio Ingress Gateway
    $gatewayIP = kubectl get svc aks-istio-ingressgateway-external -n aks-istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    
    if ([string]::IsNullOrWhiteSpace($gatewayIP)) {
        Write-Host "  ⚠ Gateway IP não encontrado ainda. Aguardando provisionamento..." -ForegroundColor Yellow
        Write-Host "    Execute novamente após o LoadBalancer estar ativo." -ForegroundColor Yellow
        $GATEWAY_IP = "PENDING"
        $GATEWAY_DNS_PRIMARY = "PENDING"
        $GATEWAY_DNS_SECONDARY = "PENDING"
    } else {
        $GATEWAY_IP = $gatewayIP
        $GATEWAY_DNS_PRIMARY = "$GATEWAY_IP.nip.io"
        $GATEWAY_DNS_SECONDARY = "www.$GATEWAY_IP.nip.io"
        
        Write-Host "  ✓ Gateway configurado:" -ForegroundColor Green
        Write-Host "    - IP Externo: $GATEWAY_IP" -ForegroundColor Gray
        Write-Host "    - DNS Primário: $GATEWAY_DNS_PRIMARY" -ForegroundColor Gray
        Write-Host "    - DNS Secundário: $GATEWAY_DNS_SECONDARY" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "  ⚠ Erro ao buscar Gateway. Pode não estar configurado ainda." -ForegroundColor Yellow
    $GATEWAY_IP = "NOT_CONFIGURED"
    $GATEWAY_DNS_PRIMARY = "NOT_CONFIGURED"
    $GATEWAY_DNS_SECONDARY = "NOT_CONFIGURED"
}

# =============================================================================
# SEÇÃO 4: CAPTURAR/DEFINIR CONFIGURAÇÕES DE EMAIL
# =============================================================================
Write-Host ""
Write-Host "[4/7] Configurando email para Let's Encrypt..." -ForegroundColor Yellow

Write-Host "  ℹ O Let's Encrypt requer um email válido para notificações." -ForegroundColor Cyan
Write-Host "    - Não pode ser de domínios genéricos (example.com)" -ForegroundColor Cyan
Write-Host "    - Não pode terminar em .local" -ForegroundColor Cyan
Write-Host "    - Deve ser um domínio público válido" -ForegroundColor Cyan
Write-Host ""

$LETSENCRYPT_EMAIL = Read-Host "  Digite seu email (ex: admin@seudominio.com.br)"

# Validar email básico
if ($LETSENCRYPT_EMAIL -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
    Write-Host "  ⚠ Email parece inválido, mas será salvo mesmo assim." -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Email configurado: $LETSENCRYPT_EMAIL" -ForegroundColor Green
}

# =============================================================================
# SEÇÃO 5: VERIFICAR AZURE MONITOR
# =============================================================================
Write-Host ""
Write-Host "[5/7] Verificando Azure Monitor (Prometheus Gerenciado)..." -ForegroundColor Yellow

try {
    $azureMonitorProfile = az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "azureMonitorProfile" --output json | ConvertFrom-Json
    
    if ($null -eq $azureMonitorProfile -or $null -eq $azureMonitorProfile.metrics) {
        Write-Host "  ⚠ Azure Monitor NÃO está habilitado neste cluster!" -ForegroundColor Yellow
        Write-Host "    Será necessário habilitar no tutorial." -ForegroundColor Yellow
        $AZURE_MONITOR_ENABLED = "false"
        $AZURE_MONITOR_WORKSPACE_ID = "NOT_CONFIGURED"
    } else {
        Write-Host "  ✓ Azure Monitor está HABILITADO!" -ForegroundColor Green
        $AZURE_MONITOR_ENABLED = "true"
        
        # Tentar obter workspace ID
        if ($azureMonitorProfile.metrics.workspaceResourceId) {
            $AZURE_MONITOR_WORKSPACE_ID = $azureMonitorProfile.metrics.workspaceResourceId
            Write-Host "    - Workspace ID: $AZURE_MONITOR_WORKSPACE_ID" -ForegroundColor Gray
        } else {
            $AZURE_MONITOR_WORKSPACE_ID = "ENABLED_BUT_NO_WORKSPACE"
        }
    }
} catch {
    Write-Host "  ⚠ Não foi possível verificar Azure Monitor" -ForegroundColor Yellow
    $AZURE_MONITOR_ENABLED = "unknown"
    $AZURE_MONITOR_WORKSPACE_ID = "UNKNOWN"
}

# =============================================================================
# SEÇÃO 6: VERIFICAR KEY VAULT (se existir)
# =============================================================================
Write-Host ""
Write-Host "[6/7] Verificando Azure Key Vault..." -ForegroundColor Yellow

# Buscar Key Vaults no resource group
try {
    $keyVaults = az keyvault list --resource-group $RESOURCE_GROUP --output json | ConvertFrom-Json
    
    if ($keyVaults.Count -eq 0) {
        Write-Host "  ⚠ Nenhum Key Vault encontrado no resource group" -ForegroundColor Yellow
        Write-Host "    Será criado no tutorial." -ForegroundColor Yellow
        $KEYVAULT_NAME = "NOT_CREATED"
        $KEYVAULT_ID = "NOT_CREATED"
    } else {
        # Se houver múltiplos, perguntar qual usar
        if ($keyVaults.Count -eq 1) {
            $selectedKV = $keyVaults[0]
        } else {
            Write-Host "  ℹ Múltiplos Key Vaults encontrados:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $keyVaults.Count; $i++) {
                Write-Host "    [$i] $($keyVaults[$i].name)" -ForegroundColor Gray
            }
            $selection = Read-Host "  Selecione o número do Key Vault a usar (ou Enter para criar novo)"
            
            if ([string]::IsNullOrWhiteSpace($selection)) {
                $KEYVAULT_NAME = "NOT_CREATED"
                $KEYVAULT_ID = "NOT_CREATED"
                Write-Host "  ℹ Será criado um novo Key Vault" -ForegroundColor Cyan
            } else {
                $selectedKV = $keyVaults[[int]$selection]
            }
        }
        
        if ($selectedKV) {
            $KEYVAULT_NAME = $selectedKV.name
            $KEYVAULT_ID = $selectedKV.id
            Write-Host "  ✓ Key Vault selecionado:" -ForegroundColor Green
            Write-Host "    - Nome: $KEYVAULT_NAME" -ForegroundColor Gray
            Write-Host "    - ID: $KEYVAULT_ID" -ForegroundColor Gray
        }
    }
} catch {
    Write-Host "  ⚠ Erro ao buscar Key Vaults" -ForegroundColor Yellow
    $KEYVAULT_NAME = "ERROR"
    $KEYVAULT_ID = "ERROR"
}

# =============================================================================
# SEÇÃO 7: SALVAR CONFIGURAÇÃO
# =============================================================================
Write-Host ""
Write-Host "[7/7] Salvando configuração..." -ForegroundColor Yellow

$configContent = @"
# ============================================================================
# CONFIGURAÇÃO DO LABORATÓRIO AKS - PARÂMETROS DINÂMICOS
# ============================================================================
# Este arquivo foi gerado automaticamente em: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# 
# IMPORTANTE: Este arquivo contém TODOS os parâmetros capturados dinamicamente
# do seu ambiente Azure. Quando você DELETAR e RECRIAR o laboratório, execute
# novamente o script capture-lab-parameters.ps1 para atualizar estes valores.
#
# NÃO commite este arquivo com valores reais no Git!
# ============================================================================

# -----------------------------------------------------------------------------
# INFORMAÇÕES DA SUBSCRIPTION AZURE
# -----------------------------------------------------------------------------
AZURE_SUBSCRIPTION_ID=$CLUSTER_SUBSCRIPTION_ID
AZURE_TENANT_ID=$($account.tenantId)
AZURE_USER=$($account.user.name)

# -----------------------------------------------------------------------------
# INFORMAÇÕES DO CLUSTER AKS
# -----------------------------------------------------------------------------
CLUSTER_NAME=$CLUSTER_NAME
CLUSTER_RESOURCE_GROUP=$RESOURCE_GROUP
CLUSTER_LOCATION=$CLUSTER_LOCATION
CLUSTER_K8S_VERSION=$CLUSTER_K8S_VERSION
CLUSTER_NODE_COUNT=$CLUSTER_NODE_COUNT
CLUSTER_NODE_SIZE=$CLUSTER_NODE_SIZE

# -----------------------------------------------------------------------------
# INFORMAÇÕES DO ISTIO GATEWAY
# -----------------------------------------------------------------------------
GATEWAY_IP=$GATEWAY_IP
GATEWAY_DNS_PRIMARY=$GATEWAY_DNS_PRIMARY
GATEWAY_DNS_SECONDARY=$GATEWAY_DNS_SECONDARY
GATEWAY_NAMESPACE=aks-istio-ingress
GATEWAY_NAME=pets-gateway

# -----------------------------------------------------------------------------
# CONFIGURAÇÕES DE CERTIFICADOS (Let's Encrypt)
# -----------------------------------------------------------------------------
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
LETSENCRYPT_STAGING_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory
LETSENCRYPT_PROD_SERVER=https://acme-v02.api.letsencrypt.org/directory

# -----------------------------------------------------------------------------
# AZURE MONITOR (PROMETHEUS GERENCIADO)
# -----------------------------------------------------------------------------
AZURE_MONITOR_ENABLED=$AZURE_MONITOR_ENABLED
AZURE_MONITOR_WORKSPACE_ID=$AZURE_MONITOR_WORKSPACE_ID

# -----------------------------------------------------------------------------
# AZURE KEY VAULT
# -----------------------------------------------------------------------------
KEYVAULT_NAME=$KEYVAULT_NAME
KEYVAULT_ID=$KEYVAULT_ID

# -----------------------------------------------------------------------------
# NAMESPACE DA APLICAÇÃO
# -----------------------------------------------------------------------------
APP_NAMESPACE=pets
APP_NAME=store-front

# -----------------------------------------------------------------------------
# CONFIGURAÇÕES DO FLAGGER
# -----------------------------------------------------------------------------
FLAGGER_NAMESPACE=istio-system
FLAGGER_METRICS_SERVER=AZURE_MONITOR  # Será configurado para usar Azure Monitor

# -----------------------------------------------------------------------------
# FIM DA CONFIGURAÇÃO
# -----------------------------------------------------------------------------
"@

# Salvar arquivo
$configPath = Join-Path $PSScriptRoot $ConfigFile
$configContent | Out-File -FilePath $configPath -Encoding UTF8 -Force

Write-Host "  ✓ Configuração salva em: $configPath" -ForegroundColor Green

# =============================================================================
# RESUMO FINAL
# =============================================================================
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESUMO DA CAPTURA" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Cluster AKS:" -ForegroundColor White
Write-Host "  • Nome: $CLUSTER_NAME" -ForegroundColor Gray
Write-Host "  • Resource Group: $RESOURCE_GROUP" -ForegroundColor Gray
Write-Host "  • Localização: $CLUSTER_LOCATION" -ForegroundColor Gray
Write-Host ""
Write-Host "Gateway Istio:" -ForegroundColor White
Write-Host "  • IP: $GATEWAY_IP" -ForegroundColor Gray
Write-Host "  • DNS: $GATEWAY_DNS_PRIMARY" -ForegroundColor Gray
Write-Host ""
Write-Host "Azure Monitor:" -ForegroundColor White
Write-Host "  • Habilitado: $AZURE_MONITOR_ENABLED" -ForegroundColor Gray
Write-Host ""
Write-Host "Key Vault:" -ForegroundColor White
Write-Host "  • Nome: $KEYVAULT_NAME" -ForegroundColor Gray
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "✓ Todos os parâmetros foram capturados e salvos!" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "  1. Revisar o arquivo: $configPath" -ForegroundColor Gray
Write-Host "  2. Seguir os tutoriais em docs/tutorials/" -ForegroundColor Gray
Write-Host "  3. Os scripts irão carregar estes parâmetros automaticamente" -ForegroundColor Gray
Write-Host ""
