output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "alb_security_group_id" {
  value = module.vpc.alb_security_group_id
}

output "ecs_tasks_security_group_id" {
  value = module.vpc.ecs_tasks_security_group_id
}

output "alb_arn" {
  value = module.alb.alb_arn
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "alb_zone_id" {
  value = module.alb.alb_zone_id
}

output "alb_listener_arn" {
  value = module.alb.alb_listener_arn
}

output "http_listener_arn" {
  value = module.alb.http_listener_arn
}

output "prod_target_groups" {
  value = module.alb.prod_target_groups
}

output "dev_repository_urls" {
  value = module.ecr.dev_repository_urls
}

output "prod_repository_urls" {
  value = module.ecr.prod_repository_urls
}

output "artifact_bucket_name" {
  value = aws_s3_bucket.artifacts.id
}

output "ecs_task_execution_role_arn" {
  value = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  value = module.iam.ecs_task_role_arn
}

output "codebuild_dev_role_arn" {
  value = module.iam.codebuild_dev_role_arn
}

output "codebuild_prod_role_arn" {
  value = module.iam.codebuild_prod_role_arn
}

output "codepipeline_dev_role_arn" {
  value = module.iam.codepipeline_dev_role_arn
}

output "codepipeline_prod_role_arn" {
  value = module.iam.codepipeline_prod_role_arn
}

output "lambda_security_gate_role_arn" {
  value = module.iam.lambda_security_gate_role_arn
}
