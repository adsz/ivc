#!/usr/bin/env groovy
/**
 * Enterprise CI/CD Pipeline for HeyCard Cryptocurrency Exchange Rates Application
 * 
 * This pipeline implements a comprehensive build, test, security scan, and deployment
 * workflow following enterprise DevOps best practices.
 */

pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['development', 'staging', 'production'],
            description: 'Target deployment environment'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip running tests (not recommended for production)'
        )
        booleanParam(
            name: 'FORCE_DEPLOY',
            defaultValue: false,
            description: 'Force deployment even if security scans fail'
        )
        string(
            name: 'IMAGE_TAG',
            defaultValue: 'latest',
            description: 'Docker image tag to build/deploy'
        )
    }
    
    environment {
        // Registry configuration
        DOCKER_REGISTRY = 'docker.io'
        IMAGE_NAME = 'crypto-rates'
        IMAGE_TAG = "${params.IMAGE_TAG != 'latest' ? params.IMAGE_TAG : env.BUILD_NUMBER}"
        FULL_IMAGE_NAME = "${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        
        // AWS configuration
        AWS_DEFAULT_REGION = 'eu-central-1'
        AWS_PROFILE = 'aws5'
        EKS_CLUSTER_NAME = 'devops-lab-cluster'
        
        // Security and quality gates
        SONAR_PROJECT_KEY = 'heycard-crypto-rates'
        SECURITY_SCAN_THRESHOLD = 'HIGH'
        
        // Helm configuration
        HELM_CHART_PATH = './helm/crypto-rates'
        HELM_RELEASE_NAME = 'crypto-rates'
        K8S_NAMESPACE = "${params.ENVIRONMENT}"
        
        // Notification settings
        SLACK_CHANNEL = '#devops-alerts'
        TEAMS_WEBHOOK = credentials('teams-webhook-url')
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
        skipDefaultCheckout(true)
    }
    
    stages {
        stage('🚀 Initialize') {
            steps {
                script {
                    // Clean workspace and checkout
                    cleanWs()
                    checkout scm
                    
                    // Set build description
                    currentBuild.description = "Environment: ${params.ENVIRONMENT} | Tag: ${IMAGE_TAG}"
                    
                    // Validate parameters
                    if (params.ENVIRONMENT == 'production' && params.SKIP_TESTS) {
                        error("Tests cannot be skipped for production deployments")
                    }
                    
                    // Display build information
                    echo """
                    ╔══════════════════════════════════════╗
                    ║         BUILD INFORMATION            ║
                    ╠══════════════════════════════════════╣
                    ║ Environment: ${params.ENVIRONMENT.padRight(20)} ║
                    ║ Image Tag:   ${IMAGE_TAG.padRight(20)} ║
                    ║ Build #:     ${env.BUILD_NUMBER.padRight(20)} ║
                    ║ Git Branch:  ${env.BRANCH_NAME?.padRight(20) ?: 'N/A'.padRight(20)} ║
                    ╚══════════════════════════════════════╝
                    """
                }
            }
        }
        
        stage('📊 Code Quality & Security Analysis') {
            parallel {
                stage('🔍 Static Code Analysis') {
                    when {
                        not { params.SKIP_TESTS }
                    }
                    steps {
                        script {
                            sh '''
                                echo "Running static code analysis..."
                                
                                # Python linting with flake8
                                pip3 install flake8 bandit safety
                                
                                # Code style check
                                flake8 app/ --max-line-length=88 --exclude=venv,__pycache__ || true
                                
                                # Security linting with bandit
                                bandit -r app/ -f json -o bandit-report.json || true
                                
                                # Dependency vulnerability check
                                safety check --json --output safety-report.json || true
                            '''
                        }
                        
                        // Archive reports
                        archiveArtifacts artifacts: '*-report.json', fingerprint: true, allowEmptyArchive: true
                        
                        // Publish results (if SonarQube is available)
                        script {
                            try {
                                withSonarQubeEnv('SonarQube') {
                                    sh "${tool 'SonarScanner'}/bin/sonar-scanner"
                                }
                            } catch (Exception e) {
                                echo "SonarQube analysis skipped: ${e.message}"
                            }
                        }
                    }
                }
                
                stage('🧪 Unit Tests') {
                    when {
                        not { params.SKIP_TESTS }
                    }
                    steps {
                        script {
                            sh '''
                                echo "Running unit tests..."
                                
                                # Install test dependencies
                                pip3 install pytest pytest-cov pytest-html requests-mock
                                
                                # Run tests with coverage
                                python3 -m pytest app/ \
                                    --cov=app \
                                    --cov-report=xml:coverage.xml \
                                    --cov-report=html:htmlcov \
                                    --junit-xml=pytest-report.xml \
                                    --html=pytest-report.html \
                                    --self-contained-html \
                                    -v || true
                            '''
                        }
                        
                        // Publish test results
                        publishTestResults testResultsPattern: 'pytest-report.xml'
                        publishCoverage adapters: [
                            coberturaAdapter('coverage.xml')
                        ], sourceFileResolver: sourceFiles('STORE_LAST_BUILD')
                        
                        // Archive artifacts
                        archiveArtifacts artifacts: 'pytest-report.html,htmlcov/**', fingerprint: true
                    }
                }
                
                stage('🔒 Container Security Scan') {
                    steps {
                        script {
                            sh '''
                                echo "Running container security analysis..."
                                
                                # Install and run Trivy for Dockerfile scanning
                                if ! command -v trivy &> /dev/null; then
                                    echo "Installing Trivy..."
                                    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
                                    echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
                                    sudo apt-get update && sudo apt-get install -y trivy
                                fi
                                
                                # Scan Dockerfile
                                trivy config --format json --output trivy-dockerfile.json . || true
                                
                                # Scan requirements for vulnerabilities
                                trivy fs --format json --output trivy-deps.json app/requirements.txt || true
                            '''
                            
                            archiveArtifacts artifacts: 'trivy-*.json', fingerprint: true, allowEmptyArchive: true
                        }
                    }
                }
            }
        }
        
        stage('🏗️ Build & Package') {
            parallel {
                stage('🐳 Build Docker Image') {
                    steps {
                        script {
                            echo "Building Docker image: ${FULL_IMAGE_NAME}"
                            
                            // Build image with build args
                            sh """
                                docker build \
                                    --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                    --build-arg VCS_REF=\$(git rev-parse --short HEAD) \
                                    --build-arg VERSION=${IMAGE_TAG} \
                                    --tag ${FULL_IMAGE_NAME} \
                                    --tag ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest \
                                    .
                            """
                            
                            // Test image health
                            sh """
                                echo "Testing Docker image..."
                                docker run --rm -d --name test-container -p 15000:5000 ${FULL_IMAGE_NAME}
                                sleep 10
                                
                                # Health check
                                if curl -f http://localhost:15000/health; then
                                    echo "✅ Image health check passed"
                                else
                                    echo "❌ Image health check failed"
                                    exit 1
                                fi
                                
                                docker stop test-container || true
                            """
                        }
                    }
                }
                
                stage('📦 Validate Helm Chart') {
                    steps {
                        script {
                            sh """
                                echo "Validating Helm chart..."
                                
                                # Install Helm if not available
                                if ! command -v helm &> /dev/null; then
                                    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                                fi
                                
                                # Lint Helm chart
                                helm lint ${HELM_CHART_PATH}
                                
                                # Template and validate
                                helm template ${HELM_RELEASE_NAME} ${HELM_CHART_PATH} \
                                    --set image.tag=${IMAGE_TAG} \
                                    --set image.repository=${DOCKER_REGISTRY}/${IMAGE_NAME} \
                                    --namespace ${K8S_NAMESPACE} > rendered-manifests.yaml
                                
                                # Validate Kubernetes manifests
                                if command -v kubeval &> /dev/null; then
                                    kubeval rendered-manifests.yaml
                                fi
                            """
                            
                            archiveArtifacts artifacts: 'rendered-manifests.yaml', fingerprint: true
                        }
                    }
                }
            }
        }
        
        stage('🔐 Advanced Security Scanning') {
            when {
                not { params.FORCE_DEPLOY }
            }
            steps {
                script {
                    sh """
                        echo "Running advanced security scans..."
                        
                        # Scan built image for vulnerabilities
                        trivy image --format json --output trivy-image.json ${FULL_IMAGE_NAME} || true
                        
                        # Check for high/critical vulnerabilities
                        HIGH_VULNS=\$(trivy image --format json ${FULL_IMAGE_NAME} | jq '.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH" or .Severity=="CRITICAL") | .VulnerabilityID' | wc -l)
                        
                        echo "Found \$HIGH_VULNS high/critical vulnerabilities"
                        
                        if [ \$HIGH_VULNS -gt 0 ] && [ "${params.ENVIRONMENT}" = "production" ]; then
                            echo "❌ High/Critical vulnerabilities found in production build!"
                            echo "Run with FORCE_DEPLOY=true to bypass this check (not recommended)"
                            exit 1
                        fi
                    """
                    
                    archiveArtifacts artifacts: 'trivy-image.json', fingerprint: true, allowEmptyArchive: true
                }
            }
        }
        
        stage('🚢 Deploy to Kubernetes') {
            when {
                anyOf {
                    environment name: 'ENVIRONMENT', value: 'development'
                    environment name: 'ENVIRONMENT', value: 'staging'
                    allOf {
                        environment name: 'ENVIRONMENT', value: 'production'
                        anyOf {
                            branch 'main'
                            branch 'master'
                        }
                    }
                }
            }
            steps {
                script {
                    // Push image to registry
                    withDockerRegistry([credentialsId: 'docker-registry-creds', url: "https://${DOCKER_REGISTRY}"]) {
                        sh """
                            echo "Pushing image to registry..."
                            docker push ${FULL_IMAGE_NAME}
                            docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest
                        """
                    }
                    
                    // Deploy with Helm
                    withAWS(profile: env.AWS_PROFILE, region: env.AWS_DEFAULT_REGION) {
                        sh """
                            echo "Deploying to Kubernetes..."
                            
                            # Update kubeconfig
                            aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}
                            
                            # Create namespace if it doesn't exist
                            kubectl create namespace ${K8S_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Deploy with Helm
                            helm upgrade --install ${HELM_RELEASE_NAME} ${HELM_CHART_PATH} \
                                --namespace ${K8S_NAMESPACE} \
                                --set image.tag=${IMAGE_TAG} \
                                --set image.repository=${DOCKER_REGISTRY}/${IMAGE_NAME} \
                                --set ingress.hosts[0].host=crypto-rates-${params.ENVIRONMENT}.devops-lab.cloud \
                                --values ${HELM_CHART_PATH}/values-${params.ENVIRONMENT}.yaml \
                                --wait --timeout=10m
                            
                            # Verify deployment
                            kubectl rollout status deployment/${HELM_RELEASE_NAME} -n ${K8S_NAMESPACE} --timeout=600s
                        """
                    }
                }
            }
        }
        
        stage('✅ Post-Deployment Tests') {
            when {
                anyOf {
                    environment name: 'ENVIRONMENT', value: 'development'
                    environment name: 'ENVIRONMENT', value: 'staging'
                    environment name: 'ENVIRONMENT', value: 'production'
                }
            }
            parallel {
                stage('🔍 Smoke Tests') {
                    steps {
                        script {
                            sh """
                                echo "Running smoke tests..."
                                
                                # Get service URL
                                SERVICE_URL="https://crypto-rates-${params.ENVIRONMENT}.devops-lab.cloud"
                                
                                # Wait for service to be ready
                                for i in {1..30}; do
                                    if curl -f \$SERVICE_URL/health; then
                                        echo "✅ Service is healthy"
                                        break
                                    fi
                                    echo "Waiting for service... (\$i/30)"
                                    sleep 10
                                done
                                
                                # Test main endpoints
                                curl -f \$SERVICE_URL/ > /dev/null
                                curl -f \$SERVICE_URL/api/rates > /dev/null
                                curl -f \$SERVICE_URL/metrics > /dev/null
                                
                                echo "✅ All smoke tests passed"
                            """
                        }
                    }
                }
                
                stage('📊 Performance Tests') {
                    when {
                        anyOf {
                            environment name: 'ENVIRONMENT', value: 'staging'
                            environment name: 'ENVIRONMENT', value: 'production'
                        }
                    }
                    steps {
                        script {
                            sh """
                                echo "Running performance tests..."
                                
                                # Install k6 if not available
                                if ! command -v k6 &> /dev/null; then
                                    echo "Installing k6..."
                                    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
                                    echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
                                    sudo apt-get update && sudo apt-get install -y k6
                                fi
                                
                                # Run performance tests
                                SERVICE_URL="https://crypto-rates-${params.ENVIRONMENT}.devops-lab.cloud"
                                
                                k6 run --out json=performance-results.json - <<EOF
                                import http from 'k6/http';
                                import { check, sleep } from 'k6';
                                
                                export let options = {
                                    stages: [
                                        { duration: '2m', target: 10 },
                                        { duration: '5m', target: 10 },
                                        { duration: '2m', target: 0 },
                                    ],
                                };
                                
                                export default function() {
                                    let response = http.get('\${SERVICE_URL}/api/rates');
                                    check(response, {
                                        'status is 200': (r) => r.status === 200,
                                        'response time < 2s': (r) => r.timings.duration < 2000,
                                    });
                                    sleep(1);
                                }
EOF
                            """
                            
                            archiveArtifacts artifacts: 'performance-results.json', fingerprint: true, allowEmptyArchive: true
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                // Cleanup test containers
                sh 'docker stop test-container 2>/dev/null || true'
                sh 'docker rm test-container 2>/dev/null || true'
                
                // Archive build logs
                archiveArtifacts artifacts: 'build.log', fingerprint: true, allowEmptyArchive: true
            }
        }
        
        success {
            script {
                echo "🎉 Pipeline completed successfully!"
                
                // Notification
                try {
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'good',
                        message: """
                        ✅ *Deployment Successful* 
                        
                        *Project:* HeyCard Crypto Rates
                        *Environment:* ${params.ENVIRONMENT}
                        *Version:* ${IMAGE_TAG}
                        *Branch:* ${env.BRANCH_NAME ?: 'N/A'}
                        *Build:* ${env.BUILD_NUMBER}
                        
                        🌐 *URL:* https://crypto-rates-${params.ENVIRONMENT}.devops-lab.cloud
                        """.stripIndent()
                    )
                } catch (Exception e) {
                    echo "Slack notification failed: ${e.message}"
                }
            }
        }
        
        failure {
            script {
                echo "❌ Pipeline failed!"
                
                try {
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'danger',
                        message: """
                        ❌ *Deployment Failed*
                        
                        *Project:* HeyCard Crypto Rates
                        *Environment:* ${params.ENVIRONMENT}
                        *Branch:* ${env.BRANCH_NAME ?: 'N/A'}
                        *Build:* ${env.BUILD_NUMBER}
                        *Stage:* ${env.STAGE_NAME ?: 'Unknown'}
                        
                        📋 *Build Log:* ${env.BUILD_URL}console
                        """.stripIndent()
                    )
                } catch (Exception e) {
                    echo "Slack notification failed: ${e.message}"
                }
            }
        }
        
        unstable {
            echo "⚠️ Pipeline completed with warnings"
        }
        
        cleanup {
            // Clean workspace
            cleanWs(
                cleanWhenAborted: true,
                cleanWhenFailure: false,
                cleanWhenNotBuilt: true,
                cleanWhenSuccess: true,
                cleanWhenUnstable: false,
                deleteDirs: true
            )
        }
    }
}