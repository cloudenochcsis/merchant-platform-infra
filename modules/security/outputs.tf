output "alb_security_group_id" {
  description = "ALB security group ID."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ECS application security group ID."
  value       = aws_security_group.app.id
}

output "database_security_group_id" {
  description = "RDS security group ID."
  value       = aws_security_group.database.id
}

