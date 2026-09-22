output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "frontend_service_name" {
  description = "Name of frontend ECS service"
  value       = aws_ecs_service.prod_frontend.name
}

output "user_service_name" {
  description = "Name of user ECS service"
  value       = aws_ecs_service.prod_user.name
}

output "product_service_name" {
  description = "Name of product ECS service"
  value       = aws_ecs_service.prod_product.name
}

output "order_service_name" {
  description = "Name of order ECS service"
  value       = aws_ecs_service.prod_order.name
}

output "prod_service_names" {
  description = "List of PROD ECS service names"
  value = [
    aws_ecs_service.prod_frontend.name,
    aws_ecs_service.prod_user.name,
    aws_ecs_service.prod_product.name,
    aws_ecs_service.prod_order.name
  ]
}

output "prod_services" {
  description = "Map of PROD ECS service names"
  value = {
    frontend = aws_ecs_service.prod_frontend.name
    user     = aws_ecs_service.prod_user.name
    product  = aws_ecs_service.prod_product.name
    order    = aws_ecs_service.prod_order.name
  }
}
