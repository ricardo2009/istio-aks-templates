#!/bin/bash

# ===============================================================================
# TERRAFORM MODULES AUTOMATED FIX SCRIPT
# ===============================================================================
# Script para corrigir automaticamente incompatibilidades nos módulos Terraform
# Desenvolvido por especialista em arquiteturas cloud-native
# ===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "🔧 Iniciando correção automatizada dos módulos Terraform..."
echo "📁 Diretório do projeto: $PROJECT_ROOT"

# ===============================================================================
# FUNÇÃO: Criar variables.tf para módulos faltantes
# ===============================================================================
create_missing_variables() {
    local module_path="$1"
    local module_name="$(basename "$module_path")"
    
    if [[ ! -f "$module_path/variables.tf" ]]; then
        echo "📝 Criando variables.tf para módulo $module_name..."
        
        case "$module_name" in
            "cross-cluster")
                cat > "$module_path/variables.tf" << 'EOF'
# CROSS-CLUSTER MODULE - VARIABLES
variable "primary_cluster" {
  description = "Configuração do cluster primário"
  type = object({
    name     = string
    endpoint = string
    ca_cert  = string
    token    = string
  })
}

variable "secondary_cluster" {
  description = "Configuração do cluster secundário"
  type = object({
    name     = string
    endpoint = string
    ca_cert  = string
    token    = string
  })
}

variable "loadtest_cluster" {
  description = "Configuração do cluster de load testing"
  type = object({
    name     = string
    endpoint = string
    ca_cert  = string
    token    = string
  })
}

variable "cluster_ca_certificates" {
  description = "Certificados CA dos clusters"
  type        = map(string)
}

variable "cluster_tokens" {
  description = "Tokens dos clusters"
  type        = map(string)
  sensitive   = true
}

variable "cluster_endpoints" {
  description = "Endpoints dos clusters"
  type        = map(string)
}

variable "istio_namespace" {
  description = "Namespace do Istio"
  type        = string
  default     = "istio-system"
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
EOF
                ;;
                
            "nginx-keda")
                cat > "$module_path/variables.tf" << 'EOF'
# NGINX-KEDA MODULE - VARIABLES
variable "cluster_config" {
  description = "Configuração do cluster Kubernetes"
  type = object({
    host                   = string
    client_certificate     = string
    client_key            = string
    cluster_ca_certificate = string
  })
}

variable "nginx_namespace" {
  description = "Namespace do NGINX Ingress"
  type        = string
  default     = "nginx-ingress"
}

variable "keda_namespace" {
  description = "Namespace do KEDA"
  type        = string
  default     = "keda"
}

variable "nginx_replica_count" {
  description = "Número de réplicas do NGINX"
  type        = number
  default     = 3
}

variable "enable_prometheus_metrics" {
  description = "Habilitar métricas do Prometheus"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
EOF
                ;;
                
            "load-testing")
                cat > "$module_path/variables.tf" << 'EOF'
# LOAD-TESTING MODULE - VARIABLES
variable "cluster_config" {
  description = "Configuração do cluster de load testing"
  type = object({
    name                   = string
    host                   = string
    client_certificate     = string
    client_key            = string
    cluster_ca_certificate = string
  })
}

variable "namespace" {
  description = "Namespace para ferramentas de load testing"
  type        = string
  default     = "load-testing"
}

variable "target_endpoints" {
  description = "Endpoints alvo para testes de carga"
  type        = list(string)
}

variable "max_rps" {
  description = "RPS máximo para testes"
  type        = number
  default     = 600000
}

variable "test_duration" {
  description = "Duração dos testes"
  type        = string
  default     = "10m"
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
}
EOF
                ;;
        esac
    fi
}

# ===============================================================================
# FUNÇÃO: Corrigir main.tf principal
# ===============================================================================
fix_main_terraform() {
    echo "🔧 Corrigindo main.tf principal..."
    
    # Backup do arquivo original
    cp "$TERRAFORM_DIR/main.tf" "$TERRAFORM_DIR/main.tf.backup"
    
    # Corrigir módulo cross_cluster
    sed -i '/module "cross_cluster"/,/^}$/{
        s/primary_cluster_name.*/primary_cluster = {/
        s/primary_cluster_resource_group.*/  name     = module.azure_infrastructure.clusters.primary.name/
        s/primary_cluster_endpoint.*/  endpoint = module.azure_infrastructure.clusters.primary.host/
        /secondary_cluster_name/i\    ca_cert  = module.azure_infrastructure.clusters.primary.cluster_ca_certificate\
    token    = ""\
  }\
\
  secondary_cluster = {
        s/secondary_cluster_name.*/    name     = module.azure_infrastructure.clusters.secondary.name/
        s/secondary_cluster_resource_group.*/    endpoint = module.azure_infrastructure.clusters.secondary.host/
        s/secondary_cluster_endpoint.*/    ca_cert  = module.azure_infrastructure.clusters.secondary.cluster_ca_certificate\
    token    = ""\
  }\
\
  loadtest_cluster = {\
    name     = module.azure_infrastructure.clusters.loadtest.name\
    endpoint = module.azure_infrastructure.clusters.loadtest.host\
    ca_cert  = module.azure_infrastructure.clusters.loadtest.cluster_ca_certificate\
    token    = ""\
  }\
\
  cluster_ca_certificates = {\
    primary   = module.azure_infrastructure.clusters.primary.cluster_ca_certificate\
    secondary = module.azure_infrastructure.clusters.secondary.cluster_ca_certificate\
    loadtest  = module.azure_infrastructure.clusters.loadtest.cluster_ca_certificate\
  }\
\
  cluster_tokens = {\
    primary   = ""\
    secondary = ""\
    loadtest  = ""\
  }\
\
  cluster_endpoints = {\
    primary   = module.azure_infrastructure.clusters.primary.host\
    secondary = module.azure_infrastructure.clusters.secondary.host\
    loadtest  = module.azure_infrastructure.clusters.loadtest.host\
  }/
    }' "$TERRAFORM_DIR/main.tf"
    
    # Corrigir módulo nginx_keda
    sed -i '/module "nginx_keda"/,/^}$/{
        s/cluster_name.*/cluster_config = {/
        s/cluster_endpoint.*/  host                   = module.azure_infrastructure.clusters.primary.host/
        /tags/i\    client_certificate     = module.azure_infrastructure.clusters.primary.client_certificate\
    client_key            = module.azure_infrastructure.clusters.primary.client_key\
    cluster_ca_certificate = module.azure_infrastructure.clusters.primary.cluster_ca_certificate\
  }
    }' "$TERRAFORM_DIR/main.tf"
    
    # Corrigir módulo load_testing
    sed -i '/module "load_testing"/,/^}$/{
        s/cluster_name.*/cluster_config = {/
        s/cluster_endpoint.*/  name                   = module.azure_infrastructure.clusters.loadtest.name/
        /target_rps/i\    host                   = module.azure_infrastructure.clusters.loadtest.host\
    client_certificate     = module.azure_infrastructure.clusters.loadtest.client_certificate\
    client_key            = module.azure_infrastructure.clusters.loadtest.client_key\
    cluster_ca_certificate = module.azure_infrastructure.clusters.loadtest.cluster_ca_certificate\
  }\
\
  target_endpoints = [\
    module.azure_infrastructure.clusters.primary.host,\
    module.azure_infrastructure.clusters.secondary.host\
  ]
        s/target_rps.*/max_rps = 600000/
    }' "$TERRAFORM_DIR/main.tf"
}

# ===============================================================================
# FUNÇÃO: Adicionar outputs faltantes
# ===============================================================================
add_missing_outputs() {
    echo "📤 Adicionando outputs faltantes..."
    
    # Adicionar outputs ao módulo azure-infrastructure
    if ! grep -q "aks_primary_name" "$TERRAFORM_DIR/modules/azure-infrastructure/outputs.tf"; then
        cat >> "$TERRAFORM_DIR/modules/azure-infrastructure/outputs.tf" << 'EOF'

# Individual Cluster Outputs for Compatibility
output "aks_primary_name" {
  description = "Nome do cluster AKS primário"
  value       = azurerm_kubernetes_cluster.primary.name
}

output "aks_secondary_name" {
  description = "Nome do cluster AKS secundário"
  value       = azurerm_kubernetes_cluster.secondary.name
}

output "aks_loadtest_name" {
  description = "Nome do cluster AKS de load testing"
  value       = azurerm_kubernetes_cluster.loadtest.name
}

output "aks_primary_fqdn" {
  description = "FQDN do cluster AKS primário"
  value       = azurerm_kubernetes_cluster.primary.fqdn
}

output "aks_secondary_fqdn" {
  description = "FQDN do cluster AKS secundário"
  value       = azurerm_kubernetes_cluster.secondary.fqdn
}

output "aks_loadtest_fqdn" {
  description = "FQDN do cluster AKS de load testing"
  value       = azurerm_kubernetes_cluster.loadtest.fqdn
}

output "log_analytics_workspace_id" {
  description = "ID do Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "application_insights_id" {
  description = "ID do Application Insights"
  value       = azurerm_application_insights.main.id
}
EOF
    fi
}

# ===============================================================================
# EXECUÇÃO PRINCIPAL
# ===============================================================================

echo "🚀 Iniciando processo de correção..."

# Criar variables.tf para módulos faltantes
for module_dir in "$TERRAFORM_DIR/modules"/*; do
    if [[ -d "$module_dir" ]]; then
        create_missing_variables "$module_dir"
    fi
done

# Adicionar outputs faltantes
add_missing_outputs

# Corrigir main.tf principal
fix_main_terraform

echo "✅ Correções aplicadas com sucesso!"
echo "🔍 Executando validação do Terraform..."

cd "$TERRAFORM_DIR"
if terraform validate; then
    echo "✅ Validação do Terraform bem-sucedida!"
else
    echo "❌ Ainda há erros na configuração do Terraform"
    echo "📋 Restaurando backup..."
    mv "$TERRAFORM_DIR/main.tf.backup" "$TERRAFORM_DIR/main.tf"
    exit 1
fi

echo "🎉 Correção automatizada concluída com sucesso!"
