data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../../lambda/security_gate"
  output_path = "${path.module}/security_gate.zip"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  # checkov:skip=CKV_AWS_158: "CloudWatch Log Group encryption using default AWS key is sufficient for project requirements"
  # checkov:skip=CKV_AWS_338: "Retention period set for lab lifecycle"
  name              = "/aws/lambda/nt548-dev-security-gate"
  retention_in_days = 7
}

resource "aws_lambda_function" "security_gate" {
  # checkov:skip=CKV_AWS_50: "X-Ray tracing not required for dev security gate function"
  # checkov:skip=CKV_AWS_115: "Concurrent execution limit not required for low frequency pipeline gate"
  # checkov:skip=CKV_AWS_116: "Dead letter queue not required for synchronous pipeline trigger"
  # checkov:skip=CKV_AWS_117: "Lambda function does not need VPC access to interact with ECR and CodePipeline"
  # checkov:skip=CKV_AWS_173: "Environment variables do not contain sensitive secrets"
  # checkov:skip=CKV_AWS_272: "Code signing validation not configured in lab environment"
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "nt548-dev-security-gate"
  role             = var.role_arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      DEV_PIPELINE_NAME    = var.dev_pipeline_name
      APPROVAL_STAGE_NAME  = "SecurityGate"
      APPROVAL_ACTION_NAME = "SecurityGateApproval"
      MAX_ALLOWED_CRITICAL = tostring(var.max_critical)
      MAX_ALLOWED_HIGH     = tostring(var.max_high)
    }
  }

  tags = {
    Name        = "nt548-dev-security-gate"
    Environment = "dev"
    Project     = "NT548"
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}
