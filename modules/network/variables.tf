variable "project" {
  description = "Project name used in resource names."
  type        = string
}

variable "environment" {
  description = "Environment name used in resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "internet_ipv4_cidr" {
  description = "IPv4 CIDR used for public and NAT default routes."
  type        = string
}

variable "availability_zones" {
  description = "Two Availability Zones for the subnet tiers."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs ordered to match availability_zones."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "Private application subnet CIDRs ordered to match availability_zones."
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "Private database subnet CIDRs ordered to match availability_zones."
  type        = list(string)
}

variable "nat_gateway_per_az" {
  description = "Whether to create one NAT Gateway per Availability Zone instead of one shared gateway."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags shared by all resources."
  type        = map(string)
}
