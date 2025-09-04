# Variables for HeyCard Cryptocurrency Exchange Rates Infrastructure

# Basic Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "crypto-rates"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"
  
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "owner" {
  description = "Owner of the infrastructure"
  type        = string
  default     = "devops-team"
}

# AWS Configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-central-1"
  
  validation {
    condition = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be in valid format (e.g., eu-central-1)."
  }
}

variable "aws_profile" {
  description = "AWS profile to use for deployment"
  type        = string
  default     = "aws5"
}

# EKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
  
  validation {
    condition = can(regex("^[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format X.Y (e.g., 1.28)."
  }
}

# Node Group Configuration
variable "node_instance_types" {
  description = "Instance types for EKS managed node groups"
  type        = list(string)
  default     = ["t3.medium"]
  
  validation {
    condition = alltrue([
      for instance_type in var.node_instance_types :
      can(regex("^[a-z0-9]+\\.[a-z0-9]+$", instance_type))
    ])
    error_message = "Instance types must be in valid format (e.g., t3.medium)."
  }
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the managed node group"
  type        = number
  default     = 1
  
  validation {
    condition     = var.node_group_min_size >= 1 && var.node_group_min_size <= 100
    error_message = "Node group minimum size must be between 1 and 100."
  }
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the managed node group"
  type        = number
  default     = 10
  
  validation {
    condition     = var.node_group_max_size >= 1 && var.node_group_max_size <= 100
    error_message = "Node group maximum size must be between 1 and 100."
  }
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the managed node group"
  type        = number
  default     = 3
  
  validation {
    condition     = var.node_group_desired_size >= 1 && var.node_group_desired_size <= 100
    error_message = "Node group desired size must be between 1 and 100."
  }
}

variable "node_disk_size" {
  description = "Disk size for worker nodes (in GB)"
  type        = number
  default     = 50
  
  validation {
    condition     = var.node_disk_size >= 20 && var.node_disk_size <= 1000
    error_message = "Node disk size must be between 20 and 1000 GB."
  }
}

variable "key_pair_name" {
  description = "AWS Key Pair name for EC2 access"
  type        = string
  default     = "devops-lab-keypair"
}

# Application Configuration
variable "app_name" {
  description = "Application name"
  type        = string
  default     = "crypto-rates"
}

variable "app_version" {
  description = "Application version"
  type        = string
  default     = "1.0.0"
}

variable "docker_image" {
  description = "Docker image for the application"
  type        = string
  default     = "crypto-rates:latest"
}

variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 3
  
  validation {
    condition     = var.app_replicas >= 1 && var.app_replicas <= 50
    error_message = "Application replicas must be between 1 and 50."
  }
}

# Monitoring and Logging
variable "enable_monitoring" {
  description = "Enable Prometheus and Grafana monitoring stack"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable ELK stack for centralized logging"
  type        = bool
  default     = true
}

variable "enable_ingress_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable External DNS for automatic DNS management"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Enable cert-manager for automatic TLS certificates"
  type        = bool
  default     = true
}

# Domain Configuration
variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "devops-lab.cloud"
}

variable "subdomain_prefix" {
  description = "Subdomain prefix for the application"
  type        = string
  default     = "crypto-rates"
}

# Security Configuration
variable "enable_pod_security_policy" {
  description = "Enable Pod Security Policy"
  type        = bool
  default     = false # PSP is deprecated, use Pod Security Standards instead
}

variable "enable_network_policy" {
  description = "Enable Network Policies"
  type        = bool
  default     = true
}

variable "enable_rbac" {
  description = "Enable RBAC"
  type        = bool
  default     = true
}

# Backup Configuration
variable "enable_velero" {
  description = "Enable Velero for backup and disaster recovery"
  type        = bool
  default     = false
}

# Cost Optimization
variable "enable_spot_instances" {
  description = "Enable spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "spot_instance_types" {
  description = "Instance types for spot instances"
  type        = list(string)
  default     = ["t3.medium", "t3.large", "m5.large"]
}

# Advanced Configuration
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_endpoint_private_access_cidrs" {
  description = "CIDR blocks that can access the private API server endpoint"
  type        = list(string)
  default     = []
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

# Environment-specific configurations
variable "environment_config" {
  description = "Environment-specific configuration overrides"
  type = map(object({
    node_instance_types    = optional(list(string))
    node_group_min_size   = optional(number)
    node_group_max_size   = optional(number)
    node_group_desired_size = optional(number)
    app_replicas          = optional(number)
    enable_monitoring     = optional(bool)
  }))
  default = {
    development = {
      node_instance_types    = ["t3.small"]
      node_group_min_size   = 1
      node_group_max_size   = 3
      node_group_desired_size = 2
      app_replicas          = 2
      enable_monitoring     = false
    }
    staging = {
      node_instance_types    = ["t3.medium"]
      node_group_min_size   = 2
      node_group_max_size   = 5
      node_group_desired_size = 3
      app_replicas          = 3
      enable_monitoring     = true
    }
    production = {
      node_instance_types    = ["t3.large", "m5.large"]
      node_group_min_size   = 3
      node_group_max_size   = 10
      node_group_desired_size = 5
      app_replicas          = 5
      enable_monitoring     = true
    }
  }
}