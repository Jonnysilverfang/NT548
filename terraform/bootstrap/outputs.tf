output "state_bucket_name" {
  description = "Name of the S3 bucket used for remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket used for remote state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "aws_region" {
  description = "AWS region for the state bucket"
  value       = var.aws_region
}
