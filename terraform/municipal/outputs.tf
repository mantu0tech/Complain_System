# ── Jump Server ───────────────────────────────────────────────────────────────
output "jump_server_ip" {
  description = "Public IP of the jump server"
  value       = module.jumpserver.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to jump server"
  value       = module.jumpserver.ssh_command
}

# ── EKS ───────────────────────────────────────────────────────────────────────
output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Run this to configure kubectl (on jump server or locally)"
  value       = module.eks.kubeconfig_cmd
}

# ── RDS ───────────────────────────────────────────────────────────────────────
output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = module.rds.endpoint
}

output "rds_host" {
  description = "RDS hostname (use in DATABASE_URL)"
  value       = module.rds.host
}

output "database_url" {
  description = "Full DATABASE_URL — use this in your .env or Kubernetes secret"
  value       = module.rds.database_url
  sensitive   = true # run: terraform output database_url
}

# ── VPC ───────────────────────────────────────────────────────────────────────
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

# ── Summary block ─────────────────────────────────────────────────────────────

