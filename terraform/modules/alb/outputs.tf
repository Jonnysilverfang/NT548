output "alb_arn" {
  description = "ARN of the shared ALB"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the shared ALB"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB"
  value       = aws_lb.main.zone_id
}

output "http_listener_arn" {
  description = "ARN of the HTTP 80 listener"
  value       = aws_lb_listener.http.arn
}

output "alb_listener_arn" {
  description = "ARN of the primary ALB listener (HTTP 80)"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS 443 listener if enabled"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "prod_target_groups" {
  description = "Map of PROD target group ARNs"
  value = {
    frontend = aws_lb_target_group.prod_fe.arn
    user     = aws_lb_target_group.prod_user.arn
    product  = aws_lb_target_group.prod_product.arn
    order    = aws_lb_target_group.prod_order.arn
  }
}
