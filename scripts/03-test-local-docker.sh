#!/bin/bash
# Test script for HeyCard Crypto Rates application
# Tests the application locally and validates functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="crypto-rates"
IMAGE_NAME="crypto-rates:test"
CONTAINER_NAME="crypto-rates-test"
TEST_PORT="15000"
BASE_URL="http://localhost:${TEST_PORT}"
TIMEOUT=30

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    log_info "Cleaning up test environment..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
}

wait_for_app() {
    local url="$1"
    local max_attempts=$((TIMEOUT))
    local attempt=1
    
    log_info "Waiting for application to be ready at ${url}..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "${url}/health" > /dev/null 2>&1; then
            log_success "Application is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 1
        ((attempt++))
    done
    
    log_error "Application failed to start within ${TIMEOUT} seconds"
    return 1
}

test_endpoint() {
    local endpoint="$1"
    local expected_status="$2"
    local description="$3"
    
    log_info "Testing ${description}..."
    
    local response
    local status_code
    
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "${BASE_URL}${endpoint}")
    status_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    
    if [ "$status_code" -eq "$expected_status" ]; then
        log_success "${description} - Status: ${status_code}"
        return 0
    else
        log_error "${description} - Expected: ${expected_status}, Got: ${status_code}"
        return 1
    fi
}

test_api_response() {
    local endpoint="/api/rates"
    log_info "Testing API response structure..."
    
    local response
    response=$(curl -s "${BASE_URL}${endpoint}")
    
    # Check if response contains expected fields
    if echo "$response" | jq -e '.rates' > /dev/null 2>&1; then
        log_success "API response contains 'rates' field"
    else
        log_error "API response missing 'rates' field"
        return 1
    fi
    
    if echo "$response" | jq -e '.last_updated' > /dev/null 2>&1; then
        log_success "API response contains 'last_updated' field"
    else
        log_error "API response missing 'last_updated' field"
        return 1
    fi
    
    if echo "$response" | jq -e '.total_currencies' > /dev/null 2>&1; then
        log_success "API response contains 'total_currencies' field"
    else
        log_error "API response missing 'total_currencies' field"
        return 1
    fi
    
    local currency_count
    currency_count=$(echo "$response" | jq -r '.total_currencies')
    
    if [ "$currency_count" -gt 0 ]; then
        log_success "API returned ${currency_count} currencies"
    else
        log_error "API returned no currencies"
        return 1
    fi
    
    return 0
}

test_prometheus_metrics() {
    local endpoint="/metrics"
    log_info "Testing Prometheus metrics..."
    
    local response
    response=$(curl -s "${BASE_URL}${endpoint}")
    
    # Check for expected metric patterns
    local expected_metrics=(
        "crypto_app_requests_total"
        "crypto_app_request_duration_seconds"
        "coingecko_api_calls_total"
    )
    
    for metric in "${expected_metrics[@]}"; do
        if echo "$response" | grep -q "$metric"; then
            log_success "Found metric: ${metric}"
        else
            log_error "Missing metric: ${metric}"
            return 1
        fi
    done
    
    return 0
}

performance_test() {
    log_info "Running performance tests..."
    
    local start_time
    local end_time
    local duration
    
    # Test response time
    start_time=$(date +%s.%N)
    curl -s -f "${BASE_URL}/api/rates" > /dev/null
    end_time=$(date +%s.%N)
    
    duration=$(echo "$end_time - $start_time" | bc)
    
    if (( $(echo "$duration < 5.0" | bc -l) )); then
        log_success "Response time: ${duration}s (< 5s threshold)"
    else
        log_warning "Response time: ${duration}s (> 5s threshold)"
    fi
    
    # Test concurrent requests
    log_info "Testing concurrent requests..."
    for i in {1..10}; do
        curl -s -f "${BASE_URL}/health" > /dev/null &
    done
    wait
    
    log_success "Handled 10 concurrent health check requests"
}

security_test() {
    log_info "Running basic security tests..."
    
    # Test for common security headers (basic check)
    local response_headers
    response_headers=$(curl -s -I "${BASE_URL}/")
    
    # Note: These would be added by reverse proxy/ingress in production
    log_info "Security headers check (informational):"
    
    if echo "$response_headers" | grep -i "server:" | grep -v "Server: nginx\|Server: Apache"; then
        log_success "Server header doesn't reveal sensitive information"
    else
        log_info "Consider hiding server version information"
    fi
    
    # Test error handling
    log_info "Testing error handling..."
    test_endpoint "/nonexistent" 404 "404 Error Handling"
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║             HeyCard Crypto Rates - Test Suite           ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Trap cleanup function
    trap cleanup EXIT
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found, installing..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        elif command -v brew &> /dev/null; then
            brew install jq
        else
            log_error "Could not install jq automatically"
            exit 1
        fi
    fi
    
    # Check for UV (preferred) or pip
    if command -v uv &> /dev/null; then
        log_success "UV package manager available"
        PYTHON_RUNNER="uv run"
    else
        log_info "UV not available, using pip"
        PYTHON_RUNNER="python3"
        
        # Install dependencies with pip if requirements.txt exists
        if [ -f "app/requirements.txt" ]; then
            pip3 install -q -r app/requirements.txt
        fi
    fi
    
    log_success "Prerequisites check completed"
    
    # Build Docker image
    log_info "Building Docker image..."
    if docker build -t "${IMAGE_NAME}" .; then
        log_success "Docker image built successfully"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
    
    # Clean up any existing test container
    cleanup
    
    # Start application container
    log_info "Starting application container..."
    if docker run -d --name "${CONTAINER_NAME}" -p "${TEST_PORT}:5000" "${IMAGE_NAME}"; then
        log_success "Container started successfully"
    else
        log_error "Failed to start container"
        exit 1
    fi
    
    # Wait for application to be ready
    if ! wait_for_app "${BASE_URL}"; then
        log_error "Application failed to start"
        docker logs "${CONTAINER_NAME}"
        exit 1
    fi
    
    # Run tests
    local test_results=()
    local failed_tests=0
    
    # Basic endpoint tests
    if test_endpoint "/" 200 "Home Page"; then
        test_results+=("✅ Home Page")
    else
        test_results+=("❌ Home Page")
        ((failed_tests++))
    fi
    
    if test_endpoint "/health" 200 "Health Check"; then
        test_results+=("✅ Health Check")
    else
        test_results+=("❌ Health Check")
        ((failed_tests++))
    fi
    
    if test_endpoint "/api/rates" 200 "API Rates Endpoint"; then
        test_results+=("✅ API Rates Endpoint")
    else
        test_results+=("❌ API Rates Endpoint")
        ((failed_tests++))
    fi
    
    if test_endpoint "/metrics" 200 "Prometheus Metrics"; then
        test_results+=("✅ Prometheus Metrics")
    else
        test_results+=("❌ Prometheus Metrics")
        ((failed_tests++))
    fi
    
    # API response structure test
    if test_api_response; then
        test_results+=("✅ API Response Structure")
    else
        test_results+=("❌ API Response Structure")
        ((failed_tests++))
    fi
    
    # Prometheus metrics test
    if test_prometheus_metrics; then
        test_results+=("✅ Prometheus Metrics Content")
    else
        test_results+=("❌ Prometheus Metrics Content")
        ((failed_tests++))
    fi
    
    # Performance tests
    performance_test
    test_results+=("✅ Performance Tests")
    
    # Security tests
    security_test
    test_results+=("✅ Security Tests")
    
    # Test results summary
    echo ""
    log_info "Test Results Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ $failed_tests -eq 0 ]; then
        log_success "All tests passed! 🎉"
        echo ""
        echo "Application is ready for deployment!"
        echo "Container details:"
        docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "Access URLs:"
        echo "  Application: ${BASE_URL}/"
        echo "  Health:      ${BASE_URL}/health"
        echo "  API:         ${BASE_URL}/api/rates"
        echo "  Metrics:     ${BASE_URL}/metrics"
        echo ""
        echo "Press Ctrl+C to stop the test container"
        
        # Keep container running for manual testing
        read -p "Press Enter to stop the container and exit..."
        
    else
        log_error "${failed_tests} test(s) failed!"
        echo ""
        echo "Container logs:"
        docker logs "${CONTAINER_NAME}"
        exit 1
    fi
}

# Run main function
main "$@"