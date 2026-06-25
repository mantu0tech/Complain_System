output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "node_iam_role_arn" {
  value = module.eks.eks_managed_node_groups["default"].iam_role_arn
}

output "kubeconfig_cmd" {
  description = "Run this to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.tags["Region"] != null ? var.tags["Region"] : "ap-south-1"}"
}
