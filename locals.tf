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
      Module      = "terraform-aws-quine-enterprise"
    },
    var.tags
  )

  # Get current AWS region from provider for log configuration
  # This uses a data source since we can't use var.aws_region anymore (provider config is in root module)
  aws_region = data.aws_region.current.name

  # -----------------------------------------------------------------------------
  # Quine Enterprise Cluster Configuration
  # -----------------------------------------------------------------------------

  # Determine if multi-member cluster mode is enabled
  is_multi_member_cluster = var.cluster_target_size > 1

  # Service discovery namespace name
  service_discovery_namespace_name = var.service_discovery_namespace_name != null ? var.service_discovery_namespace_name : "${var.project_name}.local"

  # Service discovery seed service name (used for cluster join DNS)
  seed_service_name = "${var.project_name}-seed"

  # Full DNS name for the seed service (used by QUINE_SEED_DNS)
  # Format: {seed_service_name}.{namespace_name}
  seed_dns_name = local.is_multi_member_cluster ? "${local.seed_service_name}.${local.service_discovery_namespace_name}" : ""

  # Base Java options for Quine cluster configuration
  # Always include target-size
  cluster_java_opts_base = "-Dquine.cluster.target-size=${var.cluster_target_size}"

  # Additional Java options for multi-member clusters
  cluster_java_opts_multi_member = local.is_multi_member_cluster ? " -Dquine.cluster.cluster-join.type=dns-entry" : ""

  # Combined cluster Java options
  cluster_java_opts = "${local.cluster_java_opts_base}${local.cluster_java_opts_multi_member}"

  # Full JAVA_OPTS combining user-provided and cluster options
  java_opts_value = trimspace("${var.java_opts} ${local.cluster_java_opts}")

  # -----------------------------------------------------------------------------
  # Container Environment Variables
  # -----------------------------------------------------------------------------

  # Default environment variables
  default_environment = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "JAVA_OPTS"
      value = local.java_opts_value
    }
  ]

  # Seed DNS environment variable (only for multi-member clusters)
  seed_dns_environment = local.is_multi_member_cluster ? [
    {
      name  = "QUINE_SEED_DNS"
      value = local.seed_dns_name
    }
  ] : []

  # Combined container environment
  container_environment = concat(
    local.default_environment,
    local.seed_dns_environment,
    var.container_environment
  )
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
