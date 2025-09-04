# SECURITY-GUIDE

## Overview

This document outlines the comprehensive security implementation for the HeyCard Crypto Rates application, covering infrastructure security, application security, and operational security best practices.

## Security Architecture

### Defense in Depth Strategy

```mermaid
graph TB
    subgraph "Network Layer"
        FW[Firewall Rules]
        NP[NetworkPolicies]
        TLS[TLS Encryption]
    end
    
    subgraph "Infrastructure Layer"
        CERT[Certificate Management]
        AUTH[Registry Authentication]
        RBAC[Kubernetes RBAC]
    end
    
    subgraph "Application Layer"
        HEADERS[Security Headers]
        VALID[Input Validation]
        RATE[Rate Limiting]
    end
    
    subgraph "Data Layer"
        CACHE[Secure Caching]
        LOGS[Audit Logging]
        SECRETS[Secret Management]
    end
    
    FW --> CERT
    NP --> AUTH
    TLS --> RBAC
    CERT --> HEADERS
    AUTH --> VALID
    RBAC --> RATE
    HEADERS --> CACHE
    VALID --> LOGS
    RATE --> SECRETS
```

## Certificate Management

### TLS Certificate Infrastructure

**Certificate Authority (Self-Signed)**:
```
Subject: CN=registry.local, O=HeyCard, L=DevOps, ST=Enterprise, C=PL
Issuer: CN=registry.local, O=HeyCard, L=DevOps, ST=Enterprise, C=PL
Validity: 365 days
Key Length: 2048 bits RSA
Signature Algorithm: SHA256withRSA
```

**Subject Alternative Names**:
- `DNS: registry.local`
- `DNS: localhost`
- `IP: 192.168.0.100`  
- `IP: 127.0.0.1`

### Certificate Distribution

**Automated Distribution via Ansible**:
```yaml
# Certificate locations on all Kubernetes nodes
containerd_cert_path: /etc/containerd/certs.d/192.168.0.100:5000/ca.crt
system_ca_path: /usr/local/share/ca-certificates/docker-registry.crt
hosts_config: /etc/containerd/certs.d/192.168.0.100:5000/hosts.toml
```

**Certificate Validation**:
```bash
# Verify certificate installation
openssl x509 -in /opt/registry/certs/domain.crt -text -noout | grep -E "(Subject|DNS|IP)"

# Test certificate chain
openssl s_client -connect 192.168.0.100:5000 -verify_return_error
```

### Certificate Rotation

**Automated Renewal Process**:
1. **Pre-expiry Check**: Monitor certificate expiry (30 days warning)
2. **Generate New Certificate**: Update with same SAN configuration
3. **Distribute Certificate**: Use Ansible automation
4. **Restart Services**: Containerd and registry services
5. **Validate Deployment**: Test connectivity and image pulls

```bash
# Certificate expiry check
openssl x509 -in /opt/registry/certs/domain.crt -noout -checkend $((30*24*3600))

# Renewal command
./scripts/01-setup-secure-docker-registry.sh --renew-cert
./scripts/03-distribute-registry-certificates.sh
```

## Docker Registry Security

### Registry Configuration

**Security Headers**:
```yaml
http:
  headers:
    X-Content-Type-Options: [nosniff]
    X-Frame-Options: [DENY]
    Strict-Transport-Security: [max-age=63072000; includeSubDomains; preload]
```

**Authentication Configuration**:
```yaml
auth:
  htpasswd:
    realm: "Registry Realm"
    path: /auth/htpasswd
```

**TLS Configuration**:
```yaml
http:
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key
```

### Registry Authentication

**htpasswd Authentication**:
- **Algorithm**: bcrypt (Blowfish-based, cost factor 10)
- **Username**: admin
- **Password**: registry123 (configurable)
- **File Location**: `/auth/htpasswd`

**Kubernetes Secret Integration**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-secret
  namespace: crypto-rates-app
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

**Docker Config Structure**:
```json
{
  "auths": {
    "192.168.0.100:5000": {
      "username": "admin",
      "password": "registry123",
      "email": "admin@heycard.com",
      "auth": "YWRtaW46cmVnaXN0cnkxMjM="
    }
  }
}
```

## Kubernetes Security

### Pod Security

**Security Context Configuration**:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

**Resource Limits**:
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
    ephemeral-storage: 1Gi
  requests:
    cpu: 100m
    memory: 128Mi
    ephemeral-storage: 500Mi
```

### Network Security

**NetworkPolicy Implementation**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: crypto-rates-netpol
spec:
  podSelector:
    matchLabels:
      app: crypto-rates
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: crypto-rates-app
    ports:
    - protocol: TCP
      port: 5000
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443  # HTTPS to CoinGecko API
    - protocol: TCP
      port: 53   # DNS
    - protocol: UDP
      port: 53   # DNS
```

### RBAC Configuration

**Service Account**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: crypto-rates-sa
  namespace: crypto-rates-app
```

**Role and RoleBinding**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: crypto-rates-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: crypto-rates-rolebinding
subjects:
- kind: ServiceAccount
  name: crypto-rates-sa
roleRef:
  kind: Role
  name: crypto-rates-role
  apiGroup: rbac.authorization.k8s.io
```

## Application Security

### HTTP Security Headers

**Implemented Headers**:
```python
@app.after_request
def security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'  
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=63072000; includeSubDomains'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self' 'unsafe-inline'"
    return response
```

### Input Validation and Sanitization

**Request Validation**:
```python
from werkzeug.exceptions import BadRequest
import re

def validate_request_params(request):
    """Validate and sanitize request parameters"""
    # Check for suspicious patterns
    suspicious_patterns = [
        r'<script.*?>.*?</script>',  # XSS
        r'union.*select',           # SQL injection
        r'javascript:',             # JavaScript injection
        r'\.\./',                  # Path traversal
    ]
    
    for param_value in request.args.values():
        for pattern in suspicious_patterns:
            if re.search(pattern, param_value, re.IGNORECASE):
                raise BadRequest("Invalid request parameters")
```

### Rate Limiting

**Application-Level Rate Limiting**:
```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["1000 per hour", "100 per minute"]
)

@app.route('/api/rates')
@limiter.limit("10 per minute")
def get_rates():
    # Rate-limited endpoint implementation
    pass
```

### Error Handling Security

**Secure Error Responses**:
```python
@app.errorhandler(Exception)
def handle_error(error):
    # Log detailed error for debugging
    app.logger.error(f"Error: {str(error)}", exc_info=True)
    
    # Return generic error to client (avoid information disclosure)
    return {
        "error": "Internal server error",
        "code": "INTERNAL_ERROR",
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }, 500
```

## Secrets Management

### Kubernetes Secrets

**Registry Authentication Secret**:
```bash
# Create registry secret
kubectl create secret docker-registry registry-secret \
  --docker-server=192.168.0.100:5000 \
  --docker-username=admin \
  --docker-password=registry123 \
  --docker-email=admin@heycard.com \
  --namespace=crypto-rates-app
```

**Application Configuration Secret**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: crypto-rates-config
  namespace: crypto-rates-app
type: Opaque
data:
  coingecko-api-key: <base64-encoded-key>
  flask-secret-key: <base64-encoded-secret>
stringData:
  database-url: "postgresql://user:pass@host:5432/db"
```

### Secret Rotation

**Automated Secret Rotation**:
1. **Generate New Secrets**: Use secure random generation
2. **Update Kubernetes Secrets**: kubectl patch or replace
3. **Rolling Restart**: Update pods to use new secrets
4. **Validate Application**: Ensure functionality with new secrets
5. **Cleanup**: Remove old secrets after validation

```bash
# Secret rotation script example
#!/bin/bash
NEW_PASSWORD=$(openssl rand -base64 32)
kubectl patch secret registry-secret -n crypto-rates-app \
  --type='json' -p='[{"op": "replace", "path": "/data/password", "value":"'$(echo -n $NEW_PASSWORD | base64)'"}]'
```

## Container Security

### Base Image Security

**Alpine Linux Base**:
```dockerfile
FROM python:3.11-alpine
# Alpine benefits:
# - Minimal attack surface (5MB base)
# - Regular security updates  
# - musl libc (smaller, simpler)
# - Package manager with signature verification
```

**Security Scanning**:
```bash
# Scan container image for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/tmp aquasec/trivy image crypto-rates:latest

# Scan filesystem
docker run --rm -v $(pwd):/tmp aquasec/trivy fs /tmp
```

### Runtime Security

**Container Runtime Configuration**:
```yaml
spec:
  containers:
  - name: crypto-rates
    securityContext:
      runAsNonRoot: true
      runAsUser: 1000
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

**Resource Constraints**:
```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
    ephemeral-storage: 1Gi
  requests:
    cpu: 100m  
    memory: 128Mi
```

## Monitoring and Auditing

### Security Monitoring

**Application Security Metrics**:
```python
# Custom security metrics
from prometheus_client import Counter, Histogram

security_events = Counter('security_events_total', 
                         'Security events', ['type', 'severity'])
request_validation_time = Histogram('request_validation_seconds',
                                   'Time spent validating requests')

# Usage
security_events.labels(type='xss_attempt', severity='high').inc()
```

**Log-based Monitoring**:
```python
import logging

security_logger = logging.getLogger('security')

def log_security_event(event_type, details, severity='info'):
    security_logger.log(
        getattr(logging, severity.upper()),
        json.dumps({
            'event_type': event_type,
            'details': details,
            'timestamp': datetime.utcnow().isoformat(),
            'source_ip': request.remote_addr,
            'user_agent': request.user_agent.string
        })
    )
```

### Audit Logging

**Kubernetes Audit Policy**:
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  namespaces: ["crypto-rates-app"]
```

**Application Audit Events**:
- Authentication attempts
- Configuration changes
- Error conditions
- Security policy violations
- Resource access patterns

## Incident Response

### Security Incident Response Plan

**Phase 1: Detection and Analysis**
1. **Automated Alerting**: Security monitoring triggers
2. **Initial Assessment**: Determine incident scope and severity
3. **Evidence Collection**: Preserve logs and system state
4. **Containment Strategy**: Isolate affected systems

**Phase 2: Containment and Eradication**  
1. **Immediate Containment**: Stop ongoing attack
2. **System Isolation**: Network segmentation
3. **Threat Removal**: Eliminate attack vectors
4. **Vulnerability Patching**: Address root causes

**Phase 3: Recovery and Post-Incident**
1. **System Restoration**: Return to normal operations
2. **Monitoring Enhancement**: Improved detection
3. **Documentation**: Incident report and lessons learned
4. **Process Improvement**: Update security procedures

### Emergency Procedures

**Compromise Detection**:
```bash
# Check for unauthorized access
kubectl get events -n crypto-rates-app --sort-by='.lastTimestamp'
kubectl logs -n crypto-rates-app -l app=crypto-rates --tail=1000 | grep -i "error\|fail\|unauthorized"

# Review registry access logs
docker logs crypto-rates-registry | grep -E "(40[13]|50[0-9])"
```

**Immediate Response Actions**:
```bash
# Isolate compromised pods
kubectl scale deployment crypto-rates -n crypto-rates-app --replicas=0

# Rotate secrets
kubectl delete secret registry-secret -n crypto-rates-app
kubectl create secret docker-registry registry-secret --docker-server=... 

# Update registry credentials
htpasswd -B -c /opt/registry/auth/htpasswd admin $(openssl rand -base64 12)
```

## Compliance and Standards

### Security Standards Compliance

**ISO 27001 Alignment**:
- **A.9**: Access Control Management
- **A.10**: Cryptography Controls  
- **A.12**: Operations Security
- **A.13**: Communications Security
- **A.14**: System Development Security

**NIST Cybersecurity Framework**:
- **Identify**: Asset and risk management
- **Protect**: Access control and data security
- **Detect**: Security monitoring and logging
- **Respond**: Incident response procedures
- **Recover**: Recovery planning and improvements

### Security Assessment

**Regular Security Reviews**:
- **Weekly**: Automated vulnerability scanning
- **Monthly**: Security configuration review
- **Quarterly**: Penetration testing
- **Annually**: Comprehensive security audit

**Security Testing**:
```bash
# Automated security testing
docker run --rm -it -v $(pwd):/app \
  securecodewarrior/docker-security-scanner /app

# Network security testing  
nmap -sS -O 192.168.0.100 -p 5000,8081

# SSL/TLS testing
testssl.sh 192.168.0.100:5000
```

## Security Best Practices

### Development Security

**Secure Coding Guidelines**:
1. **Input Validation**: Validate all user inputs
2. **Output Encoding**: Encode data in output contexts
3. **Authentication**: Implement strong authentication
4. **Authorization**: Principle of least privilege
5. **Error Handling**: Avoid information disclosure
6. **Logging**: Log security-relevant events
7. **Cryptography**: Use established algorithms

### Operational Security

**Security Hardening Checklist**:
- [ ] Regular security updates applied
- [ ] Unnecessary services disabled
- [ ] Strong password policies enforced
- [ ] Multi-factor authentication enabled
- [ ] Network segmentation implemented
- [ ] Monitoring and alerting configured
- [ ] Backup and recovery tested
- [ ] Incident response plan documented

### Deployment Security

**Secure Deployment Pipeline**:
1. **Code Security Scanning**: Static analysis and dependency checking
2. **Container Scanning**: Vulnerability assessment
3. **Configuration Validation**: Security policy compliance
4. **Runtime Testing**: Dynamic security testing
5. **Monitoring Setup**: Security monitoring configuration

---

**🔒 Security Implementation Complete**

This comprehensive security implementation provides:
- ✅ End-to-end encryption with TLS certificates
- ✅ Multi-layered authentication and authorization
- ✅ Container and Kubernetes security hardening
- ✅ Comprehensive monitoring and auditing
- ✅ Incident response procedures
- ✅ Compliance with security standards

Regular security reviews and updates ensure continued protection against evolving threats.