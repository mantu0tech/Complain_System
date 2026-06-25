# ── Fill these in before running terraform apply ──────────────────────────────
# Copy this file: cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars is in .gitignore — never commit it (contains db_password)

# General
project_name = "municipal"
environment  = "dev"
aws_region   = "ap-south-1"

# Your SSH public key (run: cat ~/.ssh/id_rsa.pub)
# create_key_pair = true 
# ssh_public_key  = "ssh-rsa AAAA... your-public-key-here"

# Or use an existing key pair instead:
existing_key_name = "ops"

# Your admin IAM role (gets cluster-admin on EKS)
admin_role_arns = {
  admin = "arn:aws:iam::051826716700:role/admin_role"
}

# Narrow SSH access to your IP in production
# ssh_allowed_cidrs = ["YOUR.IP.ADDRESS/32"]
ssh_allowed_cidrs = ["0.0.0.0/0"] # OK for dev/learning

# Database
db_name     = "complaints_db"
db_username = "postgres"
db_password = "Chula123!" # use a strong password, keep this out of git

# EKS node group (t3.medium is cheaper than m7i-flex for dev/learning)
eks_node_groups = {
  default = {
    desired_size   = 2
    min_size       = 1
    max_size       = 3
    instance_types = ["t3.medium"]
    disk_size      = 20
    labels         = {}
  }
}

# RDS (db.t3.micro is free-tier eligible)
rds_instance_class      = "db.t3.micro"
rds_publicly_accessible = true  # set false in prod (use jump server to connect)
rds_multi_az            = false # set true in prod
rds_deletion_protection = false # set true in prod

# ── Production overrides (uncomment for prod) ─────────────────────────────────
# environment             = "prod"
# enable_nat_gateway      = true        # pods in private subnets need this
# rds_instance_class      = "db.t3.small"
# rds_publicly_accessible = false
# rds_multi_az            = true
# rds_deletion_protection = true
# rds_backup_retention_days = 30
# ssh_allowed_cidrs       = ["YOUR.OFFICE.IP/32"]
# eks_node_groups = {
#   default = {
#     desired_size   = 3
#     min_size       = 2
#     max_size       = 6
#     instance_types = ["m7i-flex.large"]
#     disk_size      = 50
#     labels         = { role = "app" }
#   }
# }
