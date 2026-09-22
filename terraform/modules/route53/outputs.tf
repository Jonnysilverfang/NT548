output "record_fqdn" {
  description = "FQDN of the alias record"
  value       = aws_route53_record.apex_a.fqdn
}
