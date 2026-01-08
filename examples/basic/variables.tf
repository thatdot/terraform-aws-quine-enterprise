# -----------------------------------------------------------------------------
# Variables for Basic Example
# -----------------------------------------------------------------------------
# These variables allow customization of the Quine deployment.
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
