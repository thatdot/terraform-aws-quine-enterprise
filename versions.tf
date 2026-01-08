# -----------------------------------------------------------------------------
# Provider Requirements
# -----------------------------------------------------------------------------
# This module declares provider requirements but does NOT configure providers.
# The calling root module is responsible for provider configuration.
#
# Example provider configuration in root module:
#
#   provider "aws" {
#     region = "us-west-2"
#   }
#
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}
