locals {
  name = "${var.project}-${var.environment}"

  public_subnets = {
    for index, az in var.availability_zones : az => {
      cidr  = var.public_subnet_cidrs[index]
      index = index + 1
    }
  }

  private_app_subnets = {
    for index, az in var.availability_zones : az => {
      cidr  = var.private_app_subnet_cidrs[index]
      index = index + 1
    }
  }

  private_db_subnets = {
    for index, az in var.availability_zones : az => {
      cidr  = var.private_db_subnet_cidrs[index]
      index = index + 1
    }
  }

  tags = merge(var.common_tags, { Component = "Network" })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${local.name}-igw" })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${local.name}-public-${each.value.index}"
    Tier = "Public"
  })
}

resource "aws_subnet" "private_app" {
  for_each = local.private_app_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${local.name}-app-${each.value.index}"
    Tier = "PrivateApplication"
  })
}

resource "aws_subnet" "private_db" {
  for_each = local.private_db_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "${local.name}-db-${each.value.index}"
    Tier = "PrivateDatabase"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = var.internet_ipv4_cidr
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.this]

  tags = merge(local.tags, { Name = "${local.name}-nat-eip" })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[var.availability_zones[0]].id

  depends_on = [aws_internet_gateway.this]

  tags = merge(local.tags, { Name = "${local.name}-nat" })
}

resource "aws_route_table" "private_app" {
  for_each = aws_subnet.private_app

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = var.internet_ipv4_cidr
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = merge(local.tags, { Name = "${local.name}-app-${local.private_app_subnets[each.key].index}-rt" })
}

resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

resource "aws_route_table" "private_db" {
  for_each = aws_subnet.private_db

  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${local.name}-db-${local.private_db_subnets[each.key].index}-rt" })
}

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db[each.key].id
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db"
  subnet_ids = [for az in var.availability_zones : aws_subnet.private_db[az].id]

  tags = merge(local.tags, { Name = "${local.name}-db" })
}
