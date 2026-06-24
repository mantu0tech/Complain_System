module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "municipal-vpc"
  cidr = "10.0.0.0/16"

  azs                     = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  public_subnets          = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  map_public_ip_on_launch = true

  enable_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true


  # Required tags for EKS to find subnets + create LoadBalancers
  public_subnet_tags = {
    "kubernetes.io/cluster/municipal" = "shared"
    "kubernetes.io/role/elb"             = "1"
  }

  tags = { Project = "municipal  " }
}
