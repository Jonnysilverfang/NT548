output "dev_pipeline_name" {
  value = aws_codepipeline.dev.name
}

output "dev_pipeline_arn" {
  value = aws_codepipeline.dev.arn
}

output "prod_pipeline_name" {
  value = aws_codepipeline.prod.name
}

output "prod_pipeline_arn" {
  value = aws_codepipeline.prod.arn
}
