#!/bin/bash
# 02-build-crypto-rates-application.sh
# Builds and pushes the HeyCard Crypto Rates application to secure Docker registry
# Run AFTER 01-setup-secure-docker-registry.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="crypto-rates"
REGISTRY_HOST="192.168.0.100"
REGISTRY_PORT="5000"
REGISTRY_USER="admin"
REGISTRY_PASS="registry123"
IMAGE_TAG="${1:-latest}"
FULL_IMAGE_NAME="${REGISTRY_HOST}:${REGISTRY_PORT}/${APP_NAME}:${IMAGE_TAG}"

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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v uv &> /dev/null; then
        missing_tools+=("uv")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  docker: https://docs.docker.com/get-docker/"
        echo "  uv:     curl -LsSf https://astral.sh/uv/install.sh | sh"
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

check_registry_availability() {
    log_info "Checking registry availability..."
    
    if ! curl -k -f "https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/" > /dev/null 2>&1; then
        log_error "Registry is not available at https://${REGISTRY_HOST}:${REGISTRY_PORT}"
        echo ""
        echo "Make sure to run the registry setup first:"
        echo "  ./01-setup-secure-docker-registry.sh"
        exit 1
    fi
    
    log_success "Registry is available"
}

validate_application_files() {
    log_info "Validating application files..."
    
    local required_files=(
        "app/main.py"
        "pyproject.toml"
        "Dockerfile"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        log_error "Missing required files: ${missing_files[*]}"
        exit 1
    fi
    
    log_success "All application files are present"
}

test_application_locally() {
    log_info "Testing application locally with UV..."
    
    # Install dependencies
    if uv sync; then
        log_success "Dependencies installed with UV"
    else
        log_error "Failed to install dependencies with UV"
        exit 1
    fi
    
    # Run basic import test
    if uv run python -c "from app.main import app; print('✓ Application imports successfully')"; then
        log_success "Application imports successfully"
    else
        log_error "Application import test failed"
        exit 1
    fi
    
    # Test application startup (quick test)
    log_info "Testing application startup..."
    timeout 10s uv run python -c "
from app.main import app
import threading
import time
import requests

def run_app():
    app.run(host='127.0.0.1', port=5001, debug=False)

# Start app in background thread
app_thread = threading.Thread(target=run_app, daemon=True)
app_thread.start()

# Give app time to start
time.sleep(3)

# Test health endpoint
try:
    response = requests.get('http://127.0.0.1:5001/health', timeout=5)
    if response.status_code == 200:
        print('✓ Health check passed')
    else:
        print(f'✗ Health check failed: {response.status_code}')
        exit(1)
except Exception as e:
    print(f'✗ Health check failed: {e}')
    exit(1)
" || {
        log_error "Application startup test failed"
        exit 1
    }
    
    log_success "Local application test passed"
}

build_docker_image() {
    log_info "Building Docker image: ${FULL_IMAGE_NAME}"
    
    # Build image with proper tags
    if docker build -t "${APP_NAME}:${IMAGE_TAG}" -t "${FULL_IMAGE_NAME}" .; then
        log_success "Docker image built successfully"
    else
        log_error "Docker image build failed"
        exit 1
    fi
    
    # Verify image was built
    if docker images "${APP_NAME}:${IMAGE_TAG}" --format "table" | grep -q "${IMAGE_TAG}"; then
        log_success "Docker image verified in local registry"
    else
        log_error "Docker image not found in local registry"
        exit 1
    fi
}

test_docker_image() {
    log_info "Testing Docker image..."
    
    # Start container for testing
    local container_id
    container_id=$(docker run -d -p 5002:5000 "${APP_NAME}:${IMAGE_TAG}")
    
    # Give container time to start
    sleep 5
    
    # Test health endpoint
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "http://localhost:5002/health" > /dev/null; then
            log_success "Container health check passed"
            break
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
        
        if [ $attempt -gt $max_attempts ]; then
            log_error "Container health check failed"
            docker logs "$container_id"
            docker stop "$container_id" > /dev/null
            docker rm "$container_id" > /dev/null
            exit 1
        fi
    done
    
    # Test API endpoint
    if curl -s "http://localhost:5002/api/rates" | grep -q "rates"; then
        log_success "Container API test passed"
    else
        log_warning "Container API test returned unexpected response"
    fi
    
    # Clean up test container
    docker stop "$container_id" > /dev/null
    docker rm "$container_id" > /dev/null
    
    log_success "Docker image test completed"
}

login_to_registry() {
    log_info "Logging in to Docker registry..."
    
    if echo "${REGISTRY_PASS}" | docker login "${REGISTRY_HOST}:${REGISTRY_PORT}" -u "${REGISTRY_USER}" --password-stdin; then
        log_success "Successfully logged in to registry"
    else
        log_error "Failed to login to registry"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Verify registry is running: curl -k https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/"
        echo "  2. Check registry credentials: ${REGISTRY_USER}:${REGISTRY_PASS}"
        echo "  3. Verify registry setup: ./01-setup-secure-docker-registry.sh"
        exit 1
    fi
}

push_to_registry() {
    log_info "Pushing image to registry: ${FULL_IMAGE_NAME}"
    
    if docker push "${FULL_IMAGE_NAME}"; then
        log_success "Image pushed successfully to registry"
    else
        log_error "Failed to push image to registry"
        exit 1
    fi
    
    # Verify image exists in registry
    log_info "Verifying image in registry..."
    if curl -k -u "${REGISTRY_USER}:${REGISTRY_PASS}" "https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/${APP_NAME}/tags/list" | grep -q "${IMAGE_TAG}"; then
        log_success "Image verified in registry"
    else
        log_error "Image not found in registry"
        exit 1
    fi
}

generate_kubernetes_secret() {
    log_info "Generating Kubernetes registry secret..."
    
    # Create Docker config for Kubernetes
    local docker_config_json
    docker_config_json=$(echo "{\"auths\":{\"${REGISTRY_HOST}:${REGISTRY_PORT}\":{\"username\":\"${REGISTRY_USER}\",\"password\":\"${REGISTRY_PASS}\",\"email\":\"admin@heycard.com\",\"auth\":\"$(echo -n "${REGISTRY_USER}:${REGISTRY_PASS}" | base64 -w 0)\"}}}" | base64 -w 0)
    
    # Generate Kubernetes secret YAML
    cat > kubernetes/manifests/registry-secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
  namespace: crypto-rates-app
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: ${docker_config_json}
EOF
    
    log_success "Kubernetes registry secret generated"
}

show_summary() {
    echo ""
    log_success "Application build and push completed successfully!"
    echo ""
    echo "📦 Build Information:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Application:      ${APP_NAME}"
    echo "  Image Tag:        ${IMAGE_TAG}"
    echo "  Full Image:       ${FULL_IMAGE_NAME}"
    echo "  Registry:         https://${REGISTRY_HOST}:${REGISTRY_PORT}"
    echo "  Registry UI:      http://${REGISTRY_HOST}:8081"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔍 Verification Commands:"
    echo "  # List images in registry:"
    echo "  curl -k -u ${REGISTRY_USER}:${REGISTRY_PASS} https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/_catalog"
    echo ""
    echo "  # List tags for crypto-rates:"
    echo "  curl -k -u ${REGISTRY_USER}:${REGISTRY_PASS} https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/${APP_NAME}/tags/list"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Run: ./03-distribute-registry-certificates.sh"
    echo "  2. Run: ./04-deploy-crypto-rates-to-k8s.sh"
    echo ""
}

usage() {
    echo "Usage: $0 [IMAGE_TAG]"
    echo ""
    echo "Builds and pushes the HeyCard Crypto Rates application to secure Docker registry"
    echo ""
    echo "Arguments:"
    echo "  IMAGE_TAG    Docker image tag (default: latest)"
    echo ""
    echo "Examples:"
    echo "  $0           # Build and push with 'latest' tag"
    echo "  $0 v1.0.0    # Build and push with 'v1.0.0' tag"
    echo "  $0 dev       # Build and push with 'dev' tag"
    echo ""
    echo "Prerequisites:"
    echo "  1. Registry must be running (run ./01-setup-secure-docker-registry.sh first)"
    echo "  2. UV package manager must be installed"
    echo "  3. Docker must be installed and running"
    echo ""
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║            Build Crypto Rates Application               ║"
    echo "║                  Step 2 of 4                            ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Handle help
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        usage
        exit 0
    fi
    
    # Run build steps
    check_prerequisites
    check_registry_availability
    validate_application_files
    test_application_locally
    build_docker_image
    test_docker_image
    login_to_registry
    push_to_registry
    generate_kubernetes_secret
    
    show_summary
    exit 0
}

# Run main function with all arguments
main "$@"