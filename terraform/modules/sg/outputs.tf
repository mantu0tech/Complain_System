output "jumpserver_sg_id" {
  value = aws_security_group.jumpserver.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "eks_nodes_sg_id" {
  value = aws_security_group.eks_nodes.id
}
