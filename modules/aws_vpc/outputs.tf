output "vpc_id" {
  description = "The ID of the primary VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "web_subnet_id" {
  description = "ID of the Web/Public subnet"
  value       = aws_subnet.web.id
}

output "app_subnet_id" {
  description = "ID of the App tier subnet"
  value       = aws_subnet.app.id
}

output "data_subnet_id" {
  description = "ID of the Data tier subnet"
  value       = aws_subnet.data.id
}

output "web_security_group_id" {
  description = "ID of the Web Tier Security Group"
  value       = aws_security_group.web_sg.id
}

output "app_security_group_id" {
  description = "ID of the App Tier Security Group"
  value       = aws_security_group.app_sg.id
}

output "data_security_group_id" {
  description = "ID of the Data Tier Security Group"
  value       = aws_security_group.data_sg.id
}

output "kms_key_arn" {
  description = "The ARN of the KMS Key"
  value       = aws_kms_key.banking_key.arn
}

output "kms_key_alias_arn" {
  description = "The ARN of the KMS Key Alias"
  value       = aws_kms_alias.banking_key_alias.arn
}

output "audit_logs_bucket_name" {
  description = "Name of the S3 WORM Bucket"
  value       = aws_s3_bucket.audit_logs.id
}

output "audit_logs_bucket_arn" {
  description = "ARN of the S3 WORM Bucket"
  value       = aws_s3_bucket.audit_logs.arn
}
