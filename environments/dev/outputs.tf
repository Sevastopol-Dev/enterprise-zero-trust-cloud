# AWS VPC & Security Outputs
output "vpc_id" {
  description = "The ID of the primary AWS VPC"
  value       = module.aws_banking_vpc.vpc_id
}

output "web_subnet_id" {
  description = "ID of the Web/Public tier subnet"
  value       = module.aws_banking_vpc.web_subnet_id
}

output "app_subnet_id" {
  description = "ID of the App tier subnet"
  value       = module.aws_banking_vpc.app_subnet_id
}

output "data_subnet_id" {
  description = "ID of the Data tier subnet"
  value       = module.aws_banking_vpc.data_subnet_id
}

output "web_security_group_id" {
  description = "ID of the Web Tier Security Group"
  value       = module.aws_banking_vpc.web_security_group_id
}

output "app_security_group_id" {
  description = "ID of the App Tier Security Group"
  value       = module.aws_banking_vpc.app_security_group_id
}

output "data_security_group_id" {
  description = "ID of the Data Tier Security Group"
  value       = module.aws_banking_vpc.data_security_group_id
}

output "kms_key_arn" {
  description = "The ARN of the Customer Managed Key (CMK)"
  value       = module.aws_banking_vpc.kms_key_arn
}

output "audit_logs_bucket_name" {
  description = "The name of the WORM S3 bucket"
  value       = module.aws_banking_vpc.audit_logs_bucket_name
}

output "deployment_status" {
  description = "Summary status of AWS infrastructure deployment"
  value       = "Dev environment provisioned on AWS VPC (${module.aws_banking_vpc.vpc_id})."
}
