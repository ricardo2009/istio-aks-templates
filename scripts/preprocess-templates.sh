#!/bin/bash

# =============================================================================
# ISTIO TEMPLATE PREPROCESSOR
# =============================================================================
# Preprocessador avançado para templates Istio com suporte total ao GitHub Actions
# Processa condicionais, resolve variáveis e prepara templates para deployment
# 
# Funcionalidades:
# - Processamento de condicionais (CONDITIONAL_START/END)
# - Resolução de variáveis de ambiente
# - Validação de templates
# - Suporte a overlays de ambiente
# - Integração nativa com GitHub Actions
# - Logging estruturado
# - Cache de templates processados

set -euo pipefail

# =============================================================================
# CONFIGURAÇÃO E VARIÁVEIS GLOBAIS
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="${PROJECT_ROOT}/templates"
OVERLAYS_DIR="${PROJECT_ROOT}/overlays"
OUTPUT_DIR="${PROJECT_ROOT}/.generated"
CACHE_DIR="${PROJECT_ROOT}/.cache"
VALUES_FILE="${PROJECT_ROOT}/values.yaml"

# GitHub Actions integration
GITHUB_ACTIONS="${GITHUB_ACTIONS:-false}"
GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-$PROJECT_ROOT}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/dev/stdout}"
GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"

# Configurações
ENVIRONMENT="${1:-dev}"
APP_NAME="${2:-myapp}"
NAMESPACE="${3:-default}"
DRY_RUN="${DRY_RUN:-false}"
VALIDATE_ONLY="${VALIDATE_ONLY:-false}"
CACHE_ENABLED="${CACHE_ENABLED:-true}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Cores para output (desabilitadas no GitHub Actions)
if [[ "$GITHUB_ACTIONS" != "true" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    PURPLE='\033[0;35m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    PURPLE=''
    NC=''
fi

# =============================================================================
# FUNÇÕES DE LOGGING E UTILITÁRIOS
# =============================================================================

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[$timestamp] [ERROR]${NC} $message" >&2
            if [[ "$GITHUB_ACTIONS" == "true" ]]; then
                echo "::error::$message"
            fi
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] [WARN]${NC} $message" >&2
            if [[ "$GITHUB_ACTIONS" == "true" ]]; then
                echo "::warning::$message"
            fi
            ;;
        "INFO")
            echo -e "${GREEN}[$timestamp] [INFO]${NC} $message"
            ;;
        "DEBUG")
            if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
                echo -e "${CYAN}[$timestamp] [DEBUG]${NC} $message"
            fi
            ;;
    esac
}

github_group() {
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        echo "::group::$1"
    else
        log "INFO" "📁 $1"
    fi
}

github_endgroup() {
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        echo "::endgroup::"
    fi
}

github_output() {
    local name="$1"
    local value="$2"
    
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        echo "${name}=${value}" >> "$GITHUB_OUTPUT"
    fi
    log "DEBUG" "Output: ${name}=${value}"
}

github_summary() {
    local content="$1"
    
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        echo "$content" >> "$GITHUB_STEP_SUMMARY"
    else
        echo -e "$content"
    fi
}

# =============================================================================
# FUNÇÕES DE VALIDAÇÃO E PRÉ-REQUISITOS
# =============================================================================

validate_prerequisites() {
    github_group "🔍 Validating Prerequisites"
    
    local missing_tools=()
    local required_tools=("yq" "envsubst" "kubectl")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -ne 0 ]]; then
        log "ERROR" "Missing required tools: ${missing_tools[*]}"
        log "ERROR" "Install missing tools before proceeding"
        exit 1
    fi
    
    # Validate project structure
    local required_dirs=("$TEMPLATES_DIR" "$OVERLAYS_DIR")
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log "ERROR" "Required directory not found: $dir"
            exit 1
        fi
    done
    
    if [[ ! -f "$VALUES_FILE" ]]; then
        log "ERROR" "Values file not found: $VALUES_FILE"
        exit 1
    fi
    
    log "INFO" "✅ All prerequisites validated successfully"
    github_endgroup
}

# =============================================================================
# FUNÇÕES DE CACHE
# =============================================================================

setup_cache() {
    if [[ "$CACHE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    mkdir -p "$CACHE_DIR"
    
    # Cache key baseado em hash dos arquivos
    local cache_key=$(find "$TEMPLATES_DIR" "$OVERLAYS_DIR" "$VALUES_FILE" -type f -exec sha256sum {} \; 2>/dev/null | sha256sum | cut -d' ' -f1)
    
    github_output "cache_key" "$cache_key"
    
    if [[ -f "$CACHE_DIR/$cache_key" ]]; then
        log "INFO" "📦 Cache hit for key: $cache_key"
        return 0
    else
        log "INFO" "🔄 Cache miss, will rebuild templates"
        echo "$cache_key" > "$CACHE_DIR/current_key"
        return 1
    fi
}

save_cache() {
    if [[ "$CACHE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    local cache_key=$(cat "$CACHE_DIR/current_key" 2>/dev/null || echo "unknown")
    touch "$CACHE_DIR/$cache_key"
    log "INFO" "💾 Cached templates with key: $cache_key"
}

# =============================================================================
# FUNÇÕES DE PROCESSAMENTO DE TEMPLATES
# =============================================================================

load_configuration() {
    github_group "⚙️ Loading Configuration"
    
    local overlay_file="$OVERLAYS_DIR/$ENVIRONMENT/values.yaml"
    local combined_values="$OUTPUT_DIR/combined-values.yaml"
    
    mkdir -p "$OUTPUT_DIR"
    
    # Combinar values.yaml com overlay
    if [[ -f "$overlay_file" ]]; then
        log "INFO" "Merging overlay: $overlay_file"
        yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$VALUES_FILE" "$overlay_file" > "$combined_values"
    else
        log "WARN" "No overlay found for environment: $ENVIRONMENT"
        cp "$VALUES_FILE" "$combined_values"
    fi
    
    # Exportar variáveis de ambiente a partir do YAML
    export_yaml_variables "$combined_values"
    
    log "INFO" "✅ Configuration loaded successfully"
    github_endgroup
}

export_yaml_variables() {
    local yaml_file="$1"
    
    log "DEBUG" "Exporting variables from: $yaml_file"
    
    # Variáveis globais
    export APP_NAME="${APP_NAME:-$(yq e '.global.app // "myapp"' "$yaml_file")}"
    export VERSION="$(yq e '.global.version // "1.0.0"' "$yaml_file")"
    export ENVIRONMENT="$ENVIRONMENT"
    export NAMESPACE="$NAMESPACE"
    export MANAGED_BY="$(yq e '.global.managedBy // "istio-templates"' "$yaml_file")"
    
    # Gateway variables
    export GATEWAY_NAME="${GATEWAY_NAME:-main-gateway}"
    export GATEWAY_SELECTOR="$(yq e '.trafficManagement.gateway.selector // "aks-istio-ingressgateway-external"' "$yaml_file")"
    export SERVICE_HOST="$(yq e '.trafficManagement.gateway.hosts[0] // "app.example.com"' "$yaml_file")"
    export SERVICE_HOST_ADDITIONAL="$(yq e '.trafficManagement.gateway.hosts[1] // ""' "$yaml_file")"
    export TLS_MODE="$(yq e '.trafficManagement.gateway.tls.mode // "SIMPLE"' "$yaml_file")"
    export TLS_CREDENTIAL_NAME="$(yq e '.trafficManagement.gateway.tls.credentialName // ""' "$yaml_file")"
    
    # Configurações condicionais
    export HTTP_SERVER_ENABLED="$(yq e '.trafficManagement.gateway.httpServer.enabled // true' "$yaml_file")"
    export HTTPS_REDIRECT="$(yq e '.trafficManagement.gateway.httpServer.httpsRedirect // true' "$yaml_file")"
    export GRPC_SERVER_ENABLED="$(yq e '.trafficManagement.gateway.grpcServer.enabled // false' "$yaml_file")"
    export TCP_SERVER_ENABLED="$(yq e '.trafficManagement.gateway.tcpServer.enabled // false' "$yaml_file")"
    export HTTPS_MUTUAL_ENABLED="$(yq e '.trafficManagement.gateway.httpsMutual.enabled // false' "$yaml_file")"
    export WEBSOCKET_SERVER_ENABLED="$(yq e '.trafficManagement.gateway.websocket.enabled // false' "$yaml_file")"
    export DB_SERVER_ENABLED="$(yq e '.trafficManagement.gateway.database.enabled // false' "$yaml_file")"
    export CUSTOM_SERVER_1_ENABLED="$(yq e '.trafficManagement.gateway.customServers.server1.enabled // false' "$yaml_file")"
    export CUSTOM_SERVER_2_ENABLED="$(yq e '.trafficManagement.gateway.customServers.server2.enabled // false' "$yaml_file")"
    
    # Configurações específicas por servidor
    if [[ "$GRPC_SERVER_ENABLED" == "true" ]]; then
        export GRPC_PORT="$(yq e '.trafficManagement.gateway.grpcServer.port // 443' "$yaml_file")"
        export GRPC_SERVICE_HOST="$(yq e '.trafficManagement.gateway.grpcServer.host // ""' "$yaml_file")"
        export GRPC_TLS_MODE="$(yq e '.trafficManagement.gateway.grpcServer.tls.mode // "SIMPLE"' "$yaml_file")"
    fi
    
    if [[ "$TCP_SERVER_ENABLED" == "true" ]]; then
        export TCP_PORT="$(yq e '.trafficManagement.gateway.tcpServer.port // 9000' "$yaml_file")"
        export TCP_SERVICE_HOST="$(yq e '.trafficManagement.gateway.tcpServer.host // ""' "$yaml_file")"
        export TCP_TLS_ENABLED="$(yq e '.trafficManagement.gateway.tcpServer.tls.enabled // false' "$yaml_file")"
    fi
    
    log "DEBUG" "Exported ${#} environment variables"
}

process_conditional_template() {
    local input_file="$1"
    local output_file="$2"
    
    log "DEBUG" "Processing conditionals in: $(basename "$input_file")"
    
    local temp_file=$(mktemp)
    local inside_conditional=false
    local conditional_var=""
    local include_section=false
    
    while IFS= read -r line; do
        # Detectar início de condicional
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*CONDITIONAL_START:[[:space:]]*([A-Z_0-9]+) ]]; then
            conditional_var="${BASH_REMATCH[1]}"
            inside_conditional=true
            
            # Verificar se a variável está definida e é true
            if [[ -n "${!conditional_var:-}" ]] && [[ "${!conditional_var}" == "true" ]]; then
                include_section=true
                log "DEBUG" "Including conditional section: $conditional_var"
            else
                include_section=false
                log "DEBUG" "Skipping conditional section: $conditional_var (${!conditional_var:-undefined})"
            fi
            continue
        fi
        
        # Detectar fim de condicional
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*CONDITIONAL_END:[[:space:]]*([A-Z_0-9]+) ]]; then
            inside_conditional=false
            include_section=false
            continue
        fi
        
        # Incluir linha se não estiver em condicional ou se condicional for true
        if [[ "$inside_conditional" == "false" ]] || [[ "$include_section" == "true" ]]; then
            # Remover comentários de configurações opcionais se a variável estiver definida
            if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*\$\{([A-Z_0-9]+)\} ]]; then
                local key="${BASH_REMATCH[1]}"
                local var_name="${BASH_REMATCH[2]}"
                if [[ -n "${!var_name:-}" ]]; then
                    # Remover comentário e incluir configuração
                    line=$(echo "$line" | sed 's/^[[:space:]]*#[[:space:]]*/    /')
                    log "DEBUG" "Activated optional config: $key"
                fi
            fi
            
            echo "$line" >> "$temp_file"
        fi
    done < "$input_file"
    
    mv "$temp_file" "$output_file"
}

process_templates() {
    github_group "🔄 Processing Templates"
    
    local templates_processed=0
    local processed_dir="$OUTPUT_DIR/processed"
    mkdir -p "$processed_dir"
    
    # Encontrar todos os templates
    local template_categories=("traffic-management" "security" "observability" "resilience" "policies-governance" "extensibility" "additional-features")
    
    for category in "${template_categories[@]}"; do
        local category_dir="$TEMPLATES_DIR/$category"
        
        if [[ ! -d "$category_dir" ]]; then
            log "WARN" "Category directory not found: $category"
            continue
        fi
        
        log "INFO" "Processing category: $category"
        
        for template_file in "$category_dir"/*.yaml; do
            if [[ ! -f "$template_file" ]]; then
                continue
            fi
            
            local template_name=$(basename "$template_file")
            local temp_conditional="$processed_dir/${template_name}.conditional"
            local temp_envsubst="$processed_dir/${template_name}.envsubst"
            local final_output="$processed_dir/$template_name"
            
            log "INFO" "  📄 Processing: $template_name"
            
            # Passo 1: Processar condicionais
            process_conditional_template "$template_file" "$temp_conditional"
            
            # Passo 2: Substituir variáveis com envsubst
            envsubst < "$temp_conditional" > "$temp_envsubst" 2>/dev/null || {
                log "WARN" "Some variables in $template_name were not substituted"
                envsubst < "$temp_conditional" > "$temp_envsubst"
            }
            
            # Passo 3: Limpar e finalizar
            # Remover linhas vazias excessivas e comentários não utilizados
            awk '
            /^[[:space:]]*$/ { 
                if (!empty_line_printed) {
                    print; 
                    empty_line_printed = 1;
                } 
                next; 
            }
            /^[[:space:]]*#/ && !/istio-templates\.io/ { next; }
            { print; empty_line_printed = 0; }
            ' "$temp_envsubst" > "$final_output"
            
            # Cleanup arquivos temporários
            rm -f "$temp_conditional" "$temp_envsubst"
            
            ((templates_processed++))
        done
    done
    
    log "INFO" "✅ Processed $templates_processed templates successfully"
    github_output "templates_processed" "$templates_processed"
    github_endgroup
}

# =============================================================================
# FUNÇÕES DE VALIDAÇÃO
# =============================================================================

validate_templates() {
    github_group "✅ Validating Templates"
    
    local processed_dir="$OUTPUT_DIR/processed"
    local validation_errors=0
    local validation_warnings=0
    local validated_templates=0
    
    # Create validation report
    local validation_report="$OUTPUT_DIR/validation-report.md"
    echo "# Template Validation Report" > "$validation_report"
    echo "" >> "$validation_report"
    echo "**Environment:** $ENVIRONMENT" >> "$validation_report"
    echo "**Application:** $APP_NAME" >> "$validation_report"
    echo "**Namespace:** $NAMESPACE" >> "$validation_report"
    echo "**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$validation_report"
    echo "" >> "$validation_report"
    echo "## Validation Results" >> "$validation_report"
    echo "" >> "$validation_report"
    
    for manifest in "$processed_dir"/*.yaml; do
        if [[ ! -f "$manifest" ]]; then
            continue
        fi
        
        local manifest_name=$(basename "$manifest")
        log "INFO" "  🔍 Validating: $manifest_name"
        
        # YAML syntax validation
        if ! yq e '.' "$manifest" > /dev/null 2>&1; then
            log "ERROR" "YAML syntax error in $manifest_name"
            echo "- ❌ **$manifest_name**: YAML syntax error" >> "$validation_report"
            ((validation_errors++))
            continue
        fi
        
        # Kubernetes API validation
        local kubectl_output
        if kubectl_output=$(kubectl --dry-run=client apply -f "$manifest" 2>&1); then
            log "INFO" "    ✅ Kubernetes validation passed"
            echo "- ✅ **$manifest_name**: Valid Kubernetes manifest" >> "$validation_report"
        else
            log "ERROR" "Kubernetes validation failed for $manifest_name"
            log "ERROR" "kubectl output: $kubectl_output"
            echo "- ❌ **$manifest_name**: Kubernetes validation failed" >> "$validation_report"
            echo "  \`\`\`" >> "$validation_report"
            echo "  $kubectl_output" >> "$validation_report"
            echo "  \`\`\`" >> "$validation_report"
            ((validation_errors++))
            continue
        fi
        
        # Istio-specific validation
        validate_istio_manifest "$manifest" "$manifest_name" "$validation_report"
        
        ((validated_templates++))
    done
    
    # Finalizar relatório
    echo "" >> "$validation_report"
    echo "## Summary" >> "$validation_report"
    echo "" >> "$validation_report"
    echo "- **Templates Validated:** $validated_templates" >> "$validation_report"
    echo "- **Errors:** $validation_errors" >> "$validation_report"
    echo "- **Warnings:** $validation_warnings" >> "$validation_report"
    
    # Output para GitHub Actions
    github_output "validation_errors" "$validation_errors"
    github_output "validation_warnings" "$validation_warnings"
    github_output "validated_templates" "$validated_templates"
    
    # Anexar relatório ao GitHub Step Summary
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        cat "$validation_report" >> "$GITHUB_STEP_SUMMARY"
    fi
    
    if [[ $validation_errors -gt 0 ]]; then
        log "ERROR" "❌ $validation_errors template(s) failed validation"
        github_endgroup
        exit 1
    fi
    
    log "INFO" "✅ All $validated_templates templates validated successfully"
    if [[ $validation_warnings -gt 0 ]]; then
        log "WARN" "⚠️ $validation_warnings warning(s) found"
    fi
    
    github_endgroup
}

validate_istio_manifest() {
    local manifest="$1"
    local manifest_name="$2"
    local report_file="$3"
    
    local kind=$(yq e '.kind' "$manifest")
    local warnings=0
    
    case "$kind" in
        "Gateway")
            # Validar seletores AKS
            local selector=$(yq e '.spec.selector.istio' "$manifest")
            if [[ "$selector" != "aks-istio-ingressgateway-external" ]] && [[ "$selector" != "aks-istio-ingressgateway-internal" ]]; then
                log "WARN" "    ⚠️ Non-standard AKS gateway selector: $selector"
                echo "  - ⚠️ Non-standard AKS gateway selector: \`$selector\`" >> "$report_file"
                ((warnings++))
            fi
            
            # Validar hosts
            local hosts=$(yq e '.spec.servers[].hosts[]' "$manifest" 2>/dev/null | wc -l)
            if [[ $hosts -eq 0 ]]; then
                log "WARN" "    ⚠️ No hosts defined in Gateway"
                echo "  - ⚠️ No hosts defined in Gateway" >> "$report_file"
                ((warnings++))
            fi
            ;;
        "VirtualService")
            # Validar referências de gateway
            local gateways=$(yq e '.spec.gateways[]?' "$manifest" 2>/dev/null)
            if [[ -z "$gateways" ]]; then
                log "WARN" "    ⚠️ No gateways referenced in VirtualService"
                echo "  - ⚠️ No gateways referenced in VirtualService" >> "$report_file"
                ((warnings++))
            fi
            ;;
        "DestinationRule")
            # Validar configurações de traffic policy
            local has_traffic_policy=$(yq e '.spec.trafficPolicy // empty' "$manifest")
            if [[ -z "$has_traffic_policy" ]]; then
                log "WARN" "    ⚠️ No traffic policy defined in DestinationRule"
                echo "  - ⚠️ No traffic policy defined in DestinationRule" >> "$report_file"
                ((warnings++))
            fi
            ;;
    esac
    
    return $warnings
}

# =============================================================================
# FUNÇÃO PRINCIPAL
# =============================================================================

main() {
    local start_time=$(date +%s)
    
    log "INFO" "🚀 Starting Istio Template Preprocessor"
    log "INFO" "Environment: $ENVIRONMENT"
    log "INFO" "Application: $APP_NAME"
    log "INFO" "Namespace: $NAMESPACE"
    log "INFO" "GitHub Actions: $GITHUB_ACTIONS"
    
    # Setup
    validate_prerequisites
    
    # Cache check
    if setup_cache; then
        log "INFO" "📦 Using cached templates"
        github_output "cache_hit" "true"
        if [[ "$VALIDATE_ONLY" != "true" ]]; then
            exit 0
        fi
    else
        github_output "cache_hit" "false"
    fi
    
    # Processamento principal
    load_configuration
    process_templates
    validate_templates
    
    # Cache save
    save_cache
    
    # Metrics e summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    github_output "processing_duration" "$duration"
    github_output "output_directory" "$OUTPUT_DIR/processed"
    
    log "INFO" "✅ Processing completed successfully in ${duration}s"
    
    # Summary para GitHub Actions
    if [[ "$GITHUB_ACTIONS" == "true" ]]; then
        cat << EOF >> "$GITHUB_STEP_SUMMARY"

## 🎯 Processing Summary

- **Environment**: $ENVIRONMENT  
- **Application**: $APP_NAME
- **Namespace**: $NAMESPACE
- **Duration**: ${duration}s
- **Output Directory**: \`$OUTPUT_DIR/processed\`

### Next Steps
1. Review the processed templates in the output directory
2. Deploy using kubectl or your preferred deployment tool
3. Monitor the application using Istio observability features

EOF
    fi
}

# Help function
show_help() {
    cat << EOF
Istio Template Preprocessor

USAGE:
    $0 [environment] [app_name] [namespace]

ARGUMENTS:
    environment     Target environment (dev|staging|prod) [default: dev]
    app_name        Application name [default: myapp]
    namespace       Kubernetes namespace [default: default]

ENVIRONMENT VARIABLES:
    DRY_RUN            Only process templates, don't validate [default: false]
    VALIDATE_ONLY      Only validate, don't process [default: false]
    CACHE_ENABLED      Enable template caching [default: true]
    LOG_LEVEL          Logging level (DEBUG|INFO|WARN|ERROR) [default: INFO]

EXAMPLES:
    $0 dev myapi myapi-dev
    $0 prod frontend frontend-prod
    CACHE_ENABLED=false $0 staging backend backend-staging

GitHub Actions Integration:
    - Automatically detects GitHub Actions environment
    - Outputs structured logs and metrics
    - Generates step summaries and reports
    - Supports caching for faster builds

EOF
}

# Check for help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Run main function
main "$@"