output "public_ip" {
  description = "Public IP of the jump server (Elastic IP if enabled, otherwise ephemeral)"
  value       = var.enable_eip ? aws_eip.jumpserver[0].public_ip : aws_instance.jumpserver.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.jumpserver.id
}

output "ssh_command" {
  description = "SSH command to connect to the jump server"
  value       = "ssh -i ~/.ssh/${var.project_name}-key.pem ubuntu@${var.enable_eip ? aws_eip.jumpserver[0].public_ip : aws_instance.jumpserver.public_ip}"
}

output "iam_role_arn" {
  description = "IAM role ARN attached to the jump server"
  value       = aws_iam_role.jumpserver.arn
}
