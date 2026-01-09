# -----------------------------------------------------------------------------
# ECS Resources
# -----------------------------------------------------------------------------
# This file defines the ECS cluster, task definition, and service.
# Uses AWS Fargate for serverless container execution.
# -----------------------------------------------------------------------------

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-logs"
    }
  )
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.cluster_name
    }
  )
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.container_image
      cpu       = var.container_cpu
      memory    = var.container_memory
      essential = true

      # Port mappings include both the container port (for HTTP) and optionally
      # the cluster port (for inter-node communication in multi-member mode)
      portMappings = concat(
        [
          {
            containerPort = var.container_port
            hostPort      = var.container_port
            protocol      = "tcp"
            name          = "http"
          }
        ],
        local.is_multi_member_cluster ? [
          {
            containerPort = var.cluster_port
            hostPort      = var.cluster_port
            protocol      = "tcp"
            name          = "cluster"
          }
        ] : []
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = local.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      environment = local.container_environment

      secrets = length(var.container_secrets) > 0 ? var.container_secrets : null

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-task"
    }
  )
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  # Use cluster_target_size as the desired count when in multi-member mode,
  # otherwise fall back to the user-specified desired_count
  desired_count = local.is_multi_member_cluster ? var.cluster_target_size : var.desired_count
  launch_type   = "FARGATE"

  network_configuration {
    subnets          = local.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  # Service discovery registration for multi-member cluster mode
  # This registers ECS tasks with AWS Cloud Map for DNS-based discovery
  dynamic "service_registries" {
    for_each = local.is_multi_member_cluster ? [1] : []
    content {
      registry_arn   = aws_service_discovery_service.seed[0].arn
      container_name = var.container_name
      container_port = var.cluster_port
    }
  }

  # Ensure the ALB listener is created before the service
  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy
  ]

  # Enable deployment circuit breaker for safer deployments
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Deployment configuration
  # For multi-member clusters, we need to be more careful with rolling updates
  # to maintain cluster quorum during deployments
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = local.is_multi_member_cluster ? 66 : 100

  # Propagate tags to tasks
  propagate_tags = "SERVICE"

  tags = merge(
    local.common_tags,
    {
      Name = local.service_name
    }
  )

  lifecycle {
    ignore_changes = [
      # Allow external changes to desired_count for auto-scaling
      desired_count
    ]
  }
}
