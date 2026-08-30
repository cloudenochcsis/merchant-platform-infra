locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "network" {
  source = "../../modules/network"

  project                  = var.project
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  internet_ipv4_cidr       = var.internet_ipv4_cidr
  availability_zones       = var.availability_zones
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  common_tags              = local.common_tags
}

module "security" {
  source = "../../modules/security"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.network.vpc_id
  container_port     = var.container_port
  internet_ipv4_cidr = var.internet_ipv4_cidr
  common_tags        = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  project                    = var.project
  environment                = var.environment
  db_subnet_group_name       = module.network.db_subnet_group_name
  database_security_group_id = module.security.database_security_group_id
  db_name                    = var.db_name
  db_username                = var.db_username
  engine_version             = var.db_engine_version
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  max_allocated_storage      = var.db_max_allocated_storage
  backup_retention_days      = var.db_backup_retention_days
  backup_window              = var.db_backup_window
  maintenance_window         = var.db_maintenance_window
  multi_az                   = var.db_multi_az
  deletion_protection        = var.db_deletion_protection
  skip_final_snapshot        = var.db_skip_final_snapshot
  common_tags                = local.common_tags
}

module "ecs" {
  source = "../../modules/ecs"

  project                = var.project
  environment            = var.environment
  aws_region             = var.aws_region
  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_app_subnet_ids = module.network.private_app_subnet_ids
  alb_security_group_id  = module.security.alb_security_group_id
  app_security_group_id  = module.security.app_security_group_id
  certificate_arn        = var.certificate_arn
  container_image        = var.container_image
  container_port         = var.container_port
  desired_count          = var.desired_count
  cpu                    = var.ecs_cpu
  memory                 = var.ecs_memory
  health_check_path      = var.health_check_path
  log_retention_days     = var.log_retention_days
  database_address       = module.rds.db_address
  database_port          = module.rds.db_port
  database_name          = module.rds.db_name
  database_secret_arn    = module.rds.secret_arn
  common_tags            = local.common_tags
}

module "observability" {
  source = "../../modules/observability"

  project                          = var.project
  environment                      = var.environment
  alb_arn_suffix                   = module.ecs.alb_arn_suffix
  target_group_arn_suffix          = module.ecs.target_group_arn_suffix
  ecs_cluster_name                 = module.ecs.cluster_name
  ecs_service_name                 = module.ecs.service_name
  rds_instance_identifier          = module.rds.db_instance_identifier
  ecs_cpu_threshold                = var.ecs_cpu_alarm_threshold
  ecs_memory_threshold             = var.ecs_memory_alarm_threshold
  rds_free_storage_threshold_bytes = var.rds_free_storage_alarm_bytes
  alarm_actions                    = var.alarm_actions
  ok_actions                       = var.ok_actions
  common_tags                      = local.common_tags
}
