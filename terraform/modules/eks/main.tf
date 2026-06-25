module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Public endpoint so kubectl works from jump server and local machine
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Gives the Terraform caller admin on the cluster automatically
  enable_cluster_creator_admin_permissions = true

  # Additional IAM principals with cluster admin (e.g. your admin role)
  access_entries = {
    for k, v in var.admin_role_arns : k => {
      principal_arn = v
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  eks_managed_node_groups = {
    for name, cfg in var.node_groups : name => {
      desired_size   = cfg.desired_size
      min_size       = cfg.min_size
      max_size       = cfg.max_size
      instance_types = cfg.instance_types
      disk_size      = cfg.disk_size

      # Standard policies every node needs
      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonS3FullAccess                 = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
        AmazonSNSFullAccess                = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
      }

      labels = merge(cfg.labels, {
        "project" = var.project_name
      })

      tags = var.tags
    }
  }

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}
