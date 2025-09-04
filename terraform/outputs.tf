# Outputs for HeyCard Cryptocurrency Exchange Rates Infrastructure

# EKS Cluster Information
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster"
  value       = module.eks.cluster_status
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = module.eks.oidc_provider_arn
}

# Node Groups Information
output "eks_managed_node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value       = module.eks.eks_managed_node_groups
  sensitive   = true
}

output "eks_managed_node_groups_autoscaling_group_names" {
  description = "List of the autoscaling group names created by EKS managed node groups"
  value       = module.eks.eks_managed_node_groups_autoscaling_group_names
}

# VPC Information
output "vpc_id" {
  description = "ID of the VPC where the cluster security group was created"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT gateways"
  value       = module.vpc.nat_gateway_ids
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

# KMS Key Information
output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key for EKS encryption"
  value       = aws_kms_key.eks.arn
}

output "kms_key_id" {
  description = "The globally unique identifier for the KMS key"
  value       = aws_kms_key.eks.key_id
}

# IAM Roles for Service Accounts
output "ebs_csi_irsa_role_arn" {
  description = "ARN of the EBS CSI driver IRSA role"
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "aws_load_balancer_controller_irsa_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IRSA role"
  value       = module.aws_load_balancer_controller_irsa_role.iam_role_arn
}

output "external_dns_irsa_role_arn" {
  description = "ARN of the External DNS IRSA role"
  value       = module.external_dns_irsa_role.iam_role_arn
}

output "cluster_autoscaler_irsa_role_arn" {
  description = "ARN of the Cluster Autoscaler IRSA role"
  value       = module.cluster_autoscaler_irsa_role.iam_role_arn
}

# Application Configuration
output "application_url" {
  description = "URL to access the crypto-rates application"
  value       = "https://${var.subdomain_prefix}-${var.environment}.${var.domain_name}"
}

output "application_namespace" {
  description = "Kubernetes namespace for the application"
  value       = var.environment
}

# kubectl Configuration Command
output "configure_kubectl" {
  description = "Configure kubectl command"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name} --profile ${var.aws_profile}"
}

# Helm Configuration
output "helm_release_name" {
  description = "Helm release name for the application"
  value       = "${var.app_name}-${var.environment}"
}

# Monitoring URLs (if enabled)
output "grafana_url" {
  description = "Grafana dashboard URL (if monitoring is enabled)"
  value       = var.enable_monitoring ? "https://grafana-${var.environment}.${var.domain_name}" : "Monitoring not enabled"
}

output "prometheus_url" {
  description = "Prometheus URL (if monitoring is enabled)"
  value       = var.enable_monitoring ? "https://prometheus-${var.environment}.${var.domain_name}" : "Monitoring not enabled"
}

# Security Information
output "cluster_encryption_config" {
  description = "Cluster encryption configuration"
  value = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }
  sensitive = true
}

# Environment-specific Information
output "environment_config" {
  description = "Environment-specific configuration applied"
  value = {
    environment             = var.environment
    node_instance_types    = var.node_instance_types
    node_group_min_size    = var.node_group_min_size
    node_group_max_size    = var.node_group_max_size
    node_group_desired_size = var.node_group_desired_size
    app_replicas           = var.app_replicas
    enable_monitoring      = var.enable_monitoring
    enable_logging         = var.enable_logging
  }
}

# Cost Information
output "estimated_monthly_cost" {
  description = "Estimated monthly cost breakdown (approximate)"
  value = {
    eks_cluster     = "$73 (EKS control plane)"
    nat_gateway     = var.environment == "development" ? "$32 (1 NAT Gateway)" : "$96 (3 NAT Gateways)"
    worker_nodes    = "${var.node_group_desired_size} x ${var.node_instance_types[0]} nodes"
    load_balancer   = "~$23 per ALB"
    ebs_storage     = "${var.node_group_desired_size * var.node_disk_size}GB EBS storage"
    data_transfer   = "Variable based on usage"
    total_estimate  = "~$200-500/month depending on configuration"
  }
}

# Deployment Commands
output "deployment_commands" {
  description = "Commands to deploy the application after infrastructure is ready"
  value = {
    configure_kubectl = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name} --profile ${var.aws_profile}"
    create_namespace  = "kubectl create namespace ${var.environment} --dry-run=client -o yaml | kubectl apply -f -"
    deploy_app = join(" ", [
      "helm upgrade --install crypto-rates-${var.environment} ./helm/crypto-rates/",
      "--namespace ${var.environment}",
      "--set image.repository=${var.docker_image}",
      "--set replicaCount=${var.app_replicas}",
      "--set ingress.hosts[0].host=${var.subdomain_prefix}-${var.environment}.${var.domain_name}",
      "--wait --timeout=10m"
    ])
    check_deployment = "kubectl rollout status deployment/crypto-rates-${var.environment} -n ${var.environment}"
    get_pods        = "kubectl get pods -n ${var.environment}"
    get_services    = "kubectl get services -n ${var.environment}"
    get_ingress     = "kubectl get ingress -n ${var.environment}"
  }
}

# Additional Information
output "cluster_addons" {
  description = "EKS cluster addons installed"
  value = {
    coredns            = "Latest"
    kube_proxy         = "Latest"
    vpc_cni            = "Latest with prefix delegation enabled"
    aws_ebs_csi_driver = "Latest with IRSA role"
  }
}

output "tags_applied" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}