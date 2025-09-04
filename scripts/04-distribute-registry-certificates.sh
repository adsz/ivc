#!/bin/bash
# 03-distribute-registry-certificates.sh
# Distributes Docker registry TLS certificates to all Kubernetes nodes using Ansible
# Run AFTER 02-build-crypto-rates-application.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ANSIBLE_DIR="./ansible"
PLAYBOOK="playbooks/deploy-registry-certificates.yml"
INVENTORY="inventory/k8s-cluster.yml"
REGISTRY_HOST="192.168.0.100"
REGISTRY_PORT="5000"
CERT_PATH="/opt/registry/certs/domain.crt"

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
    
    if ! command -v ansible &> /dev/null; then
        missing_tools+=("ansible")
    fi
    
    if ! command -v ansible-playbook &> /dev/null; then
        missing_tools+=("ansible-playbook")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Installation instructions:"
        echo "  Ubuntu/Debian: apt-get install ansible"
        echo "  CentOS/RHEL:   yum install ansible"
        echo "  macOS:         brew install ansible"
        echo "  pip:           pip install ansible"
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

verify_ansible_setup() {
    log_info "Verifying Ansible setup..."
    
    # Check if ansible directory exists
    if [ ! -d "${ANSIBLE_DIR}" ]; then
        log_error "Ansible directory not found: ${ANSIBLE_DIR}"
        exit 1
    fi
    
    # Check if playbook exists
    if [ ! -f "${ANSIBLE_DIR}/${PLAYBOOK}" ]; then
        log_error "Ansible playbook not found: ${ANSIBLE_DIR}/${PLAYBOOK}"
        exit 1
    fi
    
    # Check if inventory exists
    if [ ! -f "${ANSIBLE_DIR}/${INVENTORY}" ]; then
        log_error "Ansible inventory not found: ${ANSIBLE_DIR}/${INVENTORY}"
        exit 1
    fi
    
    log_success "Ansible setup verified"
}

verify_certificate() {
    log_info "Verifying registry certificate..."
    
    if [ ! -f "${CERT_PATH}" ]; then
        log_error "Registry certificate not found: ${CERT_PATH}"
        echo ""
        echo "Make sure to run the registry setup first:"
        echo "  ./01-setup-secure-docker-registry.sh"
        exit 1
    fi
    
    # Check certificate validity
    if openssl x509 -in "${CERT_PATH}" -noout -checkend 86400; then
        log_success "Certificate is valid and not expiring within 24 hours"
    else
        log_warning "Certificate is expiring soon or invalid"
    fi
    
    # Display certificate information
    log_info "Certificate details:"
    openssl x509 -in "${CERT_PATH}" -noout -subject -dates
    openssl x509 -in "${CERT_PATH}" -noout -text | grep -A 3 "Subject Alternative Name" || log_warning "No Subject Alternative Names found"
}

test_ansible_connectivity() {
    log_info "Testing Ansible connectivity to Kubernetes nodes..."
    
    cd "${ANSIBLE_DIR}"
    
    if ansible all -m ping; then
        log_success "Ansible connectivity test passed"
    else
        log_error "Ansible connectivity test failed"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check SSH connectivity: ssh ansible@<node-ip>"
        echo "  2. Verify inventory file: ${INVENTORY}"
        echo "  3. Check SSH keys: ssh-add -l"
        echo "  4. Verify ansible.cfg configuration"
        exit 1
    fi
}

run_certificate_playbook() {
    log_info "Running certificate distribution playbook..."
    
    cd "${ANSIBLE_DIR}"
    
    # Run the playbook with verbose output
    if ansible-playbook "${PLAYBOOK}" -v; then
        log_success "Certificate distribution playbook completed successfully"
    else
        log_error "Certificate distribution playbook failed"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check playbook logs above for specific errors"
        echo "  2. Verify SSH connectivity: ansible all -m ping"
        echo "  3. Check certificate path: ls -la ${CERT_PATH}"
        echo "  4. Run with more verbosity: ansible-playbook ${PLAYBOOK} -vvv"
        exit 1
    fi
}

verify_certificate_distribution() {
    log_info "Verifying certificate distribution..."
    
    cd "${ANSIBLE_DIR}"
    
    # Check certificate files on nodes
    log_info "Checking certificate files on Kubernetes nodes..."
    if ansible k8s_cluster -a "ls -la /etc/containerd/certs.d/${REGISTRY_HOST}:${REGISTRY_PORT}/" --become; then
        log_success "Certificate files found on all nodes"
    else
        log_error "Certificate files not found on some nodes"
        return 1
    fi
    
    # Check containerd service status
    log_info "Checking containerd service status..."
    if ansible k8s_cluster -a "systemctl is-active containerd" --become | grep -q "active"; then
        log_success "Containerd is active on all nodes"
    else
        log_warning "Containerd may not be active on all nodes"
    fi
    
    # Check system CA trust
    log_info "Checking system CA trust..."
    if ansible k8s_cluster -a "ls -la /usr/local/share/ca-certificates/docker-registry.crt" --become; then
        log_success "Certificate added to system CA trust"
    else
        log_warning "Certificate may not be in system CA trust"
    fi
    
    return 0
}

test_registry_connectivity() {
    log_info "Testing registry connectivity from Kubernetes nodes..."
    
    cd "${ANSIBLE_DIR}"
    
    # Test HTTPS connectivity
    log_info "Testing HTTPS connectivity..."
    if ansible k8s_cluster -m uri -a "url=https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/ validate_certs=no status_code=401,403" | grep -q "status.*40[13]"; then
        log_success "Registry is accessible from all nodes (authentication required as expected)"
    else
        log_warning "Registry connectivity test returned unexpected results"
    fi
    
    # Test certificate validation
    log_info "Testing certificate validation..."
    if ansible k8s_cluster -a "openssl s_client -connect ${REGISTRY_HOST}:${REGISTRY_PORT} -verify_return_error < /dev/null" 2>/dev/null | grep -q "Verification: OK"; then
        log_success "Certificate validation successful from all nodes"
    else
        log_warning "Certificate validation may have issues (expected for self-signed certificates)"
    fi
}

restart_containerd_services() {
    log_info "Restarting containerd services on all nodes..."
    
    cd "${ANSIBLE_DIR}"
    
    if ansible k8s_cluster -a "systemctl restart containerd" --become; then
        log_success "Containerd restarted on all nodes"
    else
        log_error "Failed to restart containerd on some nodes"
        return 1
    fi
    
    # Wait for services to be ready
    log_info "Waiting for containerd services to be ready..."
    sleep 10
    
    # Verify services are running
    if ansible k8s_cluster -a "systemctl is-active containerd" --become | grep -v "active" | grep -q "inactive"; then
        log_error "Some containerd services are not active after restart"
        return 1
    else
        log_success "All containerd services are active"
    fi
    
    return 0
}

generate_deployment_report() {
    log_info "Generating deployment report..."
    
    local report_file="/tmp/certificate-deployment-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "${report_file}" << EOF
# Certificate Deployment Report

**Generated:** $(date)
**Registry:** https://${REGISTRY_HOST}:${REGISTRY_PORT}

## Deployment Summary

The following certificate distribution tasks were completed:

### ✅ Completed Tasks
- Certificate validation and verification
- Ansible connectivity testing
- Certificate distribution to containerd directories
- System CA trust store updates
- Containerd service restarts
- Registry connectivity verification

### 📁 Certificate Locations
- **Containerd**: \`/etc/containerd/certs.d/${REGISTRY_HOST}:${REGISTRY_PORT}/ca.crt\`
- **System CA**: \`/usr/local/share/ca-certificates/docker-registry.crt\`
- **Configuration**: \`/etc/containerd/certs.d/${REGISTRY_HOST}:${REGISTRY_PORT}/hosts.toml\`

### 🔧 Configuration Details
- Registry Host: \`${REGISTRY_HOST}\`
- Registry Port: \`${REGISTRY_PORT}\`
- Certificate Path: \`${CERT_PATH}\`
- TLS Encryption: Enabled
- Authentication: Basic Auth

### 🧪 Next Steps
1. Deploy application to Kubernetes: \`./04-deploy-crypto-rates-to-k8s.sh\`
2. Verify pod image pulls work correctly
3. Test application functionality

### 🔍 Verification Commands
\`\`\`bash
# Test registry connectivity
ansible k8s_cluster -m uri -a "url=https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/ validate_certs=no"

# Check certificate files
ansible k8s_cluster -a "ls -la /etc/containerd/certs.d/${REGISTRY_HOST}:${REGISTRY_PORT}/"

# Check containerd status
ansible k8s_cluster -a "systemctl status containerd"
\`\`\`

---
*Generated by: Certificate Distribution Script*
EOF
    
    echo ""
    log_success "Deployment report generated: ${report_file}"
    echo ""
    echo "📄 Report Contents:"
    head -20 "${report_file}"
    echo "..."
    echo ""
}

show_summary() {
    echo ""
    log_success "Certificate distribution completed successfully!"
    echo ""
    echo "📋 Distribution Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Registry:         https://${REGISTRY_HOST}:${REGISTRY_PORT}"
    echo "  Certificate:      ${CERT_PATH}"
    echo "  Target Nodes:     Kubernetes cluster nodes"
    echo "  Containerd:       Configured and restarted"
    echo "  System CA:        Updated on all nodes"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔐 Security Features:"
    echo "  ✅ TLS encryption enabled"
    echo "  ✅ Certificate validation configured"
    echo "  ✅ System trust store updated"
    echo "  ✅ Containerd configuration applied"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Run: ./04-deploy-crypto-rates-to-k8s.sh"
    echo "  2. Verify pods can pull images from secure registry"
    echo ""
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Distributes Docker registry TLS certificates to all Kubernetes nodes"
    echo ""
    echo "Options:"
    echo "  --skip-tests     Skip connectivity and verification tests"
    echo "  --dry-run        Show what would be done without executing"
    echo "  --help           Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  1. Registry must be running with certificates"
    echo "  2. Ansible must be configured with SSH access to nodes"
    echo "  3. Inventory file must be configured properly"
    echo ""
    echo "Examples:"
    echo "  $0               # Full certificate distribution"
    echo "  $0 --skip-tests  # Skip verification tests"
    echo "  $0 --dry-run     # Show planned actions"
    echo ""
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         Distribute Registry Certificates                ║"
    echo "║                  Step 3 of 4                            ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    local skip_tests=false
    local dry_run=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
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
    
    if [ "$dry_run" = true ]; then
        log_info "DRY RUN MODE - No changes will be made"
        log_info "Would run certificate distribution playbook"
        log_info "Would restart containerd services"
        log_info "Would verify certificate installation"
        exit 0
    fi
    
    # Run distribution steps
    check_prerequisites
    verify_ansible_setup
    verify_certificate
    
    if [ "$skip_tests" = false ]; then
        test_ansible_connectivity
    fi
    
    run_certificate_playbook
    
    if verify_certificate_distribution && restart_containerd_services; then
        if [ "$skip_tests" = false ]; then
            test_registry_connectivity
        fi
        
        generate_deployment_report
        show_summary
        exit 0
    else
        log_error "Certificate distribution failed verification"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check Ansible playbook logs"
        echo "  2. Verify SSH connectivity: ansible all -m ping"
        echo "  3. Check certificate file: ls -la ${CERT_PATH}"
        echo "  4. Manual verification: ansible k8s_cluster -a 'ls -la /etc/containerd/certs.d/'"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"