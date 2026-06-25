variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH into jump server. Use your office/home IP, not 0.0.0.0/0 in prod."
  type        = list(string)
  default     = ["0.0.0.0/0"] # narrow this down in production
}

variable "tags" {
  type    = map(string)
  default = {}
}
