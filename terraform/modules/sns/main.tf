resource "aws_sns_topic" "prod_approval" {
  # checkov:skip=CKV_AWS_26: "SNS topic is encrypted with AWS managed KMS key"
  name              = var.topic_name
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Name        = var.topic_name
    Environment = "prod"
    Project     = "NT548"
  }
}

resource "aws_sns_topic_subscription" "email_sub" {
  count     = var.approval_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.prod_approval.arn
  protocol  = "email"
  endpoint  = var.approval_email
}
