# -----------------------------------------------------------------------------
# Variables for Complete Example
# -----------------------------------------------------------------------------
# These variables allow full customization of the Quine Enterprise deployment.
# Copy terraform.tfvars.example to terraform.tfvars and customize.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID (if not using vpc_name lookup)"
  type        = string
  default     = null
}

variable "vpc_name" {
  description = "VPC name tag to look up (alternative to vpc_id)"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "Subnet IDs (if not using subnet_tag_filter lookup)"
  type        = list(string)
  default     = null
}

variable "subnet_tag_filter" {
  description = "Subnet name tag filter for lookup (e.g., '*-public-*')"
  type        = string
  default     = null
}

variable "assign_public_ip" {
  description = "Assign public IP to ECS tasks"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ECS Cluster Configuration
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = null
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ECS Service Configuration
# -----------------------------------------------------------------------------

variable "service_name" {
  description = "ECS service name"
  type        = string
  default     = null
}

variable "desired_count" {
  description = "Number of ECS tasks"
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# Container Configuration
# -----------------------------------------------------------------------------

variable "container_name" {
  description = "Container name"
  type        = string
  default     = "quine"
}

variable "container_image" {
  description = "Docker image to run in the ECS task. This is required and must be provided by the user."
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "container_cpu" {
  description = "CPU units"
  type        = number
  default     = 4096
}

variable "container_memory" {
  description = "Memory in MB"
  type        = number
  default     = 8192
}

variable "container_environment" {
  description = "Environment variables"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "container_secrets" {
  description = "Secrets from SSM/Secrets Manager"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

# -----------------------------------------------------------------------------
# Load Balancer Configuration
# -----------------------------------------------------------------------------

variable "internal_alb" {
  description = "Internal ALB (not internet-facing)"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/api/v1/liveness"
}

variable "health_check_interval" {
  description = "Health check interval (seconds)"
  type        = number
  default     = 30
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# HTTPS Configuration
# -----------------------------------------------------------------------------

variable "enable_https" {
  description = "Enable HTTPS. When enabled, requires either certificate_arn OR domain_name + hosted_zone_id"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. If not provided and enable_https is true, a certificate will be created using domain_name"
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "domain_name" {
  description = "Domain name for the Quine service (e.g., quine.example.com). Required if enable_https is true and certificate_arn is not provided"
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID where the domain is managed. Required if domain_name is provided"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Logging Configuration
# -----------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch log retention (days)"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_task_role_policy_arns" {
  description = "Additional IAM policies for task role"
  type        = list(string)
  default     = []
}

variable "additional_execution_role_policy_arns" {
  description = "Additional IAM policies for execution role"
  type        = list(string)
  default     = []
}
