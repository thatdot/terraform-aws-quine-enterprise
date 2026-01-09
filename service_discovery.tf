# -----------------------------------------------------------------------------
# AWS Cloud Map Service Discovery
# -----------------------------------------------------------------------------
# This file defines the service discovery resources for Quine Enterprise
# multi-member cluster mode. When cluster_target_size > 1, a private DNS
# namespace and service are created to enable cluster member discovery.
#
# The seed service acts like the Kubernetes headless service, providing
# DNS-based discovery for cluster join operations.
# -----------------------------------------------------------------------------

# Private DNS Namespace for service discovery
# Only created when multi-member cluster mode is enabled
resource "aws_service_discovery_private_dns_namespace" "main" {
  count = local.is_multi_member_cluster ? 1 : 0

  name        = local.service_discovery_namespace_name
  description = "Private DNS namespace for ${var.project_name} Quine Enterprise cluster discovery"
  vpc         = local.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = local.service_discovery_namespace_name
    }
  )
}

# Service Discovery Service for cluster seed nodes
# This is the AWS Cloud Map equivalent of the Kubernetes headless service
# It enables DNS-based service discovery for Quine cluster join operations
resource "aws_service_discovery_service" "seed" {
  count = local.is_multi_member_cluster ? 1 : 0

  name = local.seed_service_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main[0].id

    # A records return the IP addresses of the ECS tasks
    dns_records {
      ttl  = 10
      type = "A"
    }

    # SRV records return IP addresses AND ports for each task
    # This is critical for Pekko cluster bootstrap to find the management port (7626)
    # which is used for HTTP-based contact point discovery during cluster formation.
    # The SRV port is configured in the ECS service_registries block.
    dns_records {
      ttl  = 10
      type = "SRV"
    }

    # MULTIVALUE routing returns all healthy instances
    # This is similar to Kubernetes headless service behavior
    routing_policy = "MULTIVALUE"
  }

  # Use ECS-managed health checks rather than Route 53 health checks
  # ECS automatically registers/deregisters tasks based on their health
  health_check_custom_config {
    failure_threshold = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.seed_service_name
    }
  )
}
