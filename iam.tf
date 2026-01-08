# -----------------------------------------------------------------------------
# IAM Roles and Policies
# -----------------------------------------------------------------------------
# This file defines IAM roles for ECS task execution and task runtime.
# - Execution Role: Used by ECS to pull images and write logs
# - Task Role: Used by the container to access AWS services
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# ECS Task Execution Role
# -----------------------------------------------------------------------------
# This role grants ECS the permissions to:
# - Pull container images from ECR
# - Write logs to CloudWatch
# - Retrieve secrets from Secrets Manager or SSM Parameter Store

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ecs-execution-role"
    }
  )
}

# Attach the AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach additional execution role policies if provided
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_additional" {
  for_each = toset(var.additional_execution_role_policy_arns)

  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = each.value
}

# Policy for accessing secrets (only if secrets are configured)
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  count = length(var.container_secrets) > 0 ? 1 : 0

  name = "${var.project_name}-ecs-execution-secrets"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = [for secret in var.container_secrets : secret.valueFrom]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${local.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECS Task Role
# -----------------------------------------------------------------------------
# This role is assumed by the container itself and grants permissions
# for the application to interact with AWS services.

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ecs-task-role"
    }
  )
}

# Base policy for task role - CloudWatch logs
resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "${var.project_name}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.ecs.arn}:*"
      }
    ]
  })
}

# Attach additional task role policies if provided
resource "aws_iam_role_policy_attachment" "ecs_task_role_additional" {
  for_each = toset(var.additional_task_role_policy_arns)

  role       = aws_iam_role.ecs_task_role.name
  policy_arn = each.value
}
