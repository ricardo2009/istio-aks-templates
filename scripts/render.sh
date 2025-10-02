#!/bin/bash

# Advanced Template Renderer for Istio AKS Templates
# Supports all deployment strategies and configurations

set -euo pipefail

# Default values
SERVICE_NAME=""
NAMESPACE=""
HOST=""
FILE=""
OUTPUT_DIR="manifests"
TLS_SECRET=""
CALLER_SA=""
METHOD="GET"
PATH="/"
MAX_CONNECTIONS="50"
CONSECUTIVE_5XX_ERRORS="5"
BASE_EJECTION_TIME="30s"
CANARY_VERSION="v2.0.0"
SWITCH_TIMESTAMP=$(/bin/date -Iseconds)

# Deployment strategy variables
ACTIVE_ENVIRONMENT="blue"
STABLE_WEIGHT="90"
EXPERIMENTAL_WEIGHT="8"
CANARY_WEIGHT="2"
DEFAULT_STABLE_WEIGHT="85"
DEFAULT_EXPERIMENTAL_WEIGHT="10"
DEFAULT_CANARY_WEIGHT="5"
SHADOW_PERCENTAGE="10"

# Function to show usage
usage() {
    cat << EOF
Usage: $0 -f <template_file> -s <service_name> -n <namespace> [OPTIONS]

Required:
  -f, --file <file>           Template file to render
  -s, --service <name>        Service name
  -n, --namespace <name>      Kubernetes namespace

Optional:
  -o, --output <dir>          Output directory (default: manifests)
  -h, --host <hostname>       Hostname for Gateway
  --tls-secret <name>         TLS secret name for Gateway
  --caller-sa <name>          Caller service account for AuthorizationPolicy
  --method <method>           HTTP method for AuthorizationPolicy (default: GET)
  --path <path>               HTTP path for AuthorizationPolicy (default: /)
  --max-connections <num>     Max connections for DestinationRule (default: 50)
  --consecutive-5xx-errors <num>  Consecutive 5xx errors threshold (default: 5)
  --base-ejection-time <time> Base ejection time for outlier detection (default: 30s)
  
  # Deployment Strategy Options
  --active-environment <env>  Active environment: blue|green (default: blue)
  --stable-weight <num>       Stable variant weight percentage (default: 90)
  --experimental-weight <num> Experimental variant weight percentage (default: 8)
  --canary-weight <num>       Canary variant weight percentage (default: 2)
  --default-stable-weight <num>     Default stable weight for ultimate strategy (default: 85)
  --default-experimental-weight <num> Default experimental weight for ultimate strategy (default: 10)
  --default-canary-weight <num>     Default canary weight for ultimate strategy (default: 5)
  --shadow-percentage <num>   Shadow traffic percentage (default: 10)
  --canary-version <version>  Canary version tag (default: v2.0.0)
  --switch-timestamp <time>   Blue/Green switch timestamp (default: current time)

Examples:
  # Basic Gateway
  $0 -f templates/base/gateway.yaml -s frontend -n ecommerce-demo -h app.example.com

  # Advanced DestinationRule with circuit breaker
  $0 -f templates/traffic-management/advanced-destination-rule.yaml \\
     -s payment-service -n ecommerce-demo \\
     --max-connections 30 --consecutive-5xx-errors 3 --base-ejection-time 60s

  # Ultimate combined strategy
  $0 -f templates/deployment-strategies/ab-bluegreen-canary-combined.yaml \\
     -s order-service -n ecommerce-demo \\
     --active-environment green --canary-weight 10 --experimental-weight 15

  # Security policy
  $0 -f templates/security/authorization-policy.yaml \\
     -s user-service -n ecommerce-demo \\
     --caller-sa api-gateway --method POST --path "/api/users"
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            FILE="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        --tls-secret)
            TLS_SECRET="$2"
            shift 2
            ;;
        --caller-sa)
            CALLER_SA="$2"
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
        --active-environment)
            ACTIVE_ENVIRONMENT="$2"
            shift 2
            ;;
        --stable-weight)
            STABLE_WEIGHT="$2"
            shift 2
            ;;
        --experimental-weight)
            EXPERIMENTAL_WEIGHT="$2"
            shift 2
            ;;
        --canary-weight)
            CANARY_WEIGHT="$2"
            shift 2
            ;;
        --default-stable-weight)
            DEFAULT_STABLE_WEIGHT="$2"
            shift 2
            ;;
        --default-experimental-weight)
            DEFAULT_EXPERIMENTAL_WEIGHT="$2"
            shift 2
            ;;
        --default-canary-weight)
            DEFAULT_CANARY_WEIGHT="$2"
            shift 2
            ;;
        --shadow-percentage)
            SHADOW_PERCENTAGE="$2"
            shift 2
            ;;
        --canary-version)
            CANARY_VERSION="$2"
            shift 2
            ;;
        --switch-timestamp)
            SWITCH_TIMESTAMP="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$FILE" || -z "$SERVICE_NAME" || -z "$NAMESPACE" ]]; then
    echo "Error: Missing required parameters"
    usage
    exit 1
fi

# Check if template file exists
if [[ ! -f "$FILE" ]]; then
    echo "Error: Template file '$FILE' not found"
    exit 1
fi

# Create output directory structure
OUTPUT_SERVICE_DIR="$OUTPUT_DIR/$SERVICE_NAME"
/bin/mkdir -p "$OUTPUT_SERVICE_DIR"

# Get template filename without path and extension
TEMPLATE_NAME=$(/usr/bin/basename "$FILE" .yaml)

# Output file path
OUTPUT_FILE="$OUTPUT_SERVICE_DIR/$TEMPLATE_NAME.yaml"

echo "🔧 Rendering template: $FILE"
echo "📦 Service: $SERVICE_NAME"
echo "🏷️  Namespace: $NAMESPACE"
echo "📁 Output: $OUTPUT_FILE"

# Create a temporary file for processing
TEMP_FILE=$(/usr/bin/mktemp)

# Copy template to temp file
/bin/cp "$FILE" "$TEMP_FILE"

# Perform substitutions
/bin/sed -i "s/SERVICE_NAME/$SERVICE_NAME/g" "$TEMP_FILE"
/bin/sed -i "s/NAMESPACE/$NAMESPACE/g" "$TEMP_FILE"
/bin/sed -i "s/HOST/$HOST/g" "$TEMP_FILE"
/bin/sed -i "s/TLS_SECRET/$TLS_SECRET/g" "$TEMP_FILE"
/bin/sed -i "s/CALLER_SA/$CALLER_SA/g" "$TEMP_FILE"
/bin/sed -i "s/METHOD/$METHOD/g" "$TEMP_FILE"
/bin/sed -i "s|PATH|$PATH|g" "$TEMP_FILE"
/bin/sed -i "s/MAX_CONNECTIONS/$MAX_CONNECTIONS/g" "$TEMP_FILE"
/bin/sed -i "s/CONSECUTIVE_5XX_ERRORS/$CONSECUTIVE_5XX_ERRORS/g" "$TEMP_FILE"
/bin/sed -i "s/BASE_EJECTION_TIME/$BASE_EJECTION_TIME/g" "$TEMP_FILE"

# Deployment strategy substitutions
/bin/sed -i "s/ACTIVE_ENVIRONMENT/$ACTIVE_ENVIRONMENT/g" "$TEMP_FILE"
/bin/sed -i "s/STABLE_WEIGHT/$STABLE_WEIGHT/g" "$TEMP_FILE"
/bin/sed -i "s/EXPERIMENTAL_WEIGHT/$EXPERIMENTAL_WEIGHT/g" "$TEMP_FILE"
/bin/sed -i "s/CANARY_WEIGHT/$CANARY_WEIGHT/g" "$TEMP_FILE"
/bin/sed -i "s/DEFAULT_STABLE_WEIGHT/$DEFAULT_STABLE_WEIGHT/g" "$TEMP_FILE"
/bin/sed -i "s/DEFAULT_EXPERIMENTAL_WEIGHT/$DEFAULT_EXPERIMENTAL_WEIGHT/g" "$TEMP_FILE"
/bin/sed -i "s/DEFAULT_CANARY_WEIGHT/$DEFAULT_CANARY_WEIGHT/g" "$TEMP_FILE"
/bin/sed -i "s/SHADOW_PERCENTAGE/$SHADOW_PERCENTAGE/g" "$TEMP_FILE"
/bin/sed -i "s/CANARY_VERSION/$CANARY_VERSION/g" "$TEMP_FILE"
/bin/sed -i "s/SWITCH_TIMESTAMP/$SWITCH_TIMESTAMP/g" "$TEMP_FILE"

# Move processed file to output location
/bin/cp "$TEMP_FILE" "$OUTPUT_FILE"

# Clean up
/bin/rm -f "$TEMP_FILE"

echo "✅ Template rendered successfully: $OUTPUT_FILE"

# Validate YAML syntax if kubectl is available
if command -v kubectl >/dev/null 2>&1; then
    if kubectl apply --dry-run=client -f "$OUTPUT_FILE" >/dev/null 2>&1; then
        echo "✅ YAML syntax validation passed"
    else
        echo "⚠️  YAML syntax validation failed - please check the output file"
        exit 1
    fi
else
    echo "ℹ️  kubectl not available - skipping YAML validation"
fi

# Show file contents if it's small enough
if [[ $(/usr/bin/wc -l < "$OUTPUT_FILE") -le 50 ]]; then
    echo ""
    echo "📄 Generated content:"
    echo "===================="
    /bin/cat "$OUTPUT_FILE"
fi

