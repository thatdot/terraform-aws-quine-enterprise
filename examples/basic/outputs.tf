# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "url" {
  description = "URL to access Quine Enterprise web interface"
  value       = module.quine_enterprise.alb_url
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.quine_enterprise.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.quine_enterprise.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.quine_enterprise.ecs_service_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for viewing container logs"
  value       = module.quine_enterprise.cloudwatch_log_group_name
}
