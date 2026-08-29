output "db_instance_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.this.identifier
}

output "db_address" {
  description = "RDS hostname."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "RDS listener port."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial PostgreSQL database name."
  value       = aws_db_instance.this.db_name
}

output "secret_arn" {
  description = "ARN of the Secrets Manager database credential secret."
  value       = aws_secretsmanager_secret.database.arn

  depends_on = [aws_secretsmanager_secret_version.database]
}

output "secret_name" {
  description = "Name of the Secrets Manager database credential secret."
  value       = aws_secretsmanager_secret.database.name
}

output "publicly_accessible" {
  description = "Whether the database is publicly accessible. Exposed for policy tests."
  value       = aws_db_instance.this.publicly_accessible
}

output "storage_encrypted" {
  description = "Whether RDS storage encryption is enabled. Exposed for policy tests."
  value       = aws_db_instance.this.storage_encrypted
}

