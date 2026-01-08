# -----------------------------------------------------------------------------
# Basic Example - Quine Enterprise on ECS Fargate
# -----------------------------------------------------------------------------
# This example demonstrates the simplest deployment of Quine Enterprise using
# the module with minimal configuration. It uses the default VPC and sensible
# defaults.
#
# Usage:
#   terraform init
#   terraform plan
#   terraform apply
#
# After deployment, access Quine Enterprise at the URL shown in the outputs.
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
# The module consumer is responsible for provider configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Example   = "basic"
      ManagedBy = "Terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Locals - Build JDK_JAVA_OPTIONS from variables
# -----------------------------------------------------------------------------

locals {
  jdk_java_options = join(" ", [
    "-Dquine.license-key=${var.license_key}",
  ])
}

# Deploy Quine Enterprise using the module
module "quine" {
  source = "../../"

  # Required: Project name for resource naming
  project_name = "quine-basic"

  # Required: Container image - must be provided by the user
  container_image = var.container_image

  # Environment variables built from Quine Enterprise configuration
  container_environment = [
    {
      name  = "JDK_JAVA_OPTIONS"
      value = local.jdk_java_options
    }
  ]

  # Optional: Environment tag (defaults to "dev")
  environment = "dev"

  # All other values use sensible defaults:
  # - Uses default VPC and subnets
  # - 2048 CPU units (2 vCPU)
  # - 4096 MB memory (4 GB)
  # - 1 task instance
}
