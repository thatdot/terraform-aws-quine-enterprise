# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "url" {
  description = "URL to access Quine web interface"
  value       = module.quine.alb_url
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.quine.alb_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.quine.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.quine.ecs_service_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for viewing container logs"
  value       = module.quine.cloudwatch_log_group_name
}
