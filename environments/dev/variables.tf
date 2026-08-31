variable "aws_region" {
  description = "AWS Region in which to create the environment."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS Region name."
  }
}

variable "project" {
  description = "Short project name used in resource names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,19}$", var.project))
    error_message = "project must be 2-20 lowercase letters, numbers, or hyphens and start with a letter."
  }
}

variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "availability_zones" {
  description = "Exactly two Availability Zones used by all subnet tiers."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2 && length(distinct(var.availability_zones)) == 2
    error_message = "availability_zones must contain exactly two distinct zones."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "internet_ipv4_cidr" {
  description = "IPv4 CIDR representing internet routes and public ALB ingress."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrnetmask(var.internet_ipv4_cidr))
    error_message = "internet_ipv4_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "Two CIDR blocks for public ALB and NAT subnets."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "public_subnet_cidrs must contain exactly two valid IPv4 CIDR blocks."
  }
}

variable "private_app_subnet_cidrs" {
  description = "Two CIDR blocks for private ECS application subnets."
  type        = list(string)

  validation {
    condition     = length(var.private_app_subnet_cidrs) == 2 && alltrue([for cidr in var.private_app_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "private_app_subnet_cidrs must contain exactly two valid IPv4 CIDR blocks."
  }
}

variable "private_db_subnet_cidrs" {
  description = "Two CIDR blocks for isolated RDS subnets."
  type        = list(string)

  validation {
    condition     = length(var.private_db_subnet_cidrs) == 2 && alltrue([for cidr in var.private_db_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "private_db_subnet_cidrs must contain exactly two valid IPv4 CIDR blocks."
  }
}

variable "nat_gateway_per_az" {
  description = "Whether to create one NAT Gateway per Availability Zone instead of one shared gateway."
  type        = bool
  default     = false
}

variable "container_image" {
  description = "Immutable container image reference, including an explicit tag or digest."
  type        = string

  validation {
    condition     = can(regex("(@sha256:[a-f0-9]{64}|:[A-Za-z0-9._-]+)$", var.container_image)) && !endswith(var.container_image, ":latest")
    error_message = "container_image must include an explicit non-latest tag or SHA-256 digest."
  }
}

variable "container_port" {
  description = "TCP port exposed by the application container."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1024 && var.container_port <= 65535
    error_message = "container_port must be between 1024 and 65535."
  }
}

variable "desired_count" {
  description = "Desired number of ECS tasks."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 1
    error_message = "desired_count must be at least 1."
  }
}

variable "ecs_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.ecs_cpu)
    error_message = "ecs_cpu must be a supported Fargate CPU value."
  }
}

variable "ecs_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512

  validation {
    condition = (
      (var.ecs_cpu == 256 && contains([512, 1024, 2048], var.ecs_memory)) ||
      (var.ecs_cpu == 512 && contains([1024, 2048, 3072, 4096], var.ecs_memory)) ||
      (var.ecs_cpu == 1024 && contains(range(2048, 8193, 1024), var.ecs_memory)) ||
      (var.ecs_cpu == 2048 && contains(range(4096, 16385, 1024), var.ecs_memory)) ||
      (var.ecs_cpu == 4096 && contains(range(8192, 30721, 1024), var.ecs_memory))
    )
    error_message = "ecs_memory must be supported for the selected ecs_cpu value."
  }
}

variable "certificate_arn" {
  description = "ARN of an existing ACM certificate in aws_region for the HTTPS listener."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:acm:[^:]+:[0-9]{12}:certificate/[0-9a-f-]+$", var.certificate_arn))
    error_message = "certificate_arn must be an ACM certificate ARN."
  }
}

variable "health_check_path" {
  description = "HTTP path used by the ALB target group health check."
  type        = string
  default     = "/health"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must begin with '/'."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a retention value supported by CloudWatch Logs."
  }
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "app"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must start with a letter and contain at most 63 alphanumeric or underscore characters."
  }
}

variable "db_username" {
  description = "PostgreSQL administrator username stored with the generated password in Secrets Manager."
  type        = string
  default     = "appadmin"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_username))
    error_message = "db_username must start with a letter and contain at most 63 alphanumeric or underscore characters."
  }
}

variable "db_engine_version" {
  description = "PostgreSQL major or minor engine version."
  type        = string
  default     = "17"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "db_allocated_storage must be at least 20 GiB."
  }
}

variable "db_max_allocated_storage" {
  description = "Maximum RDS autoscaled storage in GiB."
  type        = number
  default     = 100

  validation {
    condition     = var.db_max_allocated_storage >= var.db_allocated_storage
    error_message = "db_max_allocated_storage must be at least db_allocated_storage."
  }
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 7

  validation {
    condition     = var.db_backup_retention_days >= 1 && var.db_backup_retention_days <= 35
    error_message = "db_backup_retention_days must be between 1 and 35."
  }
}

variable "db_multi_az" {
  description = "Whether RDS runs in Multi-AZ mode."
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Whether RDS deletion protection is enabled."
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip a final snapshot when destroying RDS."
  type        = bool
  default     = false
}

variable "db_backup_window" {
  description = "Preferred UTC backup window."
  type        = string
  default     = "02:00-03:00"
}

variable "db_maintenance_window" {
  description = "Preferred UTC maintenance window."
  type        = string
  default     = "sun:03:30-sun:04:30"
}

variable "ecs_cpu_alarm_threshold" {
  description = "ECS average CPU percentage that triggers an alarm."
  type        = number
  default     = 80

  validation {
    condition     = var.ecs_cpu_alarm_threshold > 0 && var.ecs_cpu_alarm_threshold <= 100
    error_message = "ecs_cpu_alarm_threshold must be greater than 0 and at most 100."
  }
}

variable "ecs_memory_alarm_threshold" {
  description = "ECS average memory percentage that triggers an alarm."
  type        = number
  default     = 80

  validation {
    condition     = var.ecs_memory_alarm_threshold > 0 && var.ecs_memory_alarm_threshold <= 100
    error_message = "ecs_memory_alarm_threshold must be greater than 0 and at most 100."
  }
}

variable "rds_free_storage_alarm_bytes" {
  description = "RDS free storage bytes below which an alarm triggers."
  type        = number
  default     = 5368709120
}

variable "alarm_actions" {
  description = "Optional SNS topic ARNs or other CloudWatch alarm action ARNs."
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Optional action ARNs invoked when alarms return to OK."
  type        = list(string)
  default     = []
}
