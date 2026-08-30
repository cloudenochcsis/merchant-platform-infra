output "alb_arn" {
  description = "Application Load Balancer ARN."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name."
  value       = aws_lb.this.dns_name
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix used in CloudWatch metric dimensions."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn" {
  description = "Application target group ARN."
  value       = aws_lb_target_group.app.arn
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix used in CloudWatch metric dimensions."
  value       = aws_lb_target_group.app.arn_suffix
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "log_group_name" {
  description = "ECS CloudWatch log group name."
  value       = aws_cloudwatch_log_group.ecs.name
}

output "assign_public_ip" {
  description = "Whether ECS tasks receive public IPs. Exposed for policy tests."
  value       = aws_ecs_service.app.network_configuration[0].assign_public_ip
}

