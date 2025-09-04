#!/bin/bash
# 04-deploy-crypto-rates-to-k8s.sh
# Deploys HeyCard Crypto Rates application to Kubernetes cluster with secure registry
# Run AFTER 03-distribute-registry-certificates.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="crypto-rates"
# Use application-specific namespace
if [ $# -eq 0 ]; then
    NAMESPACE="crypto-rates-app"
else
    NAMESPACE="$1"
fi
IMAGE_TAG="${2:-local}"
HELM_RELEASE_NAME="${APP_NAME}"
CHART_PATH="./helm/crypto-rates"
TIMEOUT="10m"

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
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Installation instructions:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                kubectl)
                    echo "  kubectl: https://kubernetes.io/docs/tasks/tools/"
                    ;;
                helm)
                    echo "  helm: https://helm.sh/docs/intro/install/"
                    ;;
                docker)
                    echo "  docker: https://docs.docker.com/get-docker/"
                    ;;
            esac
        done
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

check_kubernetes_connection() {
    log_info "Checking Kubernetes connection..."
    
    if ! kubectl cluster-info > /dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        echo ""
        echo "Common solutions:"
        echo "  - Start minikube: minikube start"
        echo "  - Start kind cluster: kind create cluster"
        echo "  - Enable Kubernetes in Docker Desktop"
        echo "  - Check kubeconfig: kubectl config current-context"
        exit 1
    fi
    
    local context
    context=$(kubectl config current-context)
    log_success "Connected to Kubernetes cluster: ${context}"
}

build_docker_image() {
    log_info "Building Docker image..."
    
    if docker build -t "${APP_NAME}:${IMAGE_TAG}" .; then
        log_success "Docker image built: ${APP_NAME}:${IMAGE_TAG}"
    else
        log_error "Failed to build Docker image"
        exit 1
    fi
    
    # Load image into cluster if using kind or minikube
    local context
    context=$(kubectl config current-context)
    
    if [[ $context == kind-* ]]; then
        log_info "Loading image into kind cluster..."
        kind load docker-image "${APP_NAME}:${IMAGE_TAG}" --name "${context#kind-}"
        log_success "Image loaded into kind cluster"
    elif [[ $context == minikube ]]; then
        log_info "Loading image into minikube..."
        minikube image load "${APP_NAME}:${IMAGE_TAG}"
        log_success "Image loaded into minikube"
    fi
}

create_namespace() {
    log_info "Creating namespace: ${NAMESPACE}"
    
    if kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -; then
        log_success "Namespace ${NAMESPACE} ready"
    else
        log_error "Failed to create namespace"
        exit 1
    fi
}

validate_helm_chart() {
    log_info "Validating Helm chart..."
    
    if helm lint "${CHART_PATH}"; then
        log_success "Helm chart validation passed"
    else
        log_error "Helm chart validation failed"
        exit 1
    fi
    
    # Template the chart to check for issues
    log_info "Templating Helm chart..."
    helm template "${HELM_RELEASE_NAME}" "${CHART_PATH}" \
        --namespace "${NAMESPACE}" \
        --set image.repository="${APP_NAME}" \
        --set image.tag="${IMAGE_TAG}" \
        --set image.pullPolicy=Never \
        --set ingress.enabled=false \
        --set service.type=NodePort \
        > /tmp/rendered-manifests.yaml
    
    log_success "Helm chart templated successfully"
}

deploy_application() {
    log_info "Deploying application with Helm..."
    
    helm upgrade --install "${HELM_RELEASE_NAME}" "${CHART_PATH}" \
        --namespace "${NAMESPACE}" \
        --set image.repository="${APP_NAME}" \
        --set image.tag="${IMAGE_TAG}" \
        --set image.pullPolicy=Never \
        --set ingress.enabled=false \
        --set service.type=NodePort \
        --set replicaCount=2 \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=128Mi \
        --set resources.limits.cpu=500m \
        --set resources.limits.memory=512Mi \
        --wait \
        --timeout="${TIMEOUT}"
    
    if [ $? -eq 0 ]; then
        log_success "Application deployed successfully"
    else
        log_error "Application deployment failed"
        exit 1
    fi
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check deployment status
    if kubectl rollout status deployment/"${HELM_RELEASE_NAME}" -n "${NAMESPACE}" --timeout=300s; then
        log_success "Deployment rollout completed"
    else
        log_error "Deployment rollout failed"
        return 1
    fi
    
    # Check pods
    log_info "Checking pod status..."
    kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=crypto-rates"
    
    # Check services
    log_info "Checking service status..."
    kubectl get services -n "${NAMESPACE}" -l "app.kubernetes.io/name=crypto-rates"
    
    return 0
}

run_smoke_tests() {
    log_info "Running smoke tests..."
    
    # Get service URL
    local service_port
    service_port=$(kubectl get service "${HELM_RELEASE_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.ports[0].nodePort}')
    
    # Get node IP
    local node_ip
    local context
    context=$(kubectl config current-context)
    
    if [[ $context == minikube ]]; then
        node_ip=$(minikube ip)
    elif [[ $context == kind-* ]]; then
        node_ip="127.0.0.1"
    else
        node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    fi
    
    local service_url="http://${node_ip}:${service_port}"
    
    log_info "Testing application at: ${service_url}"
    
    # Wait for service to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "${service_url}/health" > /dev/null 2>&1; then
            log_success "Health check passed"
            break
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
        
        if [ $attempt -gt $max_attempts ]; then
            log_error "Health check failed after ${max_attempts} attempts"
            return 1
        fi
    done
    
    # Test main endpoints
    local endpoints=("/" "/api/rates" "/metrics")
    
    for endpoint in "${endpoints[@]}"; do
        if curl -s -f "${service_url}${endpoint}" > /dev/null; then
            log_success "Endpoint ${endpoint} is accessible"
        else
            log_error "Endpoint ${endpoint} is not accessible"
            return 1
        fi
    done
    
    log_success "All smoke tests passed"
    echo ""
    echo "🎉 Application is ready!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  URL: ${service_url}"
    echo "  Namespace: ${NAMESPACE}"
    echo "  Release: ${HELM_RELEASE_NAME}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    return 0
}

port_forward() {
    log_info "Setting up port forwarding..."
    echo ""
    echo "You can access the application at:"
    echo "  http://localhost:8080"
    echo ""
    echo "Press Ctrl+C to stop port forwarding"
    
    kubectl port-forward -n "${NAMESPACE}" service/"${HELM_RELEASE_NAME}" 8080:80
}

show_status() {
    echo ""
    log_info "Deployment Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    echo "Pods:"
    kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=crypto-rates"
    
    echo ""
    echo "Services:"
    kubectl get services -n "${NAMESPACE}" -l "app.kubernetes.io/name=crypto-rates"
    
    echo ""
    echo "Helm Release:"
    helm list -n "${NAMESPACE}"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

cleanup() {
    log_warning "Cleaning up deployment..."
    
    if helm uninstall "${HELM_RELEASE_NAME}" -n "${NAMESPACE}"; then
        log_success "Helm release ${HELM_RELEASE_NAME} uninstalled"
    else
        log_error "Failed to uninstall Helm release"
    fi
    
    # Optionally delete namespace (uncomment if desired)
    # if kubectl delete namespace "${NAMESPACE}"; then
    #     log_success "Namespace ${NAMESPACE} deleted"
    # fi
}

usage() {
    echo "Usage: $0 [NAMESPACE] [IMAGE_TAG]"
    echo ""
    echo "Arguments:"
    echo "  NAMESPACE   Kubernetes namespace (default: crypto-rates-app)"
    echo "  IMAGE_TAG   Docker image tag (default: local)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Deploy to crypto-rates-app namespace"
    echo "  $0 my-test-ns v1.0.0   # Deploy to 'my-test-ns' with 'v1.0.0' tag"
    echo ""
    echo "Commands:"
    echo "  $0 cleanup             # Clean up deployment"
    echo "  $0 status              # Show deployment status"
    echo "  $0 port-forward        # Start port forwarding to access app"
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║           HeyCard Crypto Rates - Local Deploy           ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Handle special commands
    case "${1:-}" in
        "help"|"-h"|"--help")
            usage
            exit 0
            ;;
        "cleanup")
            cleanup
            exit 0
            ;;
        "status")
            show_status
            exit 0
            ;;
        "port-forward")
            port_forward
            exit 0
            ;;
    esac
    
    # Run deployment steps
    check_prerequisites
    check_kubernetes_connection
    build_docker_image
    create_namespace
    validate_helm_chart
    deploy_application
    
    if verify_deployment && run_smoke_tests; then
        show_status
        echo ""
        echo "🚀 Deployment completed successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Run port forwarding: $0 port-forward"
        echo "  2. Check status: $0 status"
        echo "  3. Clean up: $0 cleanup"
        echo ""
    else
        log_error "Deployment verification failed"
        echo ""
        echo "Troubleshooting:"
        echo "  kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=crypto-rates"
        echo "  kubectl describe pods -n ${NAMESPACE} -l app.kubernetes.io/name=crypto-rates"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"