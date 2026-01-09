# Complete Example

Production-ready deployment of Quine Enterprise on AWS ECS Fargate with HTTPS and custom domain support.

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.5.0
- Route53 hosted zone for your domain (for HTTPS)
- Quine Enterprise container image (from your registry or ECR)
- Quine Enterprise license key

## Quick Start

1. Copy the example tfvars file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your required values:

```hcl
# Project configuration
project_name = "quine-enterprise-prod"

# Container image (required)
container_image = "your-registry/quine-enterprise:latest"

# Quine Enterprise license (required)
license_key        = "YOUR_LICENSE_KEY"

# HTTPS configuration (optional but recommended)
enable_https   = true
domain_name    = "quine-enterprise.example.com"
hosted_zone_id = "Z0123456789ABCDEFGHIJ"
```

To find your hosted zone ID:
```bash
aws route53 list-hosted-zones --query "HostedZones[?Name=='example.com.'].Id" --output text
```

3. Deploy:

```bash
terraform init
terraform plan
terraform apply
```

4. Access Quine Enterprise at `https://quine-enterprise.example.com`

## Configuration Options

See `terraform.tfvars.example` for all available options including:
- Custom VPC and subnet configuration
- Container CPU/memory allocation
- Environment variables and secrets
- ALB access restrictions

## HTTPS Options

**Option 1: Automatic (Recommended)** - Provide `domain_name` + `hosted_zone_id` and Terraform creates the ACM certificate and Route53 records.

**Option 2: Bring Your Own Certificate** - Provide `certificate_arn` for an existing ACM certificate.

## Cleanup

```bash
terraform destroy
```

Note: If you enabled `enable_deletion_protection = true`, disable it first via AWS Console or set to `false` and apply.

## What Gets Created

- ECS Fargate cluster with Container Insights
- ECS service running 1 Quine Enterprise container (4 vCPU, 8 GB)
- Internet-facing ALB with HTTPS
- ACM certificate (if using automatic option)
- Route53 alias record for custom domain
- Security groups, CloudWatch logs, IAM roles

## Outputs

| Name                 | Description                    |
| -------------------- | ------------------------------ |
| url                  | URL to access Quine Enterprise |
| certificate_arn      | ACM certificate ARN            |
| alb_dns_name         | ALB DNS name                   |
| ecs_cluster_name     | ECS cluster name               |
| ecs_service_name     | ECS service name               |
| cloudwatch_log_group | CloudWatch log group           |
