output "endpoint" {
  description = "RDS endpoint address"
  value       = aws_db_instance.mysql.address
}

output "port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.mysql.port
}

output "database_name" {
  description = "Initial database name"
  value       = aws_db_instance.mysql.db_name
}

output "security_group_id" {
  description = "RDS MySQL security group ID"
  value       = aws_security_group.mysql.id
}

output "credentials_secret_arn" {
  description = "Secrets Manager ARN containing RDS credentials"
  value       = aws_db_instance.mysql.master_user_secret[0].secret_arn
}
