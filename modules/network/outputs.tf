output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs ordered by availability_zones."
  value       = [for az in var.availability_zones : aws_subnet.public[az].id]
}

output "private_app_subnet_ids" {
  description = "Private application subnet IDs ordered by availability_zones."
  value       = [for az in var.availability_zones : aws_subnet.private_app[az].id]
}

output "private_db_subnet_ids" {
  description = "Private database subnet IDs ordered by availability_zones."
  value       = [for az in var.availability_zones : aws_subnet.private_db[az].id]
}

output "db_subnet_group_name" {
  description = "RDS database subnet group name."
  value       = aws_db_subnet_group.this.name
}

