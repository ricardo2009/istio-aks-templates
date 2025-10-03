#!/bin/bash

# ===============================================================================
# STRESS TEST SCRIPT - 600K RPS LOAD TESTING
# ===============================================================================
# Script principal para executar testes de carga de alta performance
# Objetivo: Atingir 600.000 RPS sustentados
# ===============================================================================

set -euo pipefail

# ===============================================================================
# CONFIGURATION
# ===============================================================================

# Default values
DEFAULT_TARGET_RPS=600000
DEFAULT_DURATION="30m"
DEFAULT_RAMP_UP="10m"
DEFAULT_RAMP_DOWN="5m"
DEFAULT_USERS=50000
DEFAULT_SCENARIO="ecommerce-stress"
DEFAULT_REGIONS="us-east,eu-west"

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_ROOT/results"
LOGS_DIR="$PROJECT_ROOT/logs"
TOOLS_DIR="$PROJECT_ROOT/tools"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===============================================================================
# FUNCTIONS
# ===============================================================================

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

High-Performance Load Testing Script for E-commerce Platform
Target: 600,000 RPS sustained load testing

OPTIONS:
    --target-rps RPS        Target requests per second (default: $DEFAULT_TARGET_RPS)
    --duration DURATION     Test duration (default: $DEFAULT_DURATION)
    --ramp-up DURATION      Ramp-up duration (default: $DEFAULT_RAMP_UP)
    --ramp-down DURATION    Ramp-down duration (default: $DEFAULT_RAMP_DOWN)
    --users COUNT           Number of virtual users (default: $DEFAULT_USERS)
    --scenario NAME         Test scenario (default: $DEFAULT_SCENARIO)
    --regions LIST          Comma-separated regions (default: $DEFAULT_REGIONS)
    --dry-run              Show configuration without running
    --help                 Show this help message

EXAMPLES:
    # Basic 600k RPS test
    $0 --target-rps=600000 --duration=30m

    # Extended test with custom parameters
    $0 --target-rps=500000 --duration=1h --users=40000 --scenario=ecommerce-peak

    # Multi-region test
    $0 --target-rps=600000 --regions=us-east,eu-west,asia-southeast

    # Dry run to validate configuration
    $0 --target-rps=600000 --dry-run

EOF
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if kubectl is available and connected
    if ! kubectl cluster-info &>/dev/null; then
        log_error "kubectl is not available or not connected to cluster"
        exit 1
    fi
    
    # Check if load testing cluster is available
    if ! kubectl get nodes -l node-pool=loadtest &>/dev/null; then
        log_error "Load testing cluster nodes not found"
        exit 1
    fi
    
    # Check if target application is running
    if ! kubectl get deployment -n ecommerce api-gateway &>/dev/null; then
        log_error "Target application (api-gateway) not found in ecommerce namespace"
        exit 1
    fi
    
    # Check if monitoring is available
    if ! kubectl get service -n monitoring prometheus-server &>/dev/null; then
        log_warning "Prometheus monitoring not found - metrics collection may be limited"
    fi
    
    # Check required tools
    local tools=("k6" "artillery" "vegeta" "jq" "curl")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "Required tool '$tool' not found"
            exit 1
        fi
    done
    
    log_success "Prerequisites check completed"
}

setup_environment() {
    log "Setting up test environment..."
    
    # Create directories
    mkdir -p "$RESULTS_DIR" "$LOGS_DIR"
    
    # Generate test ID
    TEST_ID="stress-$(date +%Y%m%d-%H%M%S)-${TARGET_RPS}rps"
    TEST_DIR="$RESULTS_DIR/$TEST_ID"
    mkdir -p "$TEST_DIR"
    
    # Export environment variables
    export TEST_ID
    export TEST_DIR
    export TARGET_RPS
    export DURATION
    export RAMP_UP
    export RAMP_DOWN
    export USERS
    export SCENARIO
    export REGIONS
    
    log_success "Environment setup completed - Test ID: $TEST_ID"
}

get_target_endpoints() {
    log "Discovering target endpoints..."
    
    # Get NGINX Ingress external IP
    INGRESS_IP=$(kubectl get service -n nginx-ingress nginx-ingress-controller \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [[ -z "$INGRESS_IP" ]]; then
        log_error "Could not get NGINX Ingress external IP"
        exit 1
    fi
    
    # Define endpoints
    BASE_URL="https://$INGRESS_IP"
    API_BASE_URL="$BASE_URL/api/v1"
    
    # Test endpoints
    ENDPOINTS=(
        "$BASE_URL/"
        "$API_BASE_URL/products"
        "$API_BASE_URL/products/search"
        "$API_BASE_URL/users/profile"
        "$API_BASE_URL/orders"
        "$API_BASE_URL/payments/methods"
    )
    
    export INGRESS_IP BASE_URL API_BASE_URL
    
    log_success "Target endpoints discovered - Base URL: $BASE_URL"
}

validate_endpoints() {
    log "Validating target endpoints..."
    
    local failed=0
    for endpoint in "${ENDPOINTS[@]}"; do
        if curl -s -f -k --max-time 10 "$endpoint" >/dev/null; then
            log_success "✓ $endpoint"
        else
            log_error "✗ $endpoint"
            ((failed++))
        fi
    done
    
    if [[ $failed -gt 0 ]]; then
        log_error "$failed endpoints failed validation"
        exit 1
    fi
    
    log_success "All endpoints validated successfully"
}

scale_infrastructure() {
    log "Scaling infrastructure for high-load testing..."
    
    # Scale NGINX Ingress Controller
    kubectl scale deployment -n nginx-ingress nginx-ingress-controller --replicas=10
    
    # Scale API Gateway
    kubectl scale deployment -n ecommerce api-gateway --replicas=20
    
    # Scale microservices
    kubectl scale deployment -n ecommerce user-service --replicas=10
    kubectl scale deployment -n ecommerce product-service --replicas=15
    kubectl scale deployment -n ecommerce order-service --replicas=8
    kubectl scale deployment -n ecommerce payment-service --replicas=6
    
    # Wait for scaling to complete
    log "Waiting for scaling to complete..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/nginx-ingress-controller -n nginx-ingress
    kubectl wait --for=condition=available --timeout=300s \
        deployment/api-gateway -n ecommerce
    kubectl wait --for=condition=available --timeout=300s \
        deployment/user-service -n ecommerce
    kubectl wait --for=condition=available --timeout=300s \
        deployment/product-service -n ecommerce
    kubectl wait --for=condition=available --timeout=300s \
        deployment/order-service -n ecommerce
    kubectl wait --for=condition=available --timeout=300s \
        deployment/payment-service -n ecommerce
    
    log_success "Infrastructure scaling completed"
}

start_monitoring() {
    log "Starting monitoring and metrics collection..."
    
    # Start Prometheus metrics collection
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: load-test-monitoring
  namespace: monitoring
data:
  additional-scrape-configs.yaml: |
    - job_name: 'load-test-metrics'
      static_configs:
      - targets: ['load-test-exporter:9090']
      scrape_interval: 5s
      metrics_path: /metrics
EOF
    
    # Start custom metrics exporter
    kubectl apply -f "$PROJECT_ROOT/monitoring/load-test-exporter.yaml"
    
    # Create Grafana dashboard for load testing
    kubectl apply -f "$PROJECT_ROOT/monitoring/load-test-dashboard.yaml"
    
    log_success "Monitoring started"
}

run_k6_test() {
    log "Running K6 load test..."
    
    local k6_script="$TOOLS_DIR/k6/stress-test.js"
    local k6_config="$TEST_DIR/k6-config.json"
    
    # Generate K6 configuration
    cat > "$k6_config" <<EOF
{
  "scenarios": {
    "stress_test": {
      "executor": "ramping-arrival-rate",
      "startRate": 1000,
      "timeUnit": "1s",
      "preAllocatedVUs": $((USERS / 4)),
      "maxVUs": $USERS,
      "stages": [
        { "duration": "$RAMP_UP", "target": $TARGET_RPS },
        { "duration": "$DURATION", "target": $TARGET_RPS },
        { "duration": "$RAMP_DOWN", "target": 0 }
      ]
    }
  },
  "thresholds": {
    "http_req_duration": ["p(95)<100", "p(99)<200"],
    "http_req_failed": ["rate<0.01"],
    "http_reqs": ["rate>$((TARGET_RPS - 1000))"]
  }
}
EOF
    
    # Run K6 test
    k6 run \
        --config "$k6_config" \
        --env BASE_URL="$BASE_URL" \
        --env API_BASE_URL="$API_BASE_URL" \
        --env TEST_ID="$TEST_ID" \
        --out json="$TEST_DIR/k6-results.json" \
        --out influxdb=http://influxdb.monitoring.svc.cluster.local:8086/k6 \
        "$k6_script" 2>&1 | tee "$TEST_DIR/k6-output.log"
    
    log_success "K6 test completed"
}

run_artillery_test() {
    log "Running Artillery load test..."
    
    local artillery_config="$TEST_DIR/artillery-config.yml"
    
    # Generate Artillery configuration
    cat > "$artillery_config" <<EOF
config:
  target: '$BASE_URL'
  phases:
    - duration: $(echo "$RAMP_UP" | sed 's/m/ minutes/')
      arrivalRate: 1000
      rampTo: $((TARGET_RPS / 4))
    - duration: $(echo "$DURATION" | sed 's/m/ minutes/')
      arrivalRate: $((TARGET_RPS / 4))
    - duration: $(echo "$RAMP_DOWN" | sed 's/m/ minutes/')
      arrivalRate: $((TARGET_RPS / 4))
      rampTo: 0
  processor: "$TOOLS_DIR/artillery/processor.js"
  
scenarios:
  - name: "E-commerce Stress Test"
    weight: 100
    flow:
      - get:
          url: "/"
      - get:
          url: "/api/v1/products"
      - get:
          url: "/api/v1/products/search?q=laptop"
      - post:
          url: "/api/v1/auth/login"
          json:
            email: "test@example.com"
            password: "password123"
      - get:
          url: "/api/v1/users/profile"
          headers:
            Authorization: "Bearer {{ token }}"
EOF
    
    # Run Artillery test
    artillery run \
        --output "$TEST_DIR/artillery-results.json" \
        "$artillery_config" 2>&1 | tee "$TEST_DIR/artillery-output.log"
    
    log_success "Artillery test completed"
}

run_vegeta_test() {
    log "Running Vegeta load test..."
    
    local vegeta_targets="$TEST_DIR/vegeta-targets.txt"
    local vegeta_results="$TEST_DIR/vegeta-results.bin"
    
    # Generate Vegeta targets
    cat > "$vegeta_targets" <<EOF
GET $BASE_URL/
GET $API_BASE_URL/products
GET $API_BASE_URL/products/search?q=laptop
GET $API_BASE_URL/products/categories
POST $API_BASE_URL/auth/login
Content-Type: application/json

{"email":"test@example.com","password":"password123"}

GET $API_BASE_URL/users/profile
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
EOF
    
    # Calculate duration in seconds
    local duration_seconds
    duration_seconds=$(echo "$DURATION" | sed 's/m/*60/' | sed 's/h/*3600/' | bc)
    
    # Run Vegeta test
    vegeta attack \
        -targets="$vegeta_targets" \
        -rate="$((TARGET_RPS / 4))" \
        -duration="${duration_seconds}s" \
        -timeout=30s \
        -workers=100 \
        > "$vegeta_results"
    
    # Generate Vegeta report
    vegeta report < "$vegeta_results" > "$TEST_DIR/vegeta-report.txt"
    vegeta plot < "$vegeta_results" > "$TEST_DIR/vegeta-plot.html"
    
    log_success "Vegeta test completed"
}

run_custom_test() {
    log "Running custom high-performance test..."
    
    local custom_script="$TOOLS_DIR/custom/high-performance-test.py"
    
    # Run custom Python test
    python3 "$custom_script" \
        --target-url="$BASE_URL" \
        --target-rps="$TARGET_RPS" \
        --duration="$DURATION" \
        --users="$USERS" \
        --output-dir="$TEST_DIR" \
        --test-id="$TEST_ID" 2>&1 | tee "$TEST_DIR/custom-output.log"
    
    log_success "Custom test completed"
}

monitor_system_metrics() {
    log "Collecting system metrics during test..."
    
    local metrics_script="$SCRIPT_DIR/collect-metrics.sh"
    
    # Start metrics collection in background
    "$metrics_script" "$TEST_DIR" &
    METRICS_PID=$!
    
    # Store PID for cleanup
    echo $METRICS_PID > "$TEST_DIR/metrics.pid"
    
    log_success "System metrics collection started (PID: $METRICS_PID)"
}

stop_monitoring() {
    log "Stopping monitoring and metrics collection..."
    
    # Stop metrics collection
    if [[ -f "$TEST_DIR/metrics.pid" ]]; then
        local metrics_pid
        metrics_pid=$(cat "$TEST_DIR/metrics.pid")
        if kill -0 "$metrics_pid" 2>/dev/null; then
            kill "$metrics_pid"
        fi
        rm -f "$TEST_DIR/metrics.pid"
    fi
    
    # Cleanup monitoring resources
    kubectl delete configmap load-test-monitoring -n monitoring --ignore-not-found
    kubectl delete -f "$PROJECT_ROOT/monitoring/load-test-exporter.yaml" --ignore-not-found
    
    log_success "Monitoring stopped"
}

generate_report() {
    log "Generating comprehensive test report..."
    
    local report_script="$SCRIPT_DIR/generate-report.py"
    
    # Generate comprehensive report
    python3 "$report_script" \
        --test-dir="$TEST_DIR" \
        --test-id="$TEST_ID" \
        --target-rps="$TARGET_RPS" \
        --duration="$DURATION" \
        --output="$TEST_DIR/comprehensive-report.html"
    
    # Generate summary
    cat > "$TEST_DIR/test-summary.txt" <<EOF
Load Test Summary
================

Test ID: $TEST_ID
Date: $(date)
Target RPS: $TARGET_RPS
Duration: $DURATION
Users: $USERS
Scenario: $SCENARIO

Results:
- K6 Results: $TEST_DIR/k6-results.json
- Artillery Results: $TEST_DIR/artillery-results.json
- Vegeta Results: $TEST_DIR/vegeta-results.bin
- Custom Results: $TEST_DIR/custom-results.json
- System Metrics: $TEST_DIR/metrics/
- Comprehensive Report: $TEST_DIR/comprehensive-report.html

Target Endpoints:
$(printf '%s\n' "${ENDPOINTS[@]}")
EOF
    
    log_success "Test report generated: $TEST_DIR/comprehensive-report.html"
}

cleanup() {
    log "Cleaning up test environment..."
    
    # Stop monitoring
    stop_monitoring
    
    # Scale down infrastructure (optional)
    if [[ "${SCALE_DOWN:-true}" == "true" ]]; then
        kubectl scale deployment -n nginx-ingress nginx-ingress-controller --replicas=3
        kubectl scale deployment -n ecommerce api-gateway --replicas=3
        kubectl scale deployment -n ecommerce user-service --replicas=2
        kubectl scale deployment -n ecommerce product-service --replicas=3
        kubectl scale deployment -n ecommerce order-service --replicas=2
        kubectl scale deployment -n ecommerce payment-service --replicas=2
    fi
    
    log_success "Cleanup completed"
}

# ===============================================================================
# MAIN EXECUTION
# ===============================================================================

main() {
    # Parse command line arguments
    TARGET_RPS=$DEFAULT_TARGET_RPS
    DURATION=$DEFAULT_DURATION
    RAMP_UP=$DEFAULT_RAMP_UP
    RAMP_DOWN=$DEFAULT_RAMP_DOWN
    USERS=$DEFAULT_USERS
    SCENARIO=$DEFAULT_SCENARIO
    REGIONS=$DEFAULT_REGIONS
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target-rps=*)
                TARGET_RPS="${1#*=}"
                shift
                ;;
            --duration=*)
                DURATION="${1#*=}"
                shift
                ;;
            --ramp-up=*)
                RAMP_UP="${1#*=}"
                shift
                ;;
            --ramp-down=*)
                RAMP_DOWN="${1#*=}"
                shift
                ;;
            --users=*)
                USERS="${1#*=}"
                shift
                ;;
            --scenario=*)
                SCENARIO="${1#*=}"
                shift
                ;;
            --regions=*)
                REGIONS="${1#*=}"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Display configuration
    log "Load Test Configuration:"
    log "  Target RPS: $TARGET_RPS"
    log "  Duration: $DURATION"
    log "  Ramp Up: $RAMP_UP"
    log "  Ramp Down: $RAMP_DOWN"
    log "  Users: $USERS"
    log "  Scenario: $SCENARIO"
    log "  Regions: $REGIONS"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run mode - configuration validated"
        exit 0
    fi
    
    # Trap for cleanup
    trap cleanup EXIT
    
    # Execute test phases
    check_prerequisites
    setup_environment
    get_target_endpoints
    validate_endpoints
    scale_infrastructure
    start_monitoring
    monitor_system_metrics
    
    # Run parallel load tests
    log "Starting parallel load tests..."
    run_k6_test &
    K6_PID=$!
    
    run_artillery_test &
    ARTILLERY_PID=$!
    
    run_vegeta_test &
    VEGETA_PID=$!
    
    run_custom_test &
    CUSTOM_PID=$!
    
    # Wait for all tests to complete
    wait $K6_PID $ARTILLERY_PID $VEGETA_PID $CUSTOM_PID
    
    log_success "All load tests completed"
    
    # Generate final report
    generate_report
    
    log_success "Load test execution completed successfully!"
    log "Results available at: $TEST_DIR"
}

# Execute main function
main "$@"
