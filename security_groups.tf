# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------
# This file defines security groups for the ALB and ECS tasks.
# The ALB security group controls inbound traffic from the internet.
# The ECS tasks security group only allows traffic from the ALB.
# -----------------------------------------------------------------------------

# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ${var.project_name} Application Load Balancer"
  vpc_id      = local.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alb-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ALB ingress rule for HTTP
resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.alb_ingress_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from allowed CIDR blocks"
}

# ALB ingress rule for HTTPS (only if HTTPS is enabled)
resource "aws_security_group_rule" "alb_https_ingress" {
  count = var.enable_https ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.alb_ingress_cidr_blocks
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from allowed CIDR blocks"
}

# ALB egress rule - allow all outbound traffic
resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Security group for ${var.project_name} ECS tasks"
  vpc_id      = local.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ecs-tasks-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ECS tasks ingress rule - only allow traffic from ALB
resource "aws_security_group_rule" "ecs_tasks_ingress" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.ecs_tasks.id
  description              = "Allow traffic from ALB on container port"
}

# ECS tasks egress rule - allow all outbound traffic
resource "aws_security_group_rule" "ecs_tasks_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_tasks.id
  description       = "Allow all outbound traffic"
}
