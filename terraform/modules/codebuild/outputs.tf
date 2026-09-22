output "dev_build_project_name" {
  value = aws_codebuild_project.dev_build.name
}

output "dev_deploy_test_project_name" {
  value = aws_codebuild_project.dev_deploy_test.name
}

output "prod_build_project_name" {
  value = aws_codebuild_project.prod_build.name
}

output "prod_deploy_project_name" {
  value = aws_codebuild_project.prod_deploy.name
}
