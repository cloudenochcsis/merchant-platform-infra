variable "project" {
  description = "Project name used in resource names."
  type        = string
}

variable "environment" {
  description = "Environment name used in resource names."
  type        = string
}

variable "db_subnet_group_name" {
  description = "Private RDS subnet group name."
  type        = string
}

variable "database_security_group_id" {
  description = "Security group ID allowing PostgreSQL from the application tier."
  type        = string
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
}

variable "db_username" {
  description = "PostgreSQL administrator username."
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Initial database storage in GiB."
  type        = number
}

variable "max_allocated_storage" {
  description = "Maximum autoscaled database storage in GiB."
  type        = number
}

variable "backup_retention_days" {
  description = "Automated backup retention in days."
  type        = number
}

variable "backup_window" {
  description = "Preferred UTC backup window."
  type        = string
}

variable "maintenance_window" {
  description = "Preferred UTC maintenance window."
  type        = string
}

variable "multi_az" {
  description = "Whether the database uses a synchronous standby in another AZ."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Whether RDS deletion protection is enabled."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot during database deletion."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags shared by all resources."
  type        = map(string)
}

