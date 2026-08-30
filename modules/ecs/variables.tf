variable "project" {
  description = "Project name used in resource names."
  type        = string
}

variable "environment" {
  description = "Environment name used in resource names."
  type        = string
}

variable "aws_region" {
  description = "AWS Region used by the CloudWatch Logs driver."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ALB target group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB."
  type        = list(string)
}

variable "private_app_subnet_ids" {
  description = "Private application subnet IDs for Fargate tasks."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID."
  type        = string
}

variable "app_security_group_id" {
  description = "ECS application security group ID."
  type        = string
}

variable "certificate_arn" {
  description = "Existing ACM certificate ARN for the HTTPS listener."
  type        = string
}

variable "container_image" {
  description = "Container image reference with explicit tag or digest."
  type        = string
}

variable "container_port" {
  description = "TCP port exposed by the application container."
  type        = number
}

variable "desired_count" {
  description = "Desired ECS task count."
  type        = number
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
}

variable "health_check_path" {
  description = "Target group health check path."
  type        = string
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS ignores failing load balancer health checks after task start."
  type        = number
  default     = 60
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
}

variable "database_address" {
  description = "RDS hostname supplied to the application."
  type        = string
}

variable "database_port" {
  description = "RDS listener port supplied to the application."
  type        = number
}

variable "database_name" {
  description = "PostgreSQL database name supplied to the application."
  type        = string
}

variable "database_secret_arn" {
  description = "Secrets Manager ARN containing database username and password JSON keys."
  type        = string
}

variable "common_tags" {
  description = "Tags shared by all resources."
  type        = map(string)
}

