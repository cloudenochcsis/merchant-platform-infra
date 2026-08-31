mock_provider "aws" {
  override_during = plan
}

mock_provider "random" {
  override_during = plan
}

variables {
  aws_region               = "eu-west-1"
  project                  = "axis"
  environment              = "dev"
  availability_zones       = ["eu-west-1a", "eu-west-1b"]
  vpc_cidr                 = "10.20.0.0/16"
  public_subnet_cidrs      = ["10.20.0.0/24", "10.20.1.0/24"]
  private_app_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
  private_db_subnet_cidrs  = ["10.20.20.0/24", "10.20.21.0/24"]
  container_image          = "registry.example.test/application:1.0.0"
  certificate_arn          = "arn:aws:acm:eu-west-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
}

run "secure_baseline" {
  command = plan

  assert {
    condition     = length(module.network.public_subnet_ids) == 2 && length(module.network.private_app_subnet_ids) == 2 && length(module.network.private_db_subnet_ids) == 2
    error_message = "The network must span two subnets in each tier."
  }

  assert {
    condition     = module.rds.publicly_accessible == false && module.rds.storage_encrypted == true
    error_message = "RDS must be private and encrypted."
  }

  assert {
    condition     = module.ecs.assign_public_ip == false
    error_message = "ECS tasks must not receive public IP addresses."
  }

  assert {
    condition     = length(module.observability.alarm_names) == 4
    error_message = "The baseline must create four CloudWatch alarms."
  }
}
