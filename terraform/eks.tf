module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "municipal"
  cluster_version = "1.35"

  # Use default VPC (simplest for demo)
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Enable public access (for testing)
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    admin = {
      principal_arn = "arn:aws:iam::519120506792:role/adminroleforproject" //add your admin role here

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Node group config
  eks_managed_node_groups = {
    default = {
      desired_size = 2
      max_size     = 3
      min_size     = 1

      instance_types = ["m7i-flex.large"]
      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }
    }
    # ADDED: nodes need this to pull images and join cluster
  }
  tags = { Project = "municipal  " }
}

output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "kubeconfig_cmd" {
  value = "aws eks update-kubeconfig --name municipal --region ap-south-1"
}