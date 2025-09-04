#!/bin/bash
# Development environment setup script for HeyCard Crypto Rates
# Uses UV for Python package management following enterprise standards

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    
    # Check UV
    if ! command -v uv &> /dev/null; then
        log_warning "UV not found, installing..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
        
        if ! command -v uv &> /dev/null; then
            log_error "Failed to install UV"
            exit 1
        fi
        log_success "UV installed successfully"
    else
        log_success "UV is available"
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Installation instructions:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                docker)
                    echo "  docker: https://docs.docker.com/get-docker/"
                    ;;
                kubectl)
                    echo "  kubectl: https://kubernetes.io/docs/tasks/tools/"
                    ;;
                helm)
                    echo "  helm: https://helm.sh/docs/intro/install/"
                    ;;
            esac
        done
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

setup_python_project() {
    log_info "Setting up Python project with UV..."
    
    cd app/
    
    # Initialize UV project if pyproject.toml doesn't exist
    if [ ! -f "pyproject.toml" ]; then
        log_info "Initializing UV project..."
        uv init --name crypto-rates --python 3.11
        
        # Remove the default hello.py if created
        rm -f hello.py
        
        # Add our dependencies
        uv add flask requests prometheus-client gunicorn
        uv add --dev pytest pytest-cov pytest-html requests-mock flake8 bandit safety
        
        log_success "UV project initialized"
    else
        log_info "UV project already initialized, syncing dependencies..."
        uv sync
        log_success "Dependencies synced"
    fi
    
    cd ..
}

run_tests() {
    log_info "Running Python tests with UV..."
    
    cd app/
    
    # Run linting
    log_info "Running code quality checks..."
    uv run flake8 --max-line-length=88 --exclude=venv,__pycache__ . || log_warning "Linting issues found"
    
    # Run security scan
    log_info "Running security scan..."
    uv run bandit -r . -f json -o bandit-report.json || log_warning "Security issues found"
    
    # Run safety check
    log_info "Running dependency vulnerability check..."
    uv run safety check || log_warning "Vulnerability issues found"
    
    # Run unit tests
    log_info "Running unit tests..."
    if [ -f "test_main.py" ]; then
        uv run pytest test_main.py -v --cov=. --cov-report=html --cov-report=term
        log_success "Unit tests completed"
    else
        log_warning "No test file found (test_main.py)"
    fi
    
    cd ..
}

start_local_app() {
    log_info "Starting application locally with UV..."
    
    cd app/
    
    echo ""
    echo "🚀 Starting HeyCard Crypto Rates application..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  URL: http://localhost:5000"
    echo "  Health: http://localhost:5000/health"
    echo "  API: http://localhost:5000/api/rates"
    echo "  Metrics: http://localhost:5000/metrics"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Press Ctrl+C to stop the application"
    echo ""
    
    # Set development environment variables
    export FLASK_DEBUG=true
    export FLASK_ENV=development
    export PORT=5000
    
    # Run with UV
    uv run python main.py
}

test_k8s_connection() {
    log_info "Testing Kubernetes connection..."
    
    if ! kubectl cluster-info > /dev/null 2>&1; then
        log_error "Cannot connect to Kubernetes cluster"
        echo ""
        echo "Available contexts:"
        kubectl config get-contexts || true
        echo ""
        echo "Current context: $(kubectl config current-context 2>/dev/null || echo 'none')"
        return 1
    fi
    
    local context
    context=$(kubectl config current-context)
    log_success "Connected to Kubernetes cluster: ${context}"
    
    # Show cluster info
    echo ""
    log_info "Cluster information:"
    kubectl get nodes
    
    return 0
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║        HeyCard Crypto Rates - Development Setup         ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Parse command line arguments
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            setup_python_project
            log_success "Development environment setup completed!"
            echo ""
            echo "Next steps:"
            echo "  1. Run tests: $0 test"
            echo "  2. Start app: $0 run"
            echo "  3. Deploy to K8s: ./scripts/deploy-local.sh"
            ;;
        "test")
            check_prerequisites
            setup_python_project
            run_tests
            ;;
        "run")
            check_prerequisites
            setup_python_project
            start_local_app
            ;;
        "k8s-check")
            test_k8s_connection
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  setup       Setup development environment (default)"
            echo "  test        Run tests and quality checks"
            echo "  run         Start application locally"
            echo "  k8s-check   Test Kubernetes connection"
            echo "  help        Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0          # Setup development environment"
            echo "  $0 run      # Start application locally"
            echo "  $0 test     # Run tests and quality checks"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"