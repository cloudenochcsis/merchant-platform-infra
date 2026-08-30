output "alarm_names" {
  description = "Names of the CloudWatch alarms."
  value = [
    aws_cloudwatch_metric_alarm.unhealthy_targets.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_memory.alarm_name,
    aws_cloudwatch_metric_alarm.rds_free_storage.alarm_name
  ]
}

