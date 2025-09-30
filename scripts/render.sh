#!/bin/bash
# Script para renderizar templates YAML do Istio

set -e

# Parâmetros com valores padrão
SERVICE_NAME=""
NAMESPACE="default"
HOST=""
TLS_SECRET_NAME=""
SERVICE_PORT="80"
CALLER_SERVICE_ACCOUNT="default"
METHOD="GET"
PATH="/"
LOAD_BALANCER_TYPE="ROUND_ROBIN"
MAX_CONNECTIONS=100
MAX_PENDING_REQUESTS=1024
MAX_REQUESTS_PER_CONN=10
CONSECUTIVE_5XX_ERRORS=5
OUTLIER_INTERVAL="10s"
BASE_EJECTION_TIME="30s"
MAX_EJECTION_PERCENT=50
TEMPLATE_FILE=""
OUTPUT_DIR="manifests"

# Função para exibir o uso
usage() {
    echo "Uso: $0 -f <template_file> -s <service_name> -n <namespace> -h <host> [outras opções]"
    echo "Opções:"
    echo "  -f, --template-file <arquivo>   Arquivo de template a ser renderizado (obrigatório)"
    echo "  -s, --service-name <nome>       Nome do serviço (obrigatório)"
    echo "  -n, --namespace <namespace>     Namespace (padrão: default)"
    echo "  -h, --host <host>               Host para o Gateway/VirtualService"
    echo "  --tls-secret <nome>             Nome do secret TLS para o Gateway"
    echo "  --service-port <porta>          Porta do serviço (padrão: 80)"
    echo "  --caller-sa <sa>                Service Account do chamador para AuthorizationPolicy"
    echo "  --method <método>               Método HTTP para AuthorizationPolicy (padrão: GET)"
    echo "  --path <caminho>                Caminho para AuthorizationPolicy (padrão: /)"
    echo "  -o, --output-dir <dir>          Diretório de saída (padrão: manifests)"
    exit 1
}

# Parse dos argumentos
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--template-file)
            TEMPLATE_FILE="$2"
            shift 2
            ;;
        -s|--service-name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        --tls-secret)
            TLS_SECRET_NAME="$2"
            shift 2
            ;;
        --service-port)
            SERVICE_PORT="$2"
            shift 2
            ;;
        --caller-sa)
            CALLER_SERVICE_ACCOUNT="$2"
            shift 2
            ;;
        --method)
            METHOD="$2"
            shift 2
            ;;
        --path)
            PATH="$2"
            shift 2
            ;;
        --max-connections)
            MAX_CONNECTIONS="$2"
            shift 2
            ;;
        --consecutive-5xx-errors)
            CONSECUTIVE_5XX_ERRORS="$2"
            shift 2
            ;;
        --base-ejection-time)
            BASE_EJECTION_TIME="$2"
            shift 2
            ;;
        --max-ejection-percent)
            MAX_EJECTION_PERCENT="$2"
            shift 2
            ;;
        --gateway-name)
            GATEWAY_NAME="$2"
            shift 2
            ;;
        --gateway-selector)
            GATEWAY_SELECTOR="$2"
            shift 2
            ;;
        --gateway-type)
            GATEWAY_TYPE="$2"
            shift 2
            ;;
        --tls-mode)
            TLS_MODE="$2"
            shift 2
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

# Validação de parâmetros obrigatórios
if [ -z "${TEMPLATE_FILE}" ] || [ -z "${SERVICE_NAME}" ]; then
    echo "Erro: --template-file e --service-name são obrigatórios."
    usage
fi

if [ ! -f "${TEMPLATE_FILE}" ]; then
    echo "Erro: Arquivo de template não encontrado em ${TEMPLATE_FILE}"
    exit 1
fi

# Cria o diretório de saída se não existir
/usr/bin/mkdir -p "${OUTPUT_DIR}/${SERVICE_NAME}"

TEMPLATE_BASENAME=$(/usr/bin/basename "${TEMPLATE_FILE}")
OUTPUT_FILE="${OUTPUT_DIR}/${SERVICE_NAME}/${TEMPLATE_BASENAME}"

# Valores padrão adicionais para templates avançados
GATEWAY_NAME="${SERVICE_NAME}-gateway"
GATEWAY_SELECTOR="aks-istio-ingressgateway-external"
GATEWAY_TYPE="public"
TLS_MODE="SIMPLE"
TLS_MIN_VERSION="TLSV1_2"
TLS_MAX_VERSION="TLSV1_3"
HTTPS_REDIRECT="true"
MIN_HEALTH_PERCENT="30"

# Renderiza o template
/usr/bin/cp "${TEMPLATE_FILE}" "${OUTPUT_FILE}"

/usr/bin/sed -i "s/{{SERVICE_NAME}}/${SERVICE_NAME}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{NAMESPACE}}/${NAMESPACE}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{HOST}}/${HOST}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{TLS_SECRET_NAME}}/${TLS_SECRET_NAME}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{SERVICE_PORT}}/${SERVICE_PORT}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{CALLER_SERVICE_ACCOUNT}}/${CALLER_SERVICE_ACCOUNT}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{METHOD}}/${METHOD}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{PATH}}/${PATH//\//\\/}/g" "${OUTPUT_FILE}" # Escapa barras para o sed
/usr/bin/sed -i "s/{{LOAD_BALANCER_TYPE}}/${LOAD_BALANCER_TYPE}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{MAX_CONNECTIONS}}/${MAX_CONNECTIONS}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{MAX_PENDING_REQUESTS}}/${MAX_PENDING_REQUESTS}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{MAX_REQUESTS_PER_CONN}}/${MAX_REQUESTS_PER_CONN}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{CONSECUTIVE_5XX_ERRORS}}/${CONSECUTIVE_5XX_ERRORS}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{OUTLIER_INTERVAL}}/${OUTLIER_INTERVAL}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{BASE_EJECTION_TIME}}/${BASE_EJECTION_TIME}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{MAX_EJECTION_PERCENT}}/${MAX_EJECTION_PERCENT}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{GATEWAY_NAME}}/${GATEWAY_NAME}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{GATEWAY_SELECTOR}}/${GATEWAY_SELECTOR}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{GATEWAY_TYPE}}/${GATEWAY_TYPE}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{TLS_MODE}}/${TLS_MODE}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{TLS_MIN_VERSION}}/${TLS_MIN_VERSION}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{TLS_MAX_VERSION}}/${TLS_MAX_VERSION}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{HTTPS_REDIRECT}}/${HTTPS_REDIRECT}/g" "${OUTPUT_FILE}"
/usr/bin/sed -i "s/{{MIN_HEALTH_PERCENT}}/${MIN_HEALTH_PERCENT}/g" "${OUTPUT_FILE}"

echo "Template '${TEMPLATE_FILE}' renderizado com sucesso em '${OUTPUT_FILE}'"

