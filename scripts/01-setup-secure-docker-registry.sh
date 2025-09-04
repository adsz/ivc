#!/bin/bash
# 01-setup-secure-docker-registry.sh
# Sets up a secure Docker registry with TLS certificates and authentication
# This script must be run FIRST to establish the secure registry infrastructure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY_HOST="192.168.0.100"
REGISTRY_PORT="5000"
REGISTRY_DOMAIN="registry.local"
CERT_DIR="/opt/registry/certs"
AUTH_DIR="/opt/registry/auth"
CONFIG_DIR="/opt/registry"
REGISTRY_USER="admin"
REGISTRY_PASS="registry123"

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
    
    if ! command -v openssl &> /dev/null; then
        missing_tools+=("openssl")
    fi
    
    if ! command -v htpasswd &> /dev/null; then
        missing_tools+=("htpasswd (apache2-utils)")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  Ubuntu/Debian: apt-get install openssl apache2-utils docker.io"
        echo "  CentOS/RHEL:   yum install openssl httpd-tools docker"
        echo "  macOS:         brew install openssl apache2-utils docker"
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

create_directories() {
    log_info "Creating registry directories..."
    
    sudo mkdir -p "${CERT_DIR}"
    sudo mkdir -p "${AUTH_DIR}"
    sudo mkdir -p "${CONFIG_DIR}"
    sudo mkdir -p "/opt/registry/data"
    
    # Set proper permissions
    sudo chown -R ${USER}:${USER} "${CONFIG_DIR}"
    
    log_success "Registry directories created"
}

generate_certificates() {
    log_info "Generating TLS certificates..."
    
    # Generate private key
    sudo openssl genrsa -out "${CERT_DIR}/domain.key" 2048
    
    # Create certificate signing request configuration
    cat > /tmp/registry.conf << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=PL
ST=Enterprise
L=DevOps
O=HeyCard
CN=${REGISTRY_DOMAIN}

[v3_req]
basicConstraints = CA:TRUE
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${REGISTRY_DOMAIN}
DNS.2 = localhost
IP.1 = ${REGISTRY_HOST}
IP.2 = 127.0.0.1
EOF

    # Generate certificate
    sudo openssl req -new -x509 -key "${CERT_DIR}/domain.key" \
        -out "${CERT_DIR}/domain.crt" \
        -days 365 \
        -config /tmp/registry.conf \
        -extensions v3_req
    
    # Set proper permissions
    sudo chmod 600 "${CERT_DIR}/domain.key"
    sudo chmod 644 "${CERT_DIR}/domain.crt"
    
    # Clean up temporary config
    rm /tmp/registry.conf
    
    log_success "TLS certificates generated"
    
    # Display certificate information
    log_info "Certificate details:"
    sudo openssl x509 -in "${CERT_DIR}/domain.crt" -text -noout | grep -A 2 "Subject:"
    sudo openssl x509 -in "${CERT_DIR}/domain.crt" -text -noout | grep -A 3 "Subject Alternative Name"
}

setup_authentication() {
    log_info "Setting up registry authentication..."
    
    # Generate htpasswd file
    sudo htpasswd -Bbn "${REGISTRY_USER}" "${REGISTRY_PASS}" > /tmp/htpasswd
    sudo mv /tmp/htpasswd "${AUTH_DIR}/htpasswd"
    sudo chmod 600 "${AUTH_DIR}/htpasswd"
    
    log_success "Registry authentication configured"
    log_info "Registry credentials: ${REGISTRY_USER}:${REGISTRY_PASS}"
}

create_registry_config() {
    log_info "Creating registry configuration..."
    
    cat > "${CONFIG_DIR}/config.yml" << EOF
version: 0.1
log:
  fields:
    service: registry
    environment: production
  level: info
  formatter: text

storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true

http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
    X-Frame-Options: [DENY]
    Strict-Transport-Security: [max-age=63072000; includeSubDomains; preload]
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key

auth:
  htpasswd:
    realm: "Registry Realm"
    path: /auth/htpasswd

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3

validation:
  disabled: false
EOF
    
    log_success "Registry configuration created"
}

start_registry_docker_compose() {
    log_info "Starting Docker registry with docker-compose..."
    
    cd docker/registry
    
    # Create data directory
    mkdir -p data
    mkdir -p auth
    mkdir -p certs
    mkdir -p config
    
    # Copy certificates and auth files
    sudo cp "${CERT_DIR}/domain.crt" certs/
    sudo cp "${CERT_DIR}/domain.key" certs/
    sudo cp "${AUTH_DIR}/htpasswd" auth/
    sudo cp "${CONFIG_DIR}/config.yml" config/
    
    # Fix permissions
    sudo chown -R ${USER}:${USER} .
    chmod 600 certs/domain.key
    chmod 644 certs/domain.crt
    chmod 600 auth/htpasswd
    
    # Start registry
    docker-compose up -d
    
    log_success "Docker registry started with docker-compose"
}

verify_registry() {
    log_info "Verifying registry setup..."
    
    # Wait for registry to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -k -f "https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/" > /dev/null 2>&1; then
            log_success "Registry is responding to health checks"
            break
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
        
        if [ $attempt -gt $max_attempts ]; then
            log_error "Registry failed to start after ${max_attempts} attempts"
            return 1
        fi
    done
    
    # Test authentication
    log_info "Testing registry authentication..."
    if curl -k -u "${REGISTRY_USER}:${REGISTRY_PASS}" "https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/_catalog" > /dev/null 2>&1; then
        log_success "Registry authentication is working"
    else
        log_error "Registry authentication failed"
        return 1
    fi
    
    # Test certificate
    log_info "Testing TLS certificate..."
    if echo | openssl s_client -connect "${REGISTRY_HOST}:${REGISTRY_PORT}" -verify_return_error 2>/dev/null; then
        log_success "TLS certificate is valid"
    else
        log_warning "TLS certificate validation failed (expected for self-signed certificates)"
    fi
    
    return 0
}

show_summary() {
    echo ""
    log_success "Registry setup completed successfully!"
    echo ""
    echo "📋 Registry Information:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Registry URL:     https://${REGISTRY_HOST}:${REGISTRY_PORT}"
    echo "  Registry UI:      http://${REGISTRY_HOST}:8081"
    echo "  Registry Domain:  ${REGISTRY_DOMAIN}"
    echo "  Username:         ${REGISTRY_USER}"
    echo "  Password:         ${REGISTRY_PASS}"
    echo "  Certificate:      ${CERT_DIR}/domain.crt"
    echo "  Private Key:      ${CERT_DIR}/domain.key"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔐 Test Commands:"
    echo "  curl -k -u ${REGISTRY_USER}:${REGISTRY_PASS} https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/_catalog"
    echo ""
    echo "📦 Next Steps:"
    echo "  1. Run: ./02-build-crypto-rates-application.sh"
    echo "  2. Run: ./03-distribute-registry-certificates.sh"
    echo "  3. Run: ./04-deploy-crypto-rates-to-k8s.sh"
    echo ""
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Sets up a secure Docker registry with TLS certificates and authentication"
    echo ""
    echo "Options:"
    echo "  --registry-host HOST    Registry host IP (default: ${REGISTRY_HOST})"
    echo "  --registry-port PORT    Registry port (default: ${REGISTRY_PORT})"
    echo "  --registry-user USER    Registry username (default: ${REGISTRY_USER})"
    echo "  --registry-pass PASS    Registry password (default: ${REGISTRY_PASS})"
    echo "  --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Use default settings"
    echo "  $0 --registry-host 10.0.0.100              # Use custom host"
    echo "  $0 --registry-user myuser --registry-pass mypass  # Use custom credentials"
    echo ""
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              Secure Docker Registry Setup               ║"
    echo "║                  Step 1 of 4                            ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --registry-host)
                REGISTRY_HOST="$2"
                shift 2
                ;;
            --registry-port)
                REGISTRY_PORT="$2"
                shift 2
                ;;
            --registry-user)
                REGISTRY_USER="$2"
                shift 2
                ;;
            --registry-pass)
                REGISTRY_PASS="$2"
                shift 2
                ;;
            --help|-h)
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
    
    # Run setup steps
    check_prerequisites
    create_directories
    generate_certificates
    setup_authentication
    create_registry_config
    start_registry_docker_compose
    
    if verify_registry; then
        show_summary
        exit 0
    else
        log_error "Registry setup failed verification"
        echo ""
        echo "Troubleshooting:"
        echo "  docker-compose logs registry"
        echo "  sudo journalctl -u docker"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"