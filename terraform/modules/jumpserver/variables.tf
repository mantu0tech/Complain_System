variable "project_name" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet to place the jump server in"
  type        = string
}

variable "security_group_id" {
  description = "SG to attach to the jump server"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name (for kubeconfig bootstrap)"
  type        = string
}

variable "aws_region" {
  description = "AWS region (for kubeconfig bootstrap)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for jump server"
  type        = string
  default     = "m7i-flex.large"
}


variable "existing_key_name" {
  description = "Name of an existing EC2 key pair (used when create_key_pair = false)"
  type        = string
  default     = "ops"
}

variable "enable_eip" {
  description = "Attach an Elastic IP so the public IP stays the same after stop/start"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
