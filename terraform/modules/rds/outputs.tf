output "endpoint" {
  description = "Private PostgreSQL hostname"
  value       = aws_db_instance.postgresql.address
}

output "port" {
  description = "PostgreSQL port"
  value       = aws_db_instance.postgresql.port
}

output "database_name" {
  description = "Initial PostgreSQL database name"
  value       = aws_db_instance.postgresql.db_name
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN generated and managed by RDS"
  value       = aws_db_instance.postgresql.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "Security group attached to PostgreSQL"
  value       = aws_security_group.postgresql.id
}
output "mysql_endpoint" {
  description = "Existing production MySQL hostname"
  value       = aws_db_instance.mysql.address
}

output "mysql_port" {
  description = "Existing production MySQL port"
  value       = aws_db_instance.mysql.port
}

output "mysql_database_name" {
  description = "Existing production MySQL database name"
  value       = aws_db_instance.mysql.db_name
}

output "mysql_master_user_secret_arn" {
  description = "Existing production MySQL master secret ARN"
  value       = aws_db_instance.mysql.master_user_secret[0].secret_arn
}
