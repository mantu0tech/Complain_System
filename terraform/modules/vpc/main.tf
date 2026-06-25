module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  map_public_ip_on_launch = true

  # NAT gateway for private subnets (disable to save cost in dev)
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway  # true = cheaper (1 NAT vs 1-per-AZ)
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS requires these tags on subnets so it can create LoadBalancers
  public_subnet_tags = merge(var.extra_public_subnet_tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })

  private_subnet_tags = merge(var.extra_private_subnet_tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })

  tags = merge(var.tags, {
    Name    = "${var.project_name}-vpc"
    Module  = "vpc"
  })
}
