variable "project" {
  description = "Project name used in alarm names."
  type        = string
}

variable "environment" {
  description = "Environment name used in alarm names."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch dimensions."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for CloudWatch dimensions."
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for CloudWatch dimensions."
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name for CloudWatch dimensions."
  type        = string
}

variable "rds_instance_identifier" {
  description = "RDS instance identifier for CloudWatch dimensions."
  type        = string
}

variable "ecs_cpu_threshold" {
  description = "ECS average CPU percentage alarm threshold."
  type        = number
}

variable "ecs_memory_threshold" {
  description = "ECS average memory percentage alarm threshold."
  type        = number
}

variable "rds_free_storage_threshold_bytes" {
  description = "RDS free storage alarm threshold in bytes."
  type        = number
}

variable "alarm_actions" {
  description = "Action ARNs invoked when alarms enter ALARM."
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Action ARNs invoked when alarms return to OK."
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Tags shared by all resources."
  type        = map(string)
}

