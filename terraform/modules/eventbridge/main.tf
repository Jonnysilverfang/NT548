resource "aws_cloudwatch_event_rule" "ecr_scan_dev" {
  name        = "nt548-dev-ecr-scan-rule"
  description = "Triggers Lambda Security Gate on DEV ECR Image Scan completion"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Scan"]
    detail = {
      repository-name = [
        { prefix = "nt548-dev-" }
      ]
    }
  })

  tags = {
    Name        = "nt548-dev-ecr-scan-rule"
    Environment = "dev"
    Project     = "NT548"
  }
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.ecr_scan_dev.name
  target_id = "TriggerLambdaSecurityGate"
  arn       = var.lambda_function_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ecr_scan_dev.arn
}
