locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.common_tags, { Component = "Observability" })
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${local.name}-alb-unhealthy-targets"
  alarm_description   = "ALB has unhealthy application targets"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  period              = 60
  statistic           = "Maximum"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  tags = merge(local.tags, { Name = "${local.name}-alb-unhealthy-targets" })
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "${local.name}-ecs-high-cpu"
  alarm_description   = "ECS service average CPU is high"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.ecs_cpu_threshold
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  period              = 300
  statistic           = "Average"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  tags = merge(local.tags, { Name = "${local.name}-ecs-high-cpu" })
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  alarm_name          = "${local.name}-ecs-high-memory"
  alarm_description   = "ECS service average memory is high"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.ecs_memory_threshold
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  period              = 300
  statistic           = "Average"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  tags = merge(local.tags, { Name = "${local.name}-ecs-high-memory" })
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${local.name}-rds-low-free-storage"
  alarm_description   = "RDS free storage is low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  comparison_operator = "LessThanThreshold"
  threshold           = var.rds_free_storage_threshold_bytes
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  period              = 300
  statistic           = "Average"
  treat_missing_data  = "missing"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_identifier
  }

  tags = merge(local.tags, { Name = "${local.name}-rds-low-free-storage" })
}

