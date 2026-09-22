output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task.arn
}

output "codebuild_dev_role_arn" {
  value = aws_iam_role.codebuild_dev.arn
}

output "codebuild_prod_role_arn" {
  value = aws_iam_role.codebuild_prod.arn
}

output "codepipeline_dev_role_arn" {
  value = aws_iam_role.codepipeline_dev.arn
}

output "codepipeline_prod_role_arn" {
  value = aws_iam_role.codepipeline_prod.arn
}

output "lambda_security_gate_role_arn" {
  value = aws_iam_role.lambda_security_gate.arn
}
