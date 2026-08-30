output "alb_dns_name" {
  description = "DNS name of the public Application Load Balancer."
  value       = module.ecs.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.ecs.service_name
}

output "ecs_log_group_name" {
  description = "CloudWatch log group receiving application logs."
  value       = module.ecs.log_group_name
}

output "database_address" {
  description = "Private RDS endpoint hostname."
  value       = module.rds.db_address
}

output "database_port" {
  description = "Private RDS endpoint port."
  value       = module.rds.db_port
}

output "database_secret_arn" {
  description = "Secrets Manager ARN containing the database credentials."
  value       = module.rds.secret_arn
}

output "cloudwatch_alarm_names" {
  description = "CloudWatch alarm names."
  value       = module.observability.alarm_names
}

