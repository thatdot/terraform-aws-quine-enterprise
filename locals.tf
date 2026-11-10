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

  # Lets the JVM read configuration from CONFIG_FORCE_* environment variables
  # (Typesafe Config). The container image does not enable this itself, and it
  # is what allows the license key to arrive as an ECS-injected secret.
  config_env_override_java_opt = "-Dconfig.override_with_env_vars=true"

  # Full JDK_JAVA_OPTIONS combining user-provided, config-override, and cluster options
  java_opts_value = trimspace("${var.java_opts} ${local.config_env_override_java_opt} ${local.cluster_java_opts}")

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
      name  = "JDK_JAVA_OPTIONS"
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

  # -----------------------------------------------------------------------------
  # Container Secrets
  # -----------------------------------------------------------------------------

  # Environment variable Quine Enterprise reads as its quine.license-key setting
  license_key_env_name = "CONFIG_FORCE_quine_license__key"

  license_secrets = var.license_key_secret_arn != null ? [
    {
      name      = local.license_key_env_name
      valueFrom = var.license_key_secret_arn
    }
  ] : []

  # Combined container secrets
  container_secrets = concat(
    local.license_secrets,
    var.container_secrets
  )

  # ARNs the execution role must be able to read. A Secrets Manager valueFrom
  # may end in ':json-key:version-stage:version-id'; IAM needs the bare secret ARN.
  container_secret_arns = distinct([
    for secret in local.container_secrets :
    try(regex("^arn:[^:]*:secretsmanager:[^:]*:[^:]*:secret:[^:]+", secret.valueFrom), secret.valueFrom)
  ])
}

# -----------------------------------------------------------------------------
# Configuration Checks
# -----------------------------------------------------------------------------
# These report warnings instead of failing the plan, so existing callers are
# not broken by upgrading.

check "jdk_java_options_not_overridden" {
  assert {
    condition     = !contains([for env in var.container_environment : env.name], "JDK_JAVA_OPTIONS")
    error_message = "container_environment sets JDK_JAVA_OPTIONS, which overrides the value the module builds (cluster options and the flag that makes license_key_secret_arn work). Pass JVM options through java_opts instead."
  }
}

check "license_key_secret_not_duplicated" {
  assert {
    condition     = var.license_key_secret_arn == null || !contains([for secret in var.container_secrets : secret.name], local.license_key_env_name)
    error_message = "container_secrets already defines ${local.license_key_env_name}. Remove that entry when using license_key_secret_arn; ECS rejects duplicate secret names."
  }
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
