terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = "us-west-2"
}

variable "container_image" {
  type = string
}

variable "license_key" {
  type      = string
  sensitive = true
}

variable "license_server_uri" {
  type = string
}

module "quine_enterprise" {
  source = "../"

  project_name    = "thatdot-terraform-ci-quine-enterprise"
  container_image = var.container_image
  desired_count   = 3

  java_opts = join(" ", [
    "-Dquine.license-key=${var.license_key}",
    "-Dquine.license-server-uri=${var.license_server_uri}",
  ])
}
