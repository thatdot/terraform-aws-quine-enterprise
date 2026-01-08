# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------
# This file centralizes computed values and fallback logic for VPC/subnet
# configuration. When users don't provide vpc_id or subnet_ids, the module
# automatically discovers and uses the default VPC and its subnets.
# -----------------------------------------------------------------------------

locals {
  # Determine whether to use custom or default VPC
  use_default_vpc = var.vpc_id == null

  # Resolve VPC ID - use provided value or fall back to default VPC
  vpc_id = local.use_default_vpc ? data.aws_vpc.default[0].id : var.vpc_id

  # Resolve subnet IDs - use provided value or fall back to default VPC subnets
  subnet_ids = var.subnet_ids != null ? var.subnet_ids : data.aws_subnets.default[0].ids

  # Computed resource names with fallbacks
  cluster_name = var.cluster_name != null ? var.cluster_name : "${var.project_name}-cluster"
  service_name = var.service_name != null ? var.service_name : "${var.project_name}-service"

  # Common tags applied to all resources
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "terraform-aws-thatdot"
    },
    var.tags
  )

  # Container environment variables - merge default with user-provided
  default_environment = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  ]

  container_environment = concat(local.default_environment, var.container_environment)

  # Get current AWS region from provider for log configuration
  # This uses a data source since we can't use var.aws_region anymore (provider config is in root module)
  aws_region = data.aws_region.current.name
}

# -----------------------------------------------------------------------------
# Data Sources for Default VPC Discovery
# -----------------------------------------------------------------------------

# Get current AWS region
data "aws_region" "current" {}

# Get default VPC (only if vpc_id is not provided)
data "aws_vpc" "default" {
  count   = local.use_default_vpc ? 1 : 0
  default = true
}

# Get subnets in the default VPC (only if subnet_ids not provided)
data "aws_subnets" "default" {
  count = var.subnet_ids == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.use_default_vpc ? data.aws_vpc.default[0].id : var.vpc_id]
  }
}
