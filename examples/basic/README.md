# Basic Example

Simplest deployment of Quine Enterprise on AWS ECS Fargate with minimal configuration.

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.5.0
- Default VPC in the target region
- Quine Enterprise container image (from your registry or ECR)
- Quine Enterprise license key

## Quick Start

1. Copy the example tfvars file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your required values:

```hcl
# Container image (required)
container_image = "your-registry/quine-enterprise:latest"

# Quine Enterprise license (required)
license_key        = "YOUR_LICENSE_KEY"
```

3. Deploy:

```bash
terraform init
terraform plan
terraform apply
```

4. Access Quine Enterprise at the URL shown in outputs:

```bash
terraform output url
```

## Cleanup

```bash
terraform destroy
```

## What Gets Created

- ECS Fargate cluster with Container Insights
- ECS service running 1 Quine Enterprise container (2 vCPU, 4 GB)
- Internet-facing Application Load Balancer (HTTP)
- Security groups for ALB and ECS tasks
- CloudWatch log group
- IAM roles for task execution

## Outputs

| Name                 | Description                      |
| -------------------- | -------------------------------- |
| url                  | URL to access Quine Enterprise   |
| alb_dns_name         | ALB DNS name                     |
| ecs_cluster_name     | ECS cluster name                 |
| ecs_service_name     | ECS service name                 |
| cloudwatch_log_group | CloudWatch log group name        |

## Next Steps

See the [complete example](../complete/) for HTTPS, custom domains, and advanced configuration.
