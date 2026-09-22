output "lambda_function_arn" {
  description = "ARN of the Security Gate Lambda function"
  value       = aws_lambda_function.security_gate.arn
}

output "lambda_function_name" {
  description = "Name of the Security Gate Lambda function"
  value       = aws_lambda_function.security_gate.function_name
}
