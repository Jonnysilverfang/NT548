output "topic_arn" {
  description = "ARN of the SNS topic for approvals"
  value       = aws_sns_topic.prod_approval.arn
}
