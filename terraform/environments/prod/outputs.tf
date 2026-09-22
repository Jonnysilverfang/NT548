output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = data.terraform_remote_state.shared.outputs.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = data.terraform_remote_state.shared.outputs.alb_arn
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB"
  value       = data.terraform_remote_state.shared.outputs.alb_zone_id
}

output "alb_listener_arn" {
  description = "ARN of the ALB listener (HTTP 80)"
  value       = data.terraform_remote_state.shared.outputs.alb_listener_arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "frontend_service_name" {
  description = "Name of PROD frontend ECS service"
  value       = module.ecs.frontend_service_name
}

output "user_service_name" {
  description = "Name of PROD user ECS service"
  value       = module.ecs.user_service_name
}

output "product_service_name" {
  description = "Name of PROD product ECS service"
  value       = module.ecs.product_service_name
}

output "order_service_name" {
  description = "Name of PROD order ECS service"
  value       = module.ecs.order_service_name
}

output "prod_pipeline_name" {
  description = "Name of the PROD CodePipeline"
  value       = aws_codepipeline.prod.name
}

output "infra_approval_topic_arn" {
  description = "SNS Topic ARN for Infrastructure Approval"
  value       = module.sns_infra.topic_arn
}

output "prod_approval_topic_arn" {
  description = "SNS Topic ARN for Application Deployment Approval"
  value       = module.sns_app.topic_arn
}
