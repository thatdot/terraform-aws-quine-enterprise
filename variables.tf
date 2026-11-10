# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Project name used for resource naming and tagging. Must be alphanumeric with hyphens, 3-32 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{2,31}$", var.project_name))
    error_message = "Project name must start with a letter, be 3-32 characters, and contain only alphanumeric characters and hyphens."
  }
}

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod). Used for resource tagging and naming."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z]{2,16}$", var.environment))
    error_message = "Environment must be 2-16 lowercase letters (e.g., dev, staging, prod)."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID where resources will be deployed. If not provided, the default VPC will be used."
  type        = string
  default     = null

  validation {
    condition     = var.vpc_id == null || can(regex("^vpc-[a-f0-9]{8,17}$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID (e.g., vpc-1234abcd or vpc-1234567890abcdef0)."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB and ECS tasks. If not provided, all subnets in the VPC will be used. Minimum 2 subnets in different AZs required for ALB."
  type        = list(string)
  default     = null

  validation {
    condition     = var.subnet_ids == null ? true : (length(var.subnet_ids) >= 2 && alltrue([for s in var.subnet_ids : can(regex("^subnet-[a-f0-9]{8,17}$", s))]))
    error_message = "Subnet IDs must be valid AWS subnet IDs and at least 2 subnets are required for the ALB."
  }
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to ECS tasks. Required if using public subnets without NAT gateway."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ECS Cluster Configuration
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the ECS cluster. If not provided, defaults to '{project_name}-cluster'."
  type        = string
  default     = null

  validation {
    condition     = var.cluster_name == null || can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,254}$", var.cluster_name))
    error_message = "Cluster name must start with a letter and contain only alphanumeric characters and hyphens (max 255 characters)."
  }
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for the ECS cluster."
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# ECS Service Configuration
# -----------------------------------------------------------------------------

variable "service_name" {
  description = "Name of the ECS service. If not provided, defaults to '{project_name}-service'."
  type        = string
  default     = null

  validation {
    condition     = var.service_name == null || can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,254}$", var.service_name))
    error_message = "Service name must start with a letter and contain only alphanumeric characters and hyphens (max 255 characters)."
  }
}

variable "desired_count" {
  description = "Desired number of ECS tasks to run. Note: This is ignored when cluster_target_size > 1 (multi-member mode uses cluster_target_size instead)."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 0 && var.desired_count <= 10
    error_message = "Desired count must be between 0 and 10."
  }
}

# -----------------------------------------------------------------------------
# Container Configuration
# -----------------------------------------------------------------------------

variable "container_name" {
  description = "Name of the container within the task definition."
  type        = string
  default     = "quine-enterprise"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]{0,254}$", var.container_name))
    error_message = "Container name must start with a letter and contain only alphanumeric characters, underscores, and hyphens."
  }
}

variable "container_image" {
  description = "Docker image to run in the ECS task. This is required and must be provided by the user (e.g., 'your-repo/quine-enterprise:tag' or 'ECR_URI:tag')."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._/-]*:[a-zA-Z0-9._-]+$", var.container_image)) || can(regex("^[0-9]+\\.dkr\\.ecr\\.[a-z0-9-]+\\.amazonaws\\.com/", var.container_image))
    error_message = "Container image must be a valid Docker image reference with tag (e.g., 'repo/image:tag' or ECR URI)."
  }
}

variable "container_port" {
  description = "Port exposed by the container."
  type        = number
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "container_cpu" {
  description = "CPU units for the Fargate task (256, 512, 1024, 2048, 4096, 8192, or 16384)."
  type        = number
  default     = 2048

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.container_cpu)
    error_message = "Container CPU must be a valid Fargate CPU value: 256, 512, 1024, 2048, 4096, 8192, or 16384."
  }
}

variable "container_memory" {
  description = "Memory for the Fargate task in MB. Must be compatible with the CPU value."
  type        = number
  default     = 4096

  validation {
    condition     = var.container_memory >= 512 && var.container_memory <= 122880
    error_message = "Container memory must be between 512 MB and 122880 MB (120 GB)."
  }
}

variable "container_environment" {
  description = "Environment variables to pass to the container. Values are stored in plain text in the task definition; use container_secrets for anything sensitive. Do not set JDK_JAVA_OPTIONS here (the module sets it; use java_opts instead)."
  type = list(object({
    name  = string
    value = string
  }))
  default  = []
  nullable = false

  validation {
    condition = length(setintersection(
      [for env in var.container_environment : env.name],
      ["ENVIRONMENT", "JDK_JAVA_OPTIONS", "QUINE_SEED_DNS", "CONFIG_FORCE_quine_license__key"]
    )) == 0
    error_message = "ENVIRONMENT, JDK_JAVA_OPTIONS, QUINE_SEED_DNS and CONFIG_FORCE_quine_license__key are set by the module and must not be set in container_environment. Pass JVM options through java_opts and the license key through license_key_secret_arn."
  }
}

variable "container_secrets" {
  description = "Secrets to inject into the container as environment variables from AWS Secrets Manager or SSM Parameter Store. Each valueFrom must be a full ARN. The license key has its own input, license_key_secret_arn."
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default  = []
  nullable = false

  validation {
    condition = length(setintersection(
      [for secret in var.container_secrets : secret.name],
      ["ENVIRONMENT", "JDK_JAVA_OPTIONS", "QUINE_SEED_DNS", "CONFIG_FORCE_quine_license__key"]
    )) == 0
    error_message = "ENVIRONMENT, JDK_JAVA_OPTIONS, QUINE_SEED_DNS and CONFIG_FORCE_quine_license__key are set by the module and must not be repeated in container_secrets."
  }

  validation {
    condition     = alltrue([for secret in var.container_secrets : can(regex("^arn:aws[a-z-]*:(secretsmanager|ssm):\\S+$", secret.valueFrom))])
    error_message = "Each container_secrets valueFrom must be the full ARN of a Secrets Manager secret or an SSM parameter, because it is also used in the execution role's IAM policy."
  }
}

# -----------------------------------------------------------------------------
# Load Balancer Configuration
# -----------------------------------------------------------------------------

variable "internal_alb" {
  description = "Whether the ALB should be internal (not internet-facing)."
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Health check path used by the ALB target group and the container health check. Defaults to the v2 API liveness endpoint. Because the same path drives the container health check, prefer liveness over /api/v2/system/readiness, which reports the whole cluster and would restart healthy tasks while a cluster forms or a member is replaced."
  type        = string
  default     = "/api/v2/system/liveness"
  nullable    = false

  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "Health check path must start with '/'."
  }
}

variable "health_check_interval" {
  description = "Interval between health checks in seconds."
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds."
  type        = number
  default     = 5

  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 120
    error_message = "Health check timeout must be between 2 and 120 seconds."
  }
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks required."
  type        = number
  default     = 2

  validation {
    condition     = var.health_check_healthy_threshold >= 2 && var.health_check_healthy_threshold <= 10
    error_message = "Healthy threshold must be between 2 and 10."
  }
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks required."
  type        = number
  default     = 3

  validation {
    condition     = var.health_check_unhealthy_threshold >= 2 && var.health_check_unhealthy_threshold <= 10
    error_message = "Unhealthy threshold must be between 2 and 10."
  }
}

variable "deregistration_delay" {
  description = "Time to wait before deregistering targets from the target group (seconds)."
  type        = number
  default     = 30

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "Deregistration delay must be between 0 and 3600 seconds."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# HTTPS Configuration (Optional)
# -----------------------------------------------------------------------------

variable "enable_https" {
  description = "Enable HTTPS listener on the ALB. Requires certificate_arn."
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS. Required if enable_https is true."
  type        = string
  default     = null

  validation {
    condition     = var.certificate_arn == null || can(regex("^arn:aws:acm:[a-z0-9-]+:[0-9]+:certificate/", var.certificate_arn))
    error_message = "Certificate ARN must be a valid ACM certificate ARN."
  }
}

variable "ssl_policy" {
  description = "SSL policy for the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

# -----------------------------------------------------------------------------
# Logging Configuration
# -----------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch log retention period in days."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention value."
  }
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB. Defaults to 0.0.0.0/0 (open to internet)."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.alb_ingress_cidr_blocks : can(cidrhost(cidr, 0))])
    error_message = "All values must be valid CIDR blocks."
  }
}

variable "additional_task_role_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the ECS task role."
  type        = list(string)
  default     = []
}

variable "additional_execution_role_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the ECS task execution role."
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Quine Enterprise Cluster Configuration
# -----------------------------------------------------------------------------

variable "cluster_target_size" {
  description = "Target number of Quine Enterprise cluster members. When > 1, enables multi-member cluster mode with DNS-based service discovery for cluster join."
  type        = number
  default     = 1

  validation {
    condition     = var.cluster_target_size >= 1 && var.cluster_target_size <= 10
    error_message = "Cluster target size must be between 1 and 10."
  }
}

variable "cluster_port" {
  description = "Port used for inter-node cluster communication (Pekko/Akka remoting after cluster formation)."
  type        = number
  default     = 25520

  validation {
    condition     = var.cluster_port >= 1 && var.cluster_port <= 65535
    error_message = "Cluster port must be between 1 and 65535."
  }
}

variable "cluster_management_port" {
  description = "Port used for Pekko/Akka cluster bootstrap HTTP-based contact point discovery. This port is probed during the initial cluster formation phase before remoting on cluster_port is established."
  type        = number
  default     = 7626

  validation {
    condition     = var.cluster_management_port >= 1 && var.cluster_management_port <= 65535
    error_message = "Cluster management port must be between 1 and 65535."
  }
}

variable "service_discovery_namespace_name" {
  description = "Name of the private DNS namespace for service discovery. Defaults to '{project_name}.local'."
  type        = string
  default     = null
}

variable "java_opts" {
  description = "Additional Java options passed to the Quine Enterprise JVM via the JDK_JAVA_OPTIONS environment variable. The value is stored in plain text in the task definition and echoed to the container log at startup, so never put secrets (such as the license key) here; use license_key_secret_arn instead."
  type        = string
  default     = ""
  nullable    = false
}

# -----------------------------------------------------------------------------
# Quine Enterprise License Configuration
# -----------------------------------------------------------------------------

variable "license_key_secret_arn" {
  description = "ARN of an AWS Secrets Manager secret (or SSM SecureString parameter) whose value is the Quine Enterprise license key. This is required. ECS injects it into the container as the CONFIG_FORCE_quine_license__key environment variable, so the key never appears in the task definition or logs. Use the complete ARN, including the random 6-character suffix Secrets Manager appends to the secret name; an ARN built from the name alone does not match in IAM. The ':json-key:version-stage:version-id' suffix supported by ECS is allowed."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:(secretsmanager|ssm):\\S+$", var.license_key_secret_arn))
    error_message = "license_key_secret_arn must be the ARN of a Secrets Manager secret or an SSM parameter."
  }
}

variable "license_server_uri" {
  description = "Quine Enterprise license server URI."
  type        = string
  default     = "https://license.thatdot.com"
  nullable    = false

  validation {
    condition     = can(regex("^https?://\\S+$", var.license_server_uri))
    error_message = "license_server_uri must be an http(s) URL."
  }
}
