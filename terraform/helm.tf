# Helm charts deployment for EKS cluster add-ons and monitoring

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_ingress_controller ? 1 : 0
  
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"
  
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }
  
  set {
    name  = "region"
    value = var.aws_region
  }
  
  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }
  
  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}

# External DNS
resource "helm_release" "external_dns" {
  count = var.enable_external_dns ? 1 : 0
  
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = "1.13.1"
  
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  
  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }
  
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.external_dns_irsa_role.iam_role_arn
  }
  
  set {
    name  = "provider"
    value = "aws"
  }
  
  set {
    name  = "aws.region"
    value = var.aws_region
  }
  
  set {
    name  = "domainFilters[0]"
    value = var.domain_name
  }
  
  set {
    name  = "txtOwnerId"
    value = local.name
  }
  
  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.29.0"
  
  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }
  
  set {
    name  = "awsRegion"
    value = var.aws_region
  }
  
  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }
  
  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }
  
  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.cluster_autoscaler_irsa_role.iam_role_arn
  }
  
  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "10m"
  }
  
  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "10m"
  }
  
  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}

# Cert Manager
resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0
  
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.13.1"
  
  set {
    name  = "installCRDs"
    value = "true"
  }
  
  set {
    name  = "prometheus.enabled"
    value = var.enable_monitoring
  }
  
  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}

# Prometheus and Grafana Stack (kube-prometheus-stack)
resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_monitoring ? 1 : 0
  
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "51.2.0"
  
  # Prometheus configuration
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d"
  }
  
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "50Gi"
  }
  
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "gp2"
  }
  
  # Grafana configuration
  set {
    name  = "grafana.enabled"
    value = "true"
  }
  
  set {
    name  = "grafana.adminPassword"
    value = "admin123" # In production, use a secret
  }
  
  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }
  
  set {
    name  = "grafana.persistence.size"
    value = "10Gi"
  }
  
  set {
    name  = "grafana.persistence.storageClassName"
    value = "gp2"
  }
  
  # Ingress for Grafana
  set {
    name  = "grafana.ingress.enabled"
    value = "true"
  }
  
  set {
    name  = "grafana.ingress.ingressClassName"
    value = "alb"
  }
  
  set {
    name  = "grafana.ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }
  
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }
  
  set {
    name  = "grafana.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }
  
  set {
    name  = "grafana.ingress.hosts[0]"
    value = "grafana-${var.environment}.${var.domain_name}"
  }
  
  # AlertManager configuration
  set {
    name  = "alertmanager.enabled"
    value = "true"
  }
  
  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }
  
  depends_on = [
    module.eks.eks_managed_node_groups,
    helm_release.aws_load_balancer_controller,
  ]
}

# ELK Stack for Logging (if enabled)
resource "helm_release" "elasticsearch" {
  count = var.enable_logging ? 1 : 0
  
  name             = "elasticsearch"
  repository       = "https://helm.elastic.co"
  chart            = "elasticsearch"
  namespace        = "logging"
  create_namespace = true
  version          = "8.5.1"
  
  set {
    name  = "replicas"
    value = var.environment == "production" ? "3" : "1"
  }
  
  set {
    name  = "minimumMasterNodes"
    value = var.environment == "production" ? "2" : "1"
  }
  
  set {
    name  = "resources.requests.cpu"
    value = "1000m"
  }
  
  set {
    name  = "resources.requests.memory"
    value = "2Gi"
  }
  
  set {
    name  = "resources.limits.cpu"
    value = "2000m"
  }
  
  set {
    name  = "resources.limits.memory"
    value = "4Gi"
  }
  
  set {
    name  = "volumeClaimTemplate.resources.requests.storage"
    value = "100Gi"
  }
  
  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}

resource "helm_release" "kibana" {
  count = var.enable_logging ? 1 : 0
  
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  namespace  = "logging"
  version    = "8.5.1"
  
  set {
    name  = "elasticsearchHosts"
    value = "http://elasticsearch-master:9200"
  }
  
  # Ingress for Kibana
  set {
    name  = "ingress.enabled"
    value = "true"
  }
  
  set {
    name  = "ingress.className"
    value = "alb"
  }
  
  set {
    name  = "ingress.annotations.kubernetes\\.io/ingress\\.class"
    value = "alb"
  }
  
  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }
  
  set {
    name  = "ingress.hosts[0].host"
    value = "kibana-${var.environment}.${var.domain_name}"
  }
  
  depends_on = [
    helm_release.elasticsearch,
    helm_release.aws_load_balancer_controller,
  ]
}

resource "helm_release" "filebeat" {
  count = var.enable_logging ? 1 : 0
  
  name       = "filebeat"
  repository = "https://helm.elastic.co"
  chart      = "filebeat"
  namespace  = "logging"
  version    = "8.5.1"
  
  set {
    name  = "daemonset.enabled"
    value = "true"
  }
  
  set {
    name  = "filebeatConfig.filebeat\\.yml"
    value = <<-EOF
      filebeat.inputs:
      - type: container
        paths:
          - /var/log/containers/*.log
        processors:
        - add_kubernetes_metadata:
            host: $${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"
      
      output.elasticsearch:
        host: '$${NODE_NAME}'
        hosts: '["elasticsearch-master:9200"]'
      
      setup.kibana:
        host: "kibana-kibana:5601"
    EOF
  }
  
  depends_on = [
    helm_release.elasticsearch,
  ]
}

# Velero for Backup (if enabled)
resource "helm_release" "velero" {
  count = var.enable_velero ? 1 : 0
  
  name             = "velero"
  repository       = "https://vmware-tanzu.github.io/helm-charts"
  chart            = "velero"
  namespace        = "velero"
  create_namespace = true
  version          = "5.1.4"
  
  set {
    name  = "initContainers[0].name"
    value = "velero-plugin-for-aws"
  }
  
  set {
    name  = "initContainers[0].image"
    value = "velero/velero-plugin-for-aws:v1.8.0"
  }
  
  set {
    name  = "initContainers[0].volumeMounts[0].mountPath"
    value = "/target"
  }
  
  set {
    name  = "initContainers[0].volumeMounts[0].name"
    value = "plugins"
  }
  
  depends_on = [
    module.eks.eks_managed_node_groups,
  ]
}