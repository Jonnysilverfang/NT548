output "dev_repository_urls" {
  description = "URLs of the DEV repositories"
  value       = { for k, v in aws_ecr_repository.dev : k => v.repository_url }
}

output "prod_repository_urls" {
  description = "URLs of the PROD repositories"
  value       = { for k, v in aws_ecr_repository.prod : k => v.repository_url }
}

output "dev_repository_arns" {
  description = "ARNs of the DEV repositories"
  value       = { for k, v in aws_ecr_repository.dev : k => v.arn }
}

output "prod_repository_arns" {
  description = "ARNs of the PROD repositories"
  value       = { for k, v in aws_ecr_repository.prod : k => v.arn }
}
