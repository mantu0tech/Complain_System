variable "project_name" {
  type = string
}

variable "subnet_ids" {
  description = "Subnets for the DB subnet group. Use public subnets for dev access, private for prod."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group that controls access to RDS"
  type        = string
}

variable "db_name" {
  description = "Name of the initial database to create"
  type        = string
  default     = "complaints_db"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Master password for the database (use a strong password in prod)"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class. db.t3.micro = free tier eligible."
  type        = string
  default     = "db.t3.micro"
}

variable "postgres_engine_version" {
  description = "Full PostgreSQL engine version"
  type        = string
  default     = "18.3"
}

variable "postgres_major_version" {
  description = "Major version (for parameter group family, e.g. '15')"
  type        = string
  default     = "18"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling (0 = disabled)"
  type        = number
  default     = 100
}

variable "publicly_accessible" {
  description = "Allow connections from outside the VPC. true for dev, false for prod."
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Enable Multi-AZ standby (doubles cost, adds HA)"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Days to retain automated backups (0 = disabled)"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Prevent accidental deletion. Set false only in dev."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
