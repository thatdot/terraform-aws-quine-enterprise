# Terraform AWS Quine Enterprise Module

[![Terraform Registry](https://img.shields.io/badge/terraform-registry-blue.svg)](https://registry.terraform.io/modules/thatdot/quine-enterprise/aws)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

Terraform module to deploy Quine Enterprise on AWS ECS Fargate with an Application Load Balancer.

## Features

- **ECS Fargate** - Serverless container orchestration (no EC2 instances to manage)
- **Application Load Balancer** - HTTP/HTTPS traffic distribution with health checks
- **Auto-discovery** - Automatically uses default VPC if none specified
- **HTTPS Support** - Optional TLS termination with ACM certificates
- **CloudWatch Integration** - Container logs with configurable retention
- **Container Insights** - Optional detailed container metrics
- **IAM Least Privilege** - Separate execution and task roles with minimal permissions
- **Secrets Management** - Native integration with AWS Secrets Manager and SSM Parameter Store
- **Production Ready** - Deployment circuit breaker, deletion protection, and proper tagging

## Architecture

```
                    Internet
                        |
                        v
              +-------------------+
              |        ALB        |
              | (Security Group)  |
              +-------------------+
                        |
                        v
              +-------------------+
              |    ECS Service    |
              | (Security Group)  |
              |                   |
              |  +-------------+  |
              |  | Quine Task  |  |
              |  +-------------+  |
              +-------------------+
                        |
                        v
              +-------------------+
              | CloudWatch Logs   |
              +-------------------+
```

## Quick Start

### Minimal Configuration

```hcl
module "quine_enterprise" {
  source  = "github.com/thatdot/terraform-aws-quine-enterprise"

  project_name    = "my-quine-enterprise"
  container_image = "your-registry/quine-enterprise:latest"  # Required
}

output "url" {
  value = module.quine_enterprise.alb_url
}
```

### Production Configuration

```hcl
module "quine_enterprise" {
  source  = "github.com/thatdot/terraform-aws-quine-enterprise"

  project_name    = "quine-enterprise-prod"
  environment     = "prod"
  container_image = "your-registry/quine-enterprise:latest"  # Required

  # Custom VPC
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-111", "subnet-222"]

  # Container sizing
  container_cpu    = 4096
  container_memory = 8192
  desired_count    = 2

  # HTTPS
  enable_https    = true
  certificate_arn = "arn:aws:acm:us-west-2:123456789012:certificate/..."

  # Production settings
  enable_deletion_protection = true
  log_retention_days         = 30

  tags = {
    Team = "platform"
  }
}
```

## Requirements

| Name      | Version       |
| --------- | ------------- |
| terraform | >= 1.5.0      |
| aws       | >= 5.0, < 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws  | >= 5.0  |

## Usage

See the [examples](./examples/) directory for complete usage examples:

- [Basic](./examples/basic/) - Minimal configuration using defaults
- [Complete](./examples/complete/) - Production setup with all options

## Inputs

### Required

| Name           | Description                                                              | Type     |
| -------------- | ------------------------------------------------------------------------ | -------- |
| `project_name` | Project name for resource naming (3-32 chars, alphanumeric with hyphens) | `string` |

### Environment

| Name          | Description                               | Type          | Default |
| ------------- | ----------------------------------------- | ------------- | ------- |
| `environment` | Environment name (2-16 lowercase letters) | `string`      | `"dev"` |
| `tags`        | Additional tags for all resources         | `map(string)` | `{}`    |

### Network

| Name               | Description                                  | Type           | Default |
| ------------------ | -------------------------------------------- | -------------- | ------- |
| `vpc_id`           | VPC ID (uses default VPC if null)            | `string`       | `null`  |
| `subnet_ids`       | Subnet IDs (min 2, uses VPC subnets if null) | `list(string)` | `null`  |
| `assign_public_ip` | Assign public IP to ECS tasks                | `bool`         | `true`  |

### ECS Cluster

| Name                        | Description                                             | Type     | Default |
| --------------------------- | ------------------------------------------------------- | -------- | ------- |
| `cluster_name`              | ECS cluster name (defaults to `{project_name}-cluster`) | `string` | `null`  |
| `enable_container_insights` | Enable CloudWatch Container Insights                    | `bool`   | `true`  |

### ECS Service

| Name            | Description                                             | Type     | Default |
| --------------- | ------------------------------------------------------- | -------- | ------- |
| `service_name`  | ECS service name (defaults to `{project_name}-service`) | `string` | `null`  |
| `desired_count` | Number of ECS tasks (0-10)                              | `number` | `1`     |

### Container

| Name                    | Description                      | Type           | Default              |
| ----------------------- | -------------------------------- | -------------- | -------------------- |
| `container_name`        | Container name                   | `string`       | `"quine-enterprise"` |
| `container_image`       | Docker image (required)          | `string`       | n/a                  |
| `container_port`        | Container port                   | `number`       | `8080`               |
| `container_cpu`         | CPU units (256-16384)            | `number`       | `2048`               |
| `container_memory`      | Memory in MB                     | `number`       | `4096`               |
| `container_environment` | Environment variables            | `list(object)` | `[]`                 |
| `container_secrets`     | Secrets from SSM/Secrets Manager | `list(object)` | `[]`                 |

### Load Balancer

| Name                               | Description                        | Type     | Default                    |
| ---------------------------------- | ---------------------------------- | -------- | -------------------------- |
| `internal_alb`                     | Internal ALB (not internet-facing) | `bool`   | `false`                    |
| `health_check_path`                | Health check path                  | `string` | `"/api/v1/admin/liveness"` |
| `health_check_interval`            | Health check interval (seconds)    | `number` | `30`                       |
| `health_check_timeout`             | Health check timeout (seconds)     | `number` | `5`                        |
| `health_check_healthy_threshold`   | Healthy threshold                  | `number` | `2`                        |
| `health_check_unhealthy_threshold` | Unhealthy threshold                | `number` | `3`                        |
| `deregistration_delay`             | Deregistration delay (seconds)     | `number` | `30`                       |
| `enable_deletion_protection`       | Enable ALB deletion protection     | `bool`   | `false`                    |

### HTTPS

| Name              | Description           | Type     | Default                                 |
| ----------------- | --------------------- | -------- | --------------------------------------- |
| `enable_https`    | Enable HTTPS listener | `bool`   | `false`                                 |
| `certificate_arn` | ACM certificate ARN   | `string` | `null`                                  |
| `ssl_policy`      | SSL policy            | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` |

### Logging

| Name                 | Description                     | Type     | Default |
| -------------------- | ------------------------------- | -------- | ------- |
| `log_retention_days` | CloudWatch log retention (days) | `number` | `7`     |

### Security

| Name                                    | Description                                | Type           | Default         |
| --------------------------------------- | ------------------------------------------ | -------------- | --------------- |
| `alb_ingress_cidr_blocks`               | CIDR blocks allowed to access ALB          | `list(string)` | `["0.0.0.0/0"]` |
| `additional_task_role_policy_arns`      | Additional IAM policies for task role      | `list(string)` | `[]`            |
| `additional_execution_role_policy_arns` | Additional IAM policies for execution role | `list(string)` | `[]`            |

### Quine Enterprise Cluster

| Name                               | Description                                                              | Type     | Default |
| ---------------------------------- | ------------------------------------------------------------------------ | -------- | ------- |
| `cluster_target_size`              | Target number of cluster members (enables multi-member mode when > 1)    | `number` | `3`     |
| `cluster_port`                     | Port for inter-node cluster communication (Pekko/Akka cluster)           | `number` | `25520` |
| `service_discovery_namespace_name` | Private DNS namespace name (defaults to `{project_name}.local`)          | `string` | `null`  |
| `java_opts`                        | Additional Java options to pass via JAVA_OPTS environment variable       | `string` | `""`    |

## Outputs

### Load Balancer

| Name               | Description         |
| ------------------ | ------------------- |
| `alb_id`           | ALB ID              |
| `alb_arn`          | ALB ARN             |
| `alb_dns_name`     | ALB DNS name        |
| `alb_zone_id`      | ALB Route53 zone ID |
| `alb_url`          | Application URL     |
| `target_group_arn` | Target group ARN    |

### ECS

| Name                           | Description              |
| ------------------------------ | ------------------------ |
| `ecs_cluster_id`               | ECS cluster ID           |
| `ecs_cluster_arn`              | ECS cluster ARN          |
| `ecs_cluster_name`             | ECS cluster name         |
| `ecs_service_id`               | ECS service ID           |
| `ecs_service_name`             | ECS service name         |
| `ecs_task_definition_arn`      | Task definition ARN      |
| `ecs_task_definition_family`   | Task definition family   |
| `ecs_task_definition_revision` | Task definition revision |

### CloudWatch

| Name                        | Description    |
| --------------------------- | -------------- |
| `cloudwatch_log_group_name` | Log group name |
| `cloudwatch_log_group_arn`  | Log group ARN  |

### IAM

| Name                           | Description         |
| ------------------------------ | ------------------- |
| `ecs_task_execution_role_arn`  | Execution role ARN  |
| `ecs_task_execution_role_name` | Execution role name |
| `ecs_task_role_arn`            | Task role ARN       |
| `ecs_task_role_name`           | Task role name      |

### Security Groups

| Name                          | Description                 |
| ----------------------------- | --------------------------- |
| `alb_security_group_id`       | ALB security group ID       |
| `ecs_tasks_security_group_id` | ECS tasks security group ID |

### Network

| Name         | Description |
| ------------ | ----------- |
| `vpc_id`     | VPC ID      |
| `subnet_ids` | Subnet IDs  |

### Quine Enterprise Cluster

| Name                                | Description                                              |
| ----------------------------------- | -------------------------------------------------------- |
| `cluster_target_size`               | Configured cluster target size                           |
| `is_multi_member_cluster`           | Whether running in multi-member cluster mode             |
| `service_discovery_namespace_id`    | AWS Cloud Map namespace ID (null if single-member)       |
| `service_discovery_namespace_arn`   | AWS Cloud Map namespace ARN (null if single-member)      |
| `service_discovery_namespace_name`  | AWS Cloud Map namespace name (null if single-member)     |
| `service_discovery_seed_service_id` | AWS Cloud Map seed service ID (null if single-member)    |
| `service_discovery_seed_service_arn`| AWS Cloud Map seed service ARN (null if single-member)   |
| `seed_dns_name`                     | DNS name for cluster seed discovery (empty if single)    |

## Examples

### Using with Custom VPC

```hcl
module "quine_enterprise" {
  source = "github.com/thatdot/terraform-aws-quine-enterprise"

  project_name    = "quine-enterprise"
  container_image = "your-registry/quine-enterprise:latest"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnets
}
```

### With Environment Variables

```hcl
module "quine_enterprise" {
  source = "github.com/thatdot/terraform-aws-quine-enterprise"

  project_name    = "quine-enterprise"
  container_image = "your-registry/quine-enterprise:latest"

  container_environment = [
    {
      name  = "JAVA_OPTS"
      value = "-Xms4g -Xmx6g"
    },
    {
      name  = "QUINE_WEBSERVER_ADDRESS"
      value = "0.0.0.0"
    }
  ]
}
```

### With Secrets

```hcl
module "quine_enterprise" {
  source = "github.com/thatdot/terraform-aws-quine-enterprise"

  project_name    = "quine-enterprise"
  container_image = "your-registry/quine-enterprise:latest"

  container_secrets = [
    {
      name      = "DATABASE_PASSWORD"
      valueFrom = "arn:aws:secretsmanager:us-west-2:123456789012:secret:db-pass"
    }
  ]
}
```

### With HTTPS and Route53

```hcl
module "quine_enterprise" {
  source = "github.com/thatdot/terraform-aws-quine-enterprise"

  project_name    = "quine-enterprise"
  container_image = "your-registry/quine-enterprise:latest"
  enable_https    = true
  certificate_arn = aws_acm_certificate.quine_enterprise.arn
}

resource "aws_route53_record" "quine_enterprise" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "quine-enterprise.example.com"
  type    = "A"

  alias {
    name                   = module.quine_enterprise.alb_dns_name
    zone_id                = module.quine_enterprise.alb_zone_id
    evaluate_target_health = true
  }
}
```

### Multi-Member Cluster

Deploy a 3-member Quine Enterprise cluster with DNS-based service discovery for high availability:

```hcl
module "quine_enterprise" {
  source = "github.com/thatdot/terraform-aws-quine-enterprise"

  project_name    = "quine-enterprise"
  container_image = "your-registry/quine-enterprise:latest"

  # Multi-member cluster configuration (default is 3)
  cluster_target_size = 3

  # Container sizing for production cluster
  container_cpu    = 4096
  container_memory = 8192

  # Additional Java options for your workload
  java_opts = "-Xms4g -Xmx6g -Dquine.webserver.address=0.0.0.0"

  tags = {
    Team = "platform"
  }
}

output "seed_dns" {
  description = "DNS name for cluster seed discovery"
  value       = module.quine_enterprise.seed_dns_name
}
```

For a single-member deployment (non-clustered), set `cluster_target_size = 1`:

```hcl
module "quine_enterprise" {
  source = "github.com/thatdot/terraform-aws-quine-enterprise"

  project_name        = "quine-enterprise-dev"
  container_image     = "your-registry/quine-enterprise:latest"
  cluster_target_size = 1  # Single-member mode (no service discovery)
}
```

## Upgrading

### From Direct Terraform to Module

If you were previously using this as a standalone Terraform configuration:

1. Add provider configuration to your root module
2. Call this as a module instead of applying directly
3. Run `terraform state mv` commands to move resources into the module

## Contributing

Contributions are welcome! Please read the [contributing guidelines](CONTRIBUTING.md) first.

## License

Apache 2.0 - See [LICENSE](LICENSE) for details.

## Authors

- Your Organization

## Related Projects

- [Quine Enterprise](https://quine.io/) - Enterprise streaming graph for connected data
- [thatDot](https://thatdot.com/) - Company behind Quine Enterprise
