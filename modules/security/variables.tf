variable "project" {
  description = "Project name used in resource names."
  type        = string
}

variable "environment" {
  description = "Environment name used in resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID in which to create security groups."
  type        = string
}

variable "container_port" {
  description = "TCP port exposed by the application container."
  type        = number
}

variable "internet_ipv4_cidr" {
  description = "IPv4 CIDR allowed to reach the public ALB and used for HTTPS egress."
  type        = string
}

variable "common_tags" {
  description = "Tags shared by all resources."
  type        = map(string)
}
