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

  project_name        = "thatdot-terraform-ci-qe"
  container_image     = var.container_image
  cluster_target_size = 3

  java_opts = join(" ", [
    "-Dquine.license-key=${var.license_key}",
    "-Dquine.license-server-uri=${var.license_server_uri}",
  ])
}

output "alb_url" {
  value = module.quine_enterprise.alb_url
}

output "ecs_cluster_name" {
  value = module.quine_enterprise.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.quine_enterprise.ecs_service_name
}
