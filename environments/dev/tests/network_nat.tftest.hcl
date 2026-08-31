mock_provider "aws" {
  override_during = plan
}

variables {
  project                  = "axis"
  environment              = "dev"
  vpc_cidr                 = "10.20.0.0/16"
  internet_ipv4_cidr       = "0.0.0.0/0"
  availability_zones       = ["eu-west-1a", "eu-west-1b"]
  public_subnet_cidrs      = ["10.20.0.0/24", "10.20.1.0/24"]
  private_app_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]
  private_db_subnet_cidrs  = ["10.20.20.0/24", "10.20.21.0/24"]
  common_tags = {
    Project     = "axis"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

run "shared_nat_gateway" {
  command = apply

  module {
    source = "../../modules/network"
  }

  variables {
    nat_gateway_per_az = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Shared NAT mode must create exactly one NAT Gateway."
  }

  assert {
    condition = alltrue([
      for route_table in aws_route_table.private_app :
      one(route_table.route).nat_gateway_id == aws_nat_gateway.this["shared"].id
    ])
    error_message = "Shared NAT mode must route every private application subnet through the shared NAT Gateway."
  }
}

run "nat_gateway_per_az" {
  command = apply

  module {
    source = "../../modules/network"
  }

  variables {
    nat_gateway_per_az = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Per-AZ NAT mode must create one NAT Gateway per Availability Zone."
  }

  assert {
    condition = alltrue([
      for az, route_table in aws_route_table.private_app :
      one(route_table.route).nat_gateway_id == aws_nat_gateway.this[az].id
    ])
    error_message = "Per-AZ NAT mode must route each private application subnet through its local NAT Gateway."
  }
}
