# -----------------------------------------------------------------------------
# Complete Example - Quine Enterprise on ECS Fargate with Custom VPC and HTTPS
# -----------------------------------------------------------------------------
# This example demonstrates a production-ready deployment of Quine Enterprise with:
# - Custom VPC and subnets
# - HTTPS with ACM certificate
# - Custom container configuration
# - Environment variables and secrets
# - Multiple task instances for high availability
#
# Usage:
#   # Copy the example tfvars file and customize
#   cp terraform.tfvars.example terraform.tfvars
#
#   # Edit terraform.tfvars with your values
#
#   terraform init
#   terraform plan
#   terraform apply
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Example     = "complete"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Look up existing VPC by tag (optional - remove if using vpc_id directly)
data "aws_vpc" "selected" {
  count = var.vpc_name != null ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Look up subnets by tag (optional - remove if using subnet_ids directly)
data "aws_subnets" "selected" {
  count = var.subnet_tag_filter != null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.vpc_id != null ? var.vpc_id : data.aws_vpc.selected[0].id]
  }

  filter {
    name   = "tag:Name"
    values = [var.subnet_tag_filter]
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  # Create a certificate if HTTPS is enabled, no certificate ARN is provided, and domain_name is set
  create_certificate = var.enable_https && var.certificate_arn == null && var.domain_name != null

  # Use provided certificate ARN or the one we create
  certificate_arn = var.certificate_arn != null ? var.certificate_arn : (
    local.create_certificate ? aws_acm_certificate.this[0].arn : null
  )

  # Build JDK_JAVA_OPTIONS from Quine Enterprise configuration variables
  jdk_java_options = join(" ", [
    "-Dquine.license-key=${var.license_key}",
    "-Dquine.license-server-uri=${var.license_server_uri}",
  ])
}

# -----------------------------------------------------------------------------
# ACM Certificate (created when enable_https=true and no certificate_arn provided)
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "this" {
  count = local.create_certificate ? 1 : 0

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-certificate"
  }
}

# Route53 records for ACM certificate DNS validation
resource "aws_route53_record" "cert_validation" {
  for_each = local.create_certificate ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.hosted_zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "this" {
  count = local.create_certificate ? 1 : 0

  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# -----------------------------------------------------------------------------
# Module Deployment
# -----------------------------------------------------------------------------

module "quine_enterprise" {
  source = "../../"

  # Project identification
  project_name = var.project_name
  environment  = var.environment

  # Network configuration
  # Priority: explicit vpc_id/subnet_ids > name lookup > default VPC (handled by module)
  vpc_id = var.vpc_id != null ? var.vpc_id : (
    var.vpc_name != null ? data.aws_vpc.selected[0].id : null
  )
  subnet_ids = var.subnet_ids != null ? var.subnet_ids : (
    var.subnet_tag_filter != null ? data.aws_subnets.selected[0].ids : null
  )
  assign_public_ip = var.assign_public_ip

  # ECS cluster configuration
  cluster_name              = var.cluster_name
  enable_container_insights = var.enable_container_insights

  # ECS service configuration
  service_name  = var.service_name
  desired_count = var.desired_count

  # Quine Enterprise cluster configuration (3-member cluster for HA)
  cluster_target_size = 3

  # Container configuration
  container_name   = var.container_name
  container_image  = var.container_image
  container_port   = var.container_port
  container_cpu    = var.container_cpu
  container_memory = var.container_memory

  # Java options for Quine Enterprise (license configuration)
  # The module automatically adds cluster-related Java options
  java_opts = local.jdk_java_options

  # Secrets (from SSM Parameter Store or Secrets Manager)
  container_secrets = var.container_secrets

  # Load balancer configuration
  internal_alb               = var.internal_alb
  health_check_path          = var.health_check_path
  health_check_interval      = var.health_check_interval
  enable_deletion_protection = var.enable_deletion_protection

  # HTTPS configuration
  enable_https    = var.enable_https
  certificate_arn = local.certificate_arn
  ssl_policy      = var.ssl_policy

  depends_on = [
    aws_acm_certificate_validation.this
  ]

  # Logging
  log_retention_days = var.log_retention_days

  # Security
  alb_ingress_cidr_blocks = var.alb_ingress_cidr_blocks

  # Additional IAM policies
  additional_task_role_policy_arns      = var.additional_task_role_policy_arns
  additional_execution_role_policy_arns = var.additional_execution_role_policy_arns

  # Custom tags
  tags = var.tags
}

# -----------------------------------------------------------------------------
# Route53 Alias Record for ALB
# -----------------------------------------------------------------------------

resource "aws_route53_record" "alb_alias" {
  count = var.domain_name != null && var.hosted_zone_id != null ? 1 : 0

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.quine_enterprise.alb_dns_name
    zone_id                = module.quine_enterprise.alb_zone_id
    evaluate_target_health = true
  }
}
