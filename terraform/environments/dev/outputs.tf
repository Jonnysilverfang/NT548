output "dev_pipeline_name" {
  value = aws_codepipeline.dev.name
}

output "lambda_security_gate_arn" {
  value = module.lambda_security_gate.lambda_function_arn
}

output "eventbridge_rule_arn" {
  value = module.eventbridge.rule_arn
}
