# DEPLOYMENT-GUIDE

## Overview

This guide provides step-by-step instructions for deploying the HeyCard Crypto Rates application in an enterprise Kubernetes environment with secure Docker registry.

## Prerequisites

### System Requirements
- **Kubernetes Cluster**: v1.29+ with at least 2 nodes
- **Docker**: v20.0+ for container operations
- **Ansible**: v4.0+ for automation
- **UV Package Manager**: Latest version for Python dependency management
- **OpenSSL**: For certificate generation

### Infrastructure Requirements
- **Master Node**: 192.168.0.180 (k8s-master-1)
- **Worker Node**: 192.168.0.190 (k8s-worker-1)
- **Registry Server**: 192.168.0.100:5000

### Network Configuration
- Pod Network: 10.244.0.0/16 (Calico CNI)
- Service Network: 10.96.0.0/12
- NodePort Range: 30000-32767

## Deployment Process

### Step 1: Setup Secure Docker Registry

**Script**: `./scripts/01-setup-secure-docker-registry.sh`

<details>
<summary>🔐 Registry Setup Details (click to expand)</summary>

```bash
# Run the registry setup script
./scripts/01-setup-secure-docker-registry.sh

# What this script does:
# ✅ Generates TLS certificates with Subject Alternative Names
# ✅ Creates registry authentication (htpasswd)
# ✅ Configures Docker Registry with security headers
# ✅ Starts registry with docker-compose
# ✅ Validates registry functionality
```

**Expected Output**:
```
📋 Registry Information:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Registry URL:     https://192.168.0.100:5000
  Registry UI:      http://192.168.0.100:8081
  Registry Domain:  registry.local
  Username:         admin
  Password:         registry123
  Certificate:      /opt/registry/certs/domain.crt
  Private Key:      /opt/registry/certs/domain.key
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
</details>

**Verification Commands**:
```bash
# Test registry health
curl -k https://192.168.0.100:5000/v2/

# Test authentication
curl -k -u admin:registry123 https://192.168.0.100:5000/v2/_catalog

# Check certificate
openssl s_client -connect 192.168.0.100:5000 -verify_return_error
```

### Step 2: Build and Push Application

**Script**: `./scripts/02-build-crypto-rates-application.sh`

<details>
<summary>🏗️ Application Build Process (click to expand)</summary>

```bash
# Build and push with default 'latest' tag
./scripts/02-build-crypto-rates-application.sh

# Build and push with specific tag
./scripts/02-build-crypto-rates-application.sh v1.0.0

# What this script does:
# ✅ Tests application locally with UV
# ✅ Builds optimized Docker image
# ✅ Tests container functionality
# ✅ Pushes image to secure registry
# ✅ Generates Kubernetes registry secret
```

**Build Process**:
1. **UV Dependency Management**: Fast dependency resolution
2. **Multi-stage Docker Build**: Optimized production image
3. **Security Scanning**: Container vulnerability checks
4. **Local Testing**: Health and API endpoint validation
5. **Registry Push**: Secure image storage
</details>

**Verification Commands**:
```bash
# List images in registry
curl -k -u admin:registry123 https://192.168.0.100:5000/v2/_catalog

# List tags for crypto-rates
curl -k -u admin:registry123 https://192.168.0.100:5000/v2/crypto-rates/tags/list

# View registry UI
open http://192.168.0.100:8081
```

### Step 3: Distribute Registry Certificates

**Script**: `./scripts/03-distribute-registry-certificates.sh`

<details>
<summary>🔧 Certificate Distribution Process (click to expand)</summary>

```bash
# Run certificate distribution
./scripts/03-distribute-registry-certificates.sh

# Skip verification tests (faster)
./scripts/03-distribute-registry-certificates.sh --skip-tests

# Dry run to see what would be done
./scripts/03-distribute-registry-certificates.sh --dry-run

# What this script does:
# ✅ Validates Ansible connectivity
# ✅ Distributes TLS certificates to all nodes
# ✅ Configures containerd for secure registry
# ✅ Updates system CA trust store
# ✅ Restarts containerd services
# ✅ Verifies certificate installation
```

**Certificate Locations**:
- **Containerd**: `/etc/containerd/certs.d/192.168.0.100:5000/ca.crt`
- **System CA**: `/usr/local/share/ca-certificates/docker-registry.crt`
- **Configuration**: `/etc/containerd/certs.d/192.168.0.100:5000/hosts.toml`
</details>

**Verification Commands**:
```bash
# Check certificate files
ansible k8s_cluster -a "ls -la /etc/containerd/certs.d/192.168.0.100:5000/"

# Check containerd status
ansible k8s_cluster -a "systemctl status containerd"

# Test registry connectivity
ansible k8s_cluster -m uri -a "url=https://192.168.0.100:5000/v2/ validate_certs=no"
```

### Step 4: Deploy to Kubernetes

**Script**: `./scripts/04-deploy-crypto-rates-to-k8s.sh`

<details>
<summary>☸️ Kubernetes Deployment Process (click to expand)</summary>

```bash
# Deploy to default crypto-rates-app namespace
./scripts/04-deploy-crypto-rates-to-k8s.sh

# Deploy to custom namespace
./scripts/04-deploy-crypto-rates-to-k8s.sh my-namespace latest

# What this script does:
# ✅ Validates Helm chart and Kubernetes connectivity
# ✅ Creates namespace with proper labels
# ✅ Deploys application using Helm
# ✅ Configures HPA, PDB, and NetworkPolicies
# ✅ Runs smoke tests and health checks
# ✅ Provides access information
```

**Kubernetes Resources Created**:
- **Deployment**: 2 replicas with rolling update strategy
- **Service**: NodePort for external access
- **ConfigMap**: Application configuration
- **Secret**: Registry authentication credentials
- **HPA**: CPU-based auto-scaling (2-10 replicas)
- **PDB**: Pod disruption budget (min 1 available)
- **NetworkPolicy**: Traffic segmentation rules
</details>

**Verification Commands**:
```bash
# Check deployment status
kubectl get pods -n crypto-rates-app

# Check services
kubectl get svc -n crypto-rates-app

# Check application logs
kubectl logs -n crypto-rates-app -l app=crypto-rates

# Test application
curl http://<node-ip>:<nodeport>/health
```

## Application Access

### Internal Access (within cluster)
```bash
# Port forwarding to localhost
kubectl port-forward -n crypto-rates-app svc/crypto-rates 8080:80

# Access application
curl http://localhost:8080/health
curl http://localhost:8080/api/rates
```

### External Access (NodePort)
```bash
# Get NodePort
kubectl get svc crypto-rates -n crypto-rates-app -o jsonpath='{.spec.ports[0].nodePort}'

# Access via node IP
curl http://192.168.0.190:<nodeport>/health
```

## API Endpoints

| Endpoint | Description | Method |
|----------|-------------|--------|
| `/` | Landing page with application info | GET |
| `/health` | Health check endpoint | GET |
| `/api/rates` | Cryptocurrency exchange rates | GET |
| `/metrics` | Prometheus metrics | GET |

### Example API Response
```json
{
  "last_updated": "2025-09-04T22:06:28.971941",
  "rates": {
    "btc": {
      "name": "Bitcoin",
      "type": "crypto", 
      "unit": "BTC",
      "value": 1.0
    },
    "usd": {
      "name": "US Dollar",
      "type": "fiat",
      "unit": "$", 
      "value": 110567.272
    }
  },
  "total_currencies": 76
}
```

## Security Configuration

### TLS Certificate Details
```bash
# View certificate information
openssl x509 -in /opt/registry/certs/domain.crt -text -noout

# Certificate includes:
# - Subject: CN=registry.local, O=HeyCard
# - SAN: DNS:registry.local, IP:192.168.0.100
# - Validity: 1 year
# - Key Usage: Digital Signature, Key Encipherment
```

### Registry Authentication
- **Username**: admin
- **Password**: registry123
- **Method**: HTTP Basic Authentication
- **Encoding**: Base64 encoded in Kubernetes secrets

### Network Security
- **TLS Encryption**: All registry communication encrypted
- **Certificate Validation**: Containerd validates certificates
- **Network Policies**: Pod-to-pod traffic restrictions
- **Security Context**: Non-root container execution

## Monitoring and Health Checks

### Application Health
```bash
# Health endpoint
curl http://<app-url>/health

# Expected response
{
  "status": "healthy",
  "timestamp": "2025-09-04T22:06:28.971941Z",
  "version": "1.0.0"
}
```

### Kubernetes Health
```bash
# Pod health
kubectl get pods -n crypto-rates-app

# Service health  
kubectl get endpoints -n crypto-rates-app

# Event logs
kubectl get events -n crypto-rates-app --sort-by='.lastTimestamp'
```

### Registry Health
```bash
# Registry health check
curl -k https://192.168.0.100:5000/v2/

# Registry UI
open http://192.168.0.100:8081
```

## Configuration Management

### Environment Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `FLASK_ENV` | production | Flask environment |
| `PORT` | 5000 | Application port |
| `WORKERS` | 4 | Gunicorn workers |
| `API_TIMEOUT` | 10 | CoinGecko API timeout |
| `CACHE_DURATION` | 300 | Cache duration (seconds) |

### Resource Limits
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Scaling Configuration
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

## Maintenance Operations

### Update Application
```bash
# Build new version
./scripts/02-build-crypto-rates-application.sh v2.0.0

# Deploy update
./scripts/04-deploy-crypto-rates-to-k8s.sh crypto-rates-app v2.0.0
```

### Scale Application
```bash
# Manual scaling
kubectl scale deployment crypto-rates -n crypto-rates-app --replicas=5

# Check HPA status
kubectl get hpa -n crypto-rates-app
```

### Certificate Renewal
```bash
# Regenerate certificates (when near expiry)
./scripts/01-setup-secure-docker-registry.sh

# Redistribute certificates
./scripts/03-distribute-registry-certificates.sh
```

## Cleanup Operations

### Remove Deployment
```bash
# Using deployment script
./scripts/04-deploy-crypto-rates-to-k8s.sh cleanup

# Manual cleanup
helm uninstall crypto-rates -n crypto-rates-app
kubectl delete namespace crypto-rates-app
```

### Stop Registry
```bash
cd docker/registry
docker-compose down

# Remove registry data (optional)
sudo rm -rf /opt/registry/
```

## Best Practices

### Security Best Practices
1. **Certificate Rotation**: Renew certificates before expiry
2. **Credential Management**: Use Kubernetes secrets for sensitive data
3. **Network Segmentation**: Implement NetworkPolicies
4. **Image Scanning**: Scan container images for vulnerabilities
5. **Resource Limits**: Set appropriate CPU/memory limits

### Operational Best Practices
1. **Monitoring**: Implement comprehensive monitoring
2. **Logging**: Centralized log management
3. **Backup**: Regular backup of configurations
4. **Testing**: Automated testing in CI/CD pipeline
5. **Documentation**: Keep deployment documentation updated

### Performance Best Practices
1. **Caching**: Implement intelligent API response caching
2. **Scaling**: Configure HPA for traffic patterns
3. **Resource Optimization**: Right-size container resources
4. **Network Optimization**: Use NodePort or LoadBalancer appropriately
5. **Database Optimization**: Optimize any data persistence layers

---

**🎉 Deployment Complete!**

Your HeyCard Crypto Rates application is now running securely in Kubernetes with:
- ✅ Secure Docker registry with TLS encryption
- ✅ Certificate-based authentication
- ✅ Enterprise-grade monitoring and scaling
- ✅ Production-ready security configuration

For support, check the [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) guide.