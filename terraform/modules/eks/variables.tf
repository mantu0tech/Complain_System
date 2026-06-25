variable "project_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets for the EKS cluster and node groups"
  type        = list(string)
}

variable "admin_role_arns" {
  description = "Map of name => IAM role ARN to give cluster-admin access"
  type        = map(string)
  default     = {}
  # Example: { admin = "arn:aws:iam::123456789:role/my-admin-role" }
}

variable "node_groups" {
  description = "Map of node group configs"
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
      instance_types = ["t3.medium"]
      disk_size      = 20
      labels         = {}
    }
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
