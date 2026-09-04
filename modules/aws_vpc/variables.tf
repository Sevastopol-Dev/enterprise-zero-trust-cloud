variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Primary CIDR block for the AWS VPC"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment name"
}
