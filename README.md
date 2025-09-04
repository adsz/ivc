# 🚀 HeyCard Crypto Rates - Enterprise DevOps Solution

[![Build Status](https://jenkins.devops-lab.cloud/buildStatus/icon?job=crypto-rates%2Fmain)](https://jenkins.devops-lab.cloud/job/crypto-rates/job/main/)
[![Docker Image](https://img.shields.io/badge/docker-crypto--rates-blue)](https://hub.docker.com/r/crypto-rates)
[![Kubernetes](https://img.shields.io/badge/kubernetes-ready-green)](./helm/crypto-rates/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Complete enterprise-grade DevOps infrastructure solution for cryptocurrency exchange rates application. Demonstrates best practices in containerization, Kubernetes deployment, secure registry management, and automation using Python Flask, Docker, Kubernetes, Ansible, and UV package manager.

## 📋 Project Overview

This project demonstrates a complete DevOps implementation for a real-time cryptocurrency exchange rates application, showcasing:

- **Modern Application Development**: Python Flask with responsive web interface
- **Containerization**: Multi-stage Docker builds with security best practices
- **Kubernetes Orchestration**: Production-ready Helm charts with monitoring
- **Infrastructure as Code**: Complete AWS EKS infrastructure with Terraform
- **Enterprise CI/CD**: Jenkins and GitHub Actions pipelines with security scanning
- **Monitoring & Security**: Prometheus metrics, security scanning, and compliance

## 🏗️ Architecture

### Complete DevOps Infrastructure
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │  Secure Docker  │    │   Kubernetes    │
│   Workstation   │───▶│    Registry     │───▶│    Cluster      │
│                 │    │  (TLS + Auth)   │    │ (crypto-rates)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   UV Package    │    │   Certificate   │    │   CoinGecko     │
│   Management    │    │   Distribution  │    │   API Access   │
│                 │    │   (Ansible)     │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Application Architecture  
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   User Browser  │───▶│  Load Balancer   │───▶│  Kubernetes     │
└─────────────────┘    └──────────────────┘    │  EKS Cluster    │
                                                └─────────────────┘
                                                          │
                              ┌─────────────────────────┬─┴─────────────────────┐
                              │                         │                       │
                    ┌─────────▼──────────┐   ┌─────────▼──────────┐   ┌────────▼───────┐
                    │  Crypto-Rates App  │   │   Prometheus       │   │    Grafana     │
                    │  (2-10 replicas)   │   │   (Monitoring)     │   │ (Dashboards)   │
                    └─────────┬──────────┘   └────────────────────┘   └────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │  CoinGecko API     │
                    │  (External)        │
                    └────────────────────┘
```

## 🌟 Features

### Application Features
- **Real-time Exchange Rates**: Live data from CoinGecko API
- **Responsive Design**: Bootstrap-based UI that works on all devices
- **Multiple Currency Types**: Supports fiat, cryptocurrency, and commodities
- **Auto-refresh**: Automatic data refresh every 5 minutes
- **Health Monitoring**: Built-in health checks and metrics endpoints
- **Error Handling**: Graceful error handling with fallback mechanisms

### Enterprise Features
- **Production-Ready**: Enterprise-grade security, monitoring, and scalability
- **Multi-Environment**: Development, staging, and production configurations
- **Auto-scaling**: Horizontal Pod Autoscaler based on CPU/memory usage
- **High Availability**: Multi-AZ deployment with pod anti-affinity
- **Security**: Network policies, RBAC, security scanning, and container hardening
- **Monitoring**: Prometheus metrics, Grafana dashboards, centralized logging
- **Disaster Recovery**: Backup strategies and rollback procedures

### Prerequisites

- Docker
- Kubernetes cluster (minikube, kind, or EKS)  
- Helm 3.x
- kubectl
- Ansible
- UV package manager
- OpenSSL
- AWS CLI (for EKS deployment)
- Terraform (for infrastructure)

## 🚀 Quick Start

### Enterprise Deployment (Recommended)

1. **Setup Registry** (Run once)
   ```bash
   ./scripts/01-setup-secure-docker-registry.sh
   ```

2. **Build Application**
   ```bash
   ./scripts/02-build-crypto-rates-application.sh
   ```

3. **Test Local Docker Build** (Recommended before deployment)
   ```bash
   ./scripts/03-test-local-docker.sh
   ```

4. **Distribute Certificates** (Run once per cluster)
   ```bash
   ./scripts/04-distribute-registry-certificates.sh
   ```

5. **Deploy to Kubernetes**
   ```bash
   ./scripts/05-deploy-crypto-rates-to-k8s.sh
   ```

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd interview-challenge
   ```

2. **Setup Python environment**
   ```bash
   # Automated setup (recommended)
   ./scripts/setup-dev.sh
   
   # Or manual setup
   curl -LsSf https://astral.sh/uv/install.sh | sh
   uv sync
   ```

3. **Run locally**
   ```bash
   # Start with UV
   uv run python app/main.py
   
   # Or run with Docker
   docker build -t crypto-rates:local .
   docker run -p 5000:5000 crypto-rates:local
   ```

4. **Access the application**
   - Open browser: http://localhost:5000
   - Health check: http://localhost:5000/health
   - API endpoint: http://localhost:5000/api/rates
   - Metrics: http://localhost:5000/metrics

### Kubernetes Deployment

1. **Deploy with Helm**
   ```bash
   # Create namespace
   kubectl create namespace development
   
   # Deploy application
   helm upgrade --install crypto-rates helm/crypto-rates/ \
     --namespace development \
     --set image.repository=crypto-rates \
     --set image.tag=latest \
     --wait
   ```

2. **Verify deployment**
   ```bash
   kubectl get pods -n development
   kubectl get services -n development
   kubectl get ingress -n development
   ```

### AWS EKS Production Deployment

1. **Deploy infrastructure with Terraform**
   ```bash
   cd terraform/
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your configuration
   
   terraform init
   terraform plan
   terraform apply
   ```

2. **Configure kubectl**
   ```bash
   aws eks update-kubeconfig --region eu-central-1 --name crypto-rates-production
   ```

3. **Deploy application**
   ```bash
   # Use the deployment commands from Terraform outputs
   terraform output deployment_commands
   ```

## 📁 Project Structure

```
interview-challenge/
├── app/                          # Application source code
│   ├── main.py                   # Flask application
│   ├── requirements.txt          # Python dependencies
│   └── templates/                # HTML templates
├── helm/crypto-rates/            # Helm chart for Kubernetes
│   ├── Chart.yaml               # Chart metadata
│   ├── values.yaml              # Default values
│   └── templates/               # Kubernetes manifests
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                  # Main Terraform configuration
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Output values
│   └── helm.tf                  # Helm provider configuration
├── ci/                          # CI/CD configurations
│   └── .github/workflows/       # GitHub Actions
├── docs/                        # Documentation
├── scripts/                     # Utility scripts
├── Dockerfile                   # Container build configuration
├── Jenkinsfile                  # Jenkins pipeline
└── README.md                    # This file
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Application port | `5000` |
| `FLASK_ENV` | Flask environment | `production` |
| `API_TIMEOUT` | CoinGecko API timeout (seconds) | `10` |
| `CACHE_DURATION` | Cache duration (seconds) | `300` |
| `WORKERS` | Gunicorn worker processes | `4` |

### Helm Configuration

Key configuration options in `values.yaml`:

```yaml
# Scaling
replicaCount: 3
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10

# Security
securityContext:
  runAsNonRoot: true
  runAsUser: 1000

# Monitoring
monitoring:
  enabled: true
```

## 🛠️ CI/CD Pipelines

### Jenkins Pipeline

The Jenkins pipeline includes:
- **Code Quality**: Static analysis, linting, security scanning
- **Testing**: Unit tests with coverage reporting
- **Building**: Multi-stage Docker builds
- **Security**: Container vulnerability scanning with Trivy
- **Deployment**: Automated deployment to Kubernetes
- **Monitoring**: Post-deployment testing and health checks

### GitHub Actions

Alternative CI/CD pipeline with:
- Parallel execution of quality checks
- Multi-environment deployment strategy
- Security scanning integration
- Automated notifications

## 📊 Monitoring & Observability

### Prometheus Metrics

The application exposes metrics at `/metrics`:
- `crypto_app_requests_total`: Total HTTP requests
- `crypto_app_request_duration_seconds`: Request duration histogram
- `coingecko_api_calls_total`: CoinGecko API call counter

### Health Checks

- **Liveness Probe**: `/health` - Application health status
- **Readiness Probe**: `/health` - Ready to serve traffic
- **Startup Probe**: `/health` - Application startup completion

### Grafana Dashboards

Pre-configured dashboards for:
- Application performance metrics
- Kubernetes cluster health
- Infrastructure monitoring
- Business metrics (exchange rate trends)

## 🔒 Security

### Application Security
- **Non-root container**: Runs as unprivileged user
- **Security context**: ReadOnlyRootFilesystem, no privilege escalation
- **Input validation**: API input sanitization
- **Error handling**: No sensitive information in error responses

### Infrastructure Security
- **Network Policies**: Restricted pod-to-pod communication
- **RBAC**: Role-based access control
- **Secrets Management**: Kubernetes secrets for sensitive data
- **TLS Encryption**: End-to-end encryption with cert-manager

### CI/CD Security
- **Static Analysis**: Bandit for Python security issues
- **Dependency Scanning**: Safety for vulnerability detection
- **Container Scanning**: Trivy for image vulnerabilities
- **Compliance**: Automated security gate in pipelines

## 🧪 Testing

### Unit Tests
```bash
# Install test dependencies
pip install pytest pytest-cov requests-mock

# Run tests with coverage
pytest app/ --cov=app --cov-report=html
```

### Integration Tests
```bash
# Test with Docker container
docker run --rm -d --name test-app -p 15000:5000 crypto-rates:latest
curl -f http://localhost:15000/health
docker stop test-app
```

### Load Testing
```bash
# Using k6 (installed in CI pipeline)
k6 run - <<EOF
import http from 'k6/http';
export default function() {
  http.get('https://crypto-rates.devops-lab.cloud/api/rates');
}
EOF
```

## 📈 Performance

### Optimization Features
- **Response Caching**: 5-minute cache for API responses
- **Connection Pooling**: Efficient HTTP connections
- **Gzip Compression**: Reduced payload sizes
- **CDN Ready**: Static assets optimization
- **Horizontal Scaling**: Auto-scaling based on demand

### Performance Metrics
- **Response Time**: < 2 seconds for API calls
- **Throughput**: 100+ requests per second per pod
- **Memory Usage**: ~128MB per container
- **CPU Usage**: 100m request, 500m limit

## 🚨 Troubleshooting

### Common Issues

1. **Application Not Starting**
   ```bash
   # Check pod logs
   kubectl logs -l app=crypto-rates -n development
   
   # Check events
   kubectl get events -n development --sort-by=.metadata.creationTimestamp
   ```

2. **CoinGecko API Errors**
   ```bash
   # Check if API is accessible
   curl -f https://api.coingecko.com/api/v3/exchange_rates
   
   # Check application logs for rate limiting
   kubectl logs deployment/crypto-rates -n development | grep "API"
   ```

3. **Ingress/Load Balancer Issues**
   ```bash
   # Check ALB controller logs
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   
   # Check ingress status
   kubectl describe ingress crypto-rates -n development
   ```

### Debug Mode

Enable debug mode by setting environment variable:
```yaml
env:
  - name: FLASK_DEBUG
    value: "true"
```

## 🛠️ Available Scripts

### Enterprise Deployment Scripts (Numbered Execution Order)
- **`01-setup-secure-docker-registry.sh`** - Sets up secure Docker registry with TLS certificates and authentication
- **`02-build-crypto-rates-application.sh`** - Builds application image and pushes to secure registry  
- **`03-test-local-docker.sh`** - Tests application locally with Docker build and comprehensive endpoint validation
- **`04-distribute-registry-certificates.sh`** - Distributes TLS certificates to Kubernetes nodes using Ansible
- **`05-deploy-crypto-rates-to-k8s.sh`** - Deploys application to Kubernetes using Helm charts

### Development Tools
- **`setup-dev.sh`** - Development environment setup with UV package manager
  - Installs UV if not present
  - Initializes Python project with dependencies
  - Runs code quality checks (flake8, bandit, safety)  
  - Executes unit tests with coverage reporting
  - Starts local development server

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes**: Follow coding standards and add tests
4. **Run tests**: Ensure all tests pass
5. **Commit changes**: `git commit -m 'Add amazing feature'`
6. **Push to branch**: `git push origin feature/amazing-feature`
7. **Create Pull Request**: Use the provided template

### Development Guidelines

- **Code Style**: Follow PEP 8 for Python, use Black formatter
- **Testing**: Maintain >90% test coverage
- **Documentation**: Update README and code comments
- **Security**: Follow security best practices
- **Performance**: Consider performance impact of changes

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **CoinGecko API**: For providing cryptocurrency exchange rate data
- **AWS**: For cloud infrastructure and services
- **Kubernetes Community**: For container orchestration platform
- **Prometheus/Grafana**: For monitoring and observability
- **Jenkins**: For CI/CD automation

## 📚 Documentation

Complete documentation is available in the `docs/` folder:

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - System architecture and design decisions
- **[DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md)** - Step-by-step deployment procedures  
- **[API-DOCUMENTATION.md](docs/API-DOCUMENTATION.md)** - Complete API reference with examples
- **[SECURITY-GUIDE.md](docs/SECURITY-GUIDE.md)** - Comprehensive security implementation guide

## 📞 Support

For support and questions:
- **Documentation**: Check this README and inline code comments
- **Issues**: Create GitHub issue with detailed description
- **DevOps Team**: Contact devops-team@heycard.com
- **Monitoring**: Check Grafana dashboards for system health

---

**Built with ❤️ by the HeyCard DevOps Team**

*This project demonstrates enterprise-grade DevOps practices suitable for production cryptocurrency trading applications.*