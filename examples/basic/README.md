# Basic Example

Simplest deployment of Quine on AWS ECS Fargate with minimal configuration.

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.5.0
- Default VPC in the target region

## Usage

```bash
terraform init
terraform plan
terraform apply
```

After deployment, access Quine at the URL shown in outputs:

```bash
terraform output url
```

## Cleanup

```bash
terraform destroy
```

## What Gets Created

- ECS Fargate cluster with Container Insights
- ECS service running 1 Quine container (2 vCPU, 4 GB)
- Internet-facing Application Load Balancer (HTTP)
- Security groups for ALB and ECS tasks
- CloudWatch log group
- IAM roles for task execution

## Outputs

| Name | Description |
|------|-------------|
| url | URL to access Quine |
| alb_dns_name | ALB DNS name |
| ecs_cluster_name | ECS cluster name |
| ecs_service_name | ECS service name |
| cloudwatch_log_group | CloudWatch log group name |

## Next Steps

See the [complete example](../complete/) for HTTPS, custom domains, and advanced configuration.
