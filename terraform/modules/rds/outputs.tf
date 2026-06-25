output "endpoint" {
  description = "RDS connection endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "host" {
  description = "RDS hostname only (without port)"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "username" {
  description = "Master username"
  value       = aws_db_instance.this.username
}

output "instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.identifier
}

output "database_url" {
  description = "Full DATABASE_URL for use in .env or Kubernetes secret"
  value       = "postgresql://${aws_db_instance.this.username}:${var.db_password}@${aws_db_instance.this.endpoint}/${aws_db_instance.this.db_name}"
  sensitive   = true
}
