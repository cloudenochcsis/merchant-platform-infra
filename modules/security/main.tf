locals {
  name = "${var.project}-${var.environment}"
  tags = merge(var.common_tags, { Component = "Security" })
}

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Controls internet and application traffic for the ALB"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-alb-sg" })
}

resource "aws_security_group" "app" {
  name        = "${local.name}-app"
  description = "Controls ALB, database, and AWS API traffic for ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-app-sg" })
}

resource "aws_security_group" "database" {
  name        = "${local.name}-database"
  description = "Allows PostgreSQL connections only from ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${local.name}-database-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Internet HTTP for redirect to HTTPS"
  cidr_ipv4         = var.internet_ipv4_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Internet HTTPS"
  cidr_ipv4         = var.internet_ipv4_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to application containers"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Application traffic from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "app_to_database" {
  security_group_id            = aws_security_group.app.id
  description                  = "Application to PostgreSQL"
  referenced_security_group_id = aws_security_group.database.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to image registries and AWS APIs through NAT"
  cidr_ipv4         = var.internet_ipv4_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "database_from_app" {
  security_group_id            = aws_security_group.database.id
  description                  = "PostgreSQL from application tasks"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"

  tags = local.tags
}
