terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to store state in S3 (recommended for teams)
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "municipal/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Region      = var.aws_region
  }
}

# ── 1. VPC ────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "../modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = true
  cluster_name         = local.cluster_name
  tags                 = local.common_tags
}

# ── 2. Security Groups ────────────────────────────────────────────────────────
module "sg" {
  source = "../modules/sg"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  tags              = local.common_tags
}

# ── 3. EKS Cluster ───────────────────────────────────────────────────────────
module "eks" {
  source = "../modules/eks"

  project_name    = var.project_name
  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids # use private_subnet_ids in prod
  admin_role_arns = var.admin_role_arns
  node_groups     = var.eks_node_groups
  tags            = local.common_tags
}

# ── 4. RDS PostgreSQL ─────────────────────────────────────────────────────────
module "rds" {
  source = "../modules/rds"

  project_name      = var.project_name
  subnet_ids        = module.vpc.public_subnet_ids # use private_subnet_ids in prod
  security_group_id = module.sg.rds_sg_id

  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  instance_class        = var.rds_instance_class
  publicly_accessible   = var.rds_publicly_accessible
  multi_az              = var.rds_multi_az
  deletion_protection   = var.rds_deletion_protection
  backup_retention_days = var.rds_backup_retention_days
  tags                  = local.common_tags
}

# ── 5. Jump Server ────────────────────────────────────────────────────────────
module "jumpserver" {
  source = "../modules/jumpserver"

  project_name      = var.project_name
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.sg.jumpserver_sg_id
  cluster_name      = local.cluster_name
  aws_region        = var.aws_region
  instance_type     = var.jumpserver_instance_type
  existing_key_name = var.existing_key_name
  enable_eip        = true
  tags              = local.common_tags
}

locals {
  cluster_name = "${var.project_name}-${var.environment}"
}
