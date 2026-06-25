# ── General ───────────────────────────────────────────────────────────────────
variable "project_name" {
  description = "Short project identifier, used as a prefix on all resource names"
  type        = string
  default     = "municipal"
}

variable "environment" {
  description = "Deployment environment: dev | staging | prod"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

# ── VPC ───────────────────────────────────────────────────────────────────────
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "enable_nat_gateway" {
  type    = bool
  default = false # set true if your pods need outbound internet from private subnets
}

# ── Security ──────────────────────────────────────────────────────────────────
variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH to the jump server. Narrow this to your IP in prod."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── EKS ───────────────────────────────────────────────────────────────────────
variable "eks_cluster_version" {
  type    = string
  default = "1.31"
}

variable "admin_role_arns" {
  description = "Map of IAM role ARNs to grant cluster-admin. Key = friendly name."
  type        = map(string)
  default     = {}
  # Example:
  # { admin = "arn:aws:iam::519120506792:role/adminroleforproject" }
}

variable "eks_node_groups" {
  description = "EKS managed node group configurations"
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    disk_size      = number
    labels         = map(string)
  }))
  default = {
    default = {
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      instance_types = ["t3.medium"] # cheaper than m7i-flex for dev
      disk_size      = 20
      labels         = {}
    }
  }
}

# ── RDS ───────────────────────────────────────────────────────────────────────
variable "db_name" {
  type    = string
  default = "complaints_db"
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "db_password" {
  description = "RDS master password. Pass via TF_VAR_db_password env var or tfvars (never commit)."
  type        = string
  sensitive   = true
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro" # free tier eligible
}

variable "rds_publicly_accessible" {
  description = "Allow direct connections from outside VPC (dev convenience)"
  type        = bool
  default     = true
}

variable "rds_multi_az" {
  type    = bool
  default = false # set true for prod
}

variable "rds_deletion_protection" {
  type    = bool
  default = false # set true for prod
}

variable "rds_backup_retention_days" {
  type    = number
  default = 7
}

# ── Jump Server ───────────────────────────────────────────────────────────────
variable "jumpserver_instance_type" {
  type    = string
  default = "t3.small"
}




variable "existing_key_name" {
  description = "Name of an existing EC2 key pair (when create_key_pair = false)"
  type        = string
  default     = ""
}
