# ── DB Subnet Group ───────────────────────────────────────────────────────────
# RDS needs a subnet group. We use public subnets so you can connect directly
# from local machine during dev. In production, switch to private_subnet_ids.
resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group for ${var.project_name} RDS"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.project_name}-db-subnet-group" })
}

# ── Parameter Group (tuning) ──────────────────────────────────────────────────
resource "aws_db_parameter_group" "this" {
  name        = "${var.project_name}-postgres-params"
  family      = "postgres${var.postgres_major_version}"
  description = "Custom parameters for ${var.project_name}"

  # parameter {
  #   name  = "log_connections"
  #   value = "all"
  # }

  # parameter {
  #   name  = "log_disconnections"
  #   value = "all"
  # }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # log queries taking > 1s
  }

  tags = merge(var.tags, { Name = "${var.project_name}-postgres-params" })
}

# ── RDS PostgreSQL Instance ───────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-postgres"

  # Engine
  engine         = "postgres"
  engine_version = var.postgres_engine_version
  instance_class = var.instance_class

  # Storage
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # enables autoscaling
  storage_type          = "gp3"
  storage_encrypted     = true

  # Credentials
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = var.publicly_accessible  # true for dev, false for prod

  # Parameter group
  parameter_group_name = aws_db_parameter_group.this.name

  # Availability
  multi_az = var.multi_az  # true for prod HA, false for dev/cost saving

  # Deletion protection — always true in prod
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.project_name}-final-snapshot" : null

  # Performance Insights (free tier for 7 days)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-postgres"
    Role = "database"
  })
}
